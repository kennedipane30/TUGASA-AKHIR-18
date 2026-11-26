package service

import (
	"fmt"
	"log"
	"math"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
)

// ============================================================================
// KENAIKAN BERAT BADAN MINIMAL (KBM) — Buku KIA / KMS
//
//   Usia (bulan)   KBM (gram)        Usia (bulan)   KBM (gram)
//   1              800               7              400
//   2              900               8              300
//   3              800               9              300
//   4              600               10             300
//   5              500               11             200
//   6              400               12 - 60        200
//
// N/T hanya dinilai bila anak juga ditimbang pada bulan sebelumnya.
// 2T  = tidak naik dua bulan berturut-turut.
// BGM = Bawah Garis Merah KMS (BB/U < -3 SD).
// ============================================================================

var tabelKbm = map[int]int{1: 800, 2: 900, 3: 800, 4: 600, 5: 500, 6: 400, 7: 400, 8: 300, 9: 300, 10: 300, 11: 200}

// KbmGram: kenaikan berat badan minimal (gram) untuk usia [usia] bulan.
func KbmGram(usia int) int {
	if usia <= 1 {
		return tabelKbm[1]
	}
	if g, ok := tabelKbm[usia]; ok {
		return g
	}
	return 200
}

type KbmService struct {
	repo  *repository.KbmRepository
	notif *NotifikasiService
}

func NewKbmService(repo *repository.KbmRepository) *KbmService { return &KbmService{repo: repo} }

// SetNotifikasi mengaktifkan notifikasi 2T/BGM ke bidan, kader, dan orang tua.
func (s *KbmService) SetNotifikasi(n *NotifikasiService) { s.notif = n }

func indeksBulan(t time.Time) int { return t.Year()*12 + int(t.Month()) }

// Nilai: hitung penilaian satu penimbangan (tanpa menyimpan).
func (s *KbmService) Nilai(anak *models.Anak, u *models.Pengukuran) (*models.PenilaianTimbang, error) {
	tgl := time.Date(u.TanggalUkur.Year(), u.TanggalUkur.Month(), u.TanggalUkur.Day(), 0, 0, 0, 0, time.UTC)
	usia := usiaBulan(anak.TanggalLahir, tgl)
	p := &models.PenilaianTimbang{
		PengukuranID: u.ID, AnakID: u.AnakID, TanggalUkur: tgl,
		UsiaBulan: int16(usia), BbKg: u.BbKg,
	}

	z, err := s.repo.ZBbu(u.ID)
	if err != nil {
		return nil, err
	}
	p.ZBbu = z
	p.Bgm = z != nil && *z < -3

	prev, err := s.repo.PengukuranSebelum(u.AnakID, tgl, u.ID)
	if err != nil {
		return nil, err
	}
	if prev == nil {
		p.Status = models.StatusTimbangBaru
		p.Keterangan = "Penimbangan pertama, kenaikan berat badan belum dapat dinilai"
	} else {
		pid := prev.ID
		bb := prev.BbKg
		pt := time.Date(prev.TanggalUkur.Year(), prev.TanggalUkur.Month(), prev.TanggalUkur.Day(), 0, 0, 0, 0, time.UTC)
		selisih := int16(indeksBulan(tgl) - indeksBulan(pt))
		p.PengukuranSebelumnyaID, p.BbSebelumnya, p.TanggalSebelumnya, p.SelisihBulan = &pid, &bb, &pt, &selisih

		naik := int(math.Round((u.BbKg - prev.BbKg) * 1000))
		p.KenaikanGram = &naik

		if selisih != 1 {
			p.Status = models.StatusTimbangO
			if selisih <= 0 {
				p.Keterangan = "Sudah ditimbang pada bulan yang sama, N/T dinilai dari penimbangan bulan lalu"
			} else {
				p.Keterangan = fmt.Sprintf("Bulan lalu tidak ditimbang (terakhir %d bulan lalu), N/T tidak dapat dinilai", selisih)
			}
		} else {
			kbm := KbmGram(usia)
			p.KbmGram = &kbm
			if naik >= kbm {
				p.Status = models.StatusTimbangNaik
				p.Keterangan = fmt.Sprintf("Naik %d g, memenuhi KBM %d g", naik, kbm)
			} else {
				p.Status = models.StatusTimbangTidakNaik
				switch {
				case naik < 0:
					p.Keterangan = fmt.Sprintf("Berat badan turun %d g (KBM %d g)", -naik, kbm)
				case naik == 0:
					p.Keterangan = fmt.Sprintf("Berat badan tetap (KBM %d g)", kbm)
				default:
					p.Keterangan = fmt.Sprintf("Naik %d g, kurang dari KBM %d g", naik, kbm)
				}
				pp, err := s.repo.GetByPengukuran(prev.ID)
				if err != nil {
					return nil, err
				}
				if pp != nil && pp.Status == models.StatusTimbangTidakNaik {
					p.DuaT = true
					p.Keterangan += "; tidak naik 2 bulan berturut-turut (2T)"
				}
			}
		}
	}
	if p.Bgm {
		p.Keterangan += "; berat badan di bawah garis merah (BGM)"
	}
	p.PerluRujuk = p.DuaT || p.Bgm
	return p, nil
}

// NilaiDanSimpan: dipanggil setiap kader menyimpan pengukuran (setelah status gizi dihitung).
func (s *KbmService) NilaiDanSimpan(anak *models.Anak, u *models.Pengukuran) (*models.PenilaianTimbang, error) {
	p, err := s.Nilai(anak, u)
	if err != nil {
		return nil, err
	}
	if err := s.repo.Simpan(p); err != nil {
		return nil, err
	}
	return p, nil
}

// NilaiDanKabari: dipakai saat kader menyimpan pengukuran. Menilai dan menyimpan.
// Orang tua TIDAK dikabari di sini; orang tua dikabari setelah bidan menyimpan catatan
// (lihat PelayananService.SimpanCatatan). Bidan tetap diberi peringatan bila 2T/BGM.
func (s *KbmService) NilaiDanKabari(anak *models.Anak, u *models.Pengukuran, pengirim *uint) (*models.PenilaianTimbang, error) {
	p, err := s.NilaiDanSimpan(anak, u)
	if err != nil {
		return nil, err
	}
	if s.notif != nil {
		a := *anak
		pp := *p
		if p.PerluRujuk {
			go s.notif.PeringatanTimbang(&a, &pp, pengirim)
		}
	}
	return p, nil
}

// UntukPengukuran: penilaian satu pengukuran (nil bila belum ada).
func (s *KbmService) UntukPengukuran(pengukuranID uuid.UUID) (*models.PenilaianTimbang, error) {
	return s.repo.GetByPengukuran(pengukuranID)
}

// PetaPengukuran: penilaian per pengukuran_id.
func (s *KbmService) PetaPengukuran(ids []uuid.UUID) (map[uuid.UUID]models.PenilaianTimbang, error) {
	list, err := s.repo.ListByPengukuran(ids)
	if err != nil {
		return nil, err
	}
	out := make(map[uuid.UUID]models.PenilaianTimbang, len(list))
	for _, p := range list {
		out[p.PengukuranID] = p
	}
	return out, nil
}

// HitungDataLama: menilai pengukuran lama yang belum punya penilaian (dijalankan saat server mulai).
func (s *KbmService) HitungDataLama() {
	total := 0
	for {
		list, err := s.repo.PengukuranTanpaPenilaian(200)
		if err != nil {
			log.Printf("kbm: gagal membaca pengukuran lama: %v", err)
			return
		}
		if len(list) == 0 {
			break
		}
		ids := make([]uuid.UUID, 0, len(list))
		for _, u := range list {
			ids = append(ids, u.AnakID)
		}
		anak, err := s.repo.AnakByIDs(ids)
		if err != nil {
			log.Printf("kbm: gagal membaca anak: %v", err)
			return
		}
		peta := map[uuid.UUID]*models.Anak{}
		for i := range anak {
			peta[anak[i].ID] = &anak[i]
		}
		berhasil := 0
		for i := range list {
			a := peta[list[i].AnakID]
			if a == nil {
				continue
			}
			if _, err := s.NilaiDanSimpan(a, &list[i]); err != nil {
				log.Printf("kbm: pengukuran %s gagal dinilai: %v", list[i].ID, err)
				continue
			}
			berhasil++
		}
		total += berhasil
		if berhasil == 0 {
			break
		}
	}
	if total > 0 {
		log.Printf("kbm: %d pengukuran lama dinilai (N/T, 2T, BGM)", total)
	}
}