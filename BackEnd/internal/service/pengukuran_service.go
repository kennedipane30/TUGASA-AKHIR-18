package service

// Pendataan kader: antrean anak yang sudah check-in, dan pencatatan pengukuran
// anak (berat, tinggi, lingkar kepala, LILA, keluhan).

import (
	"errors"
	"fmt"
	"log"
	"sort"
	"strings"
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Fitur kader: antrean pendataan dan pencatatan pengukuran anak
// (berat, tinggi, lingkar kepala, LILA, keluhan).


type PengukuranInput struct {
	BbKg            float64  `json:"bb_kg" binding:"required"`
	TbCm            float64  `json:"tb_cm" binding:"required"`
	CaraUkur        string   `json:"cara_ukur"` // berbaring | berdiri (kosong = otomatis dari usia)
	LingkarKepalaCm *float64 `json:"lingkar_kepala_cm"`
	LilaCm          *float64 `json:"lila_cm"`
	Keluhan         string   `json:"keluhan"`
	SedangSakit     bool     `json:"sedang_sakit"`
	AsiEksklusif    bool     `json:"asi_eksklusif"`
	Catatan         string   `json:"catatan"`
}

type AntreanItem struct {
	PendaftaranID     uuid.UUID                `json:"pendaftaran_id"`
	AnakID            uuid.UUID                `json:"anak_id"`
	Nama              string                   `json:"nama"`
	JenisKelamin      string                   `json:"jenis_kelamin"`
	TanggalLahir      string                   `json:"tanggal_lahir"` // YYYY-MM-DD, untuk usia detail di aplikasi
	UsiaBulan         int                      `json:"usia_bulan"`
	NomorAntrean      *int16                   `json:"nomor_antrean"`
	StatusKehadiran   string                   `json:"status_kehadiran"`
	Sumber            string                   `json:"sumber"`
	SudahDiukur       bool                     `json:"sudah_diukur"`
	SudahDicatatBidan bool                     `json:"sudah_dicatat_bidan"`
	StatusGizi        *models.StatusGizi       `json:"status_gizi"`
	Penilaian         *models.PenilaianTimbang `json:"penilaian"`
}

// AntreanKader: antrean pendataan, yaitu anak yang sudah check-in pada satu jadwal di posyandu kader.
func (s *PelayananService) AntreanKader(jadwalID uuid.UUID, pos string) ([]AntreanItem, error) {
	if _, err := s.jadwalPos(jadwalID, pos); err != nil {
		return nil, err
	}
	list, err := s.jadwal.ListPendaftaranJadwal(jadwalID, "sudah_checkin")
	if err != nil {
		return nil, err
	}
	sort.SliceStable(list, func(i, j int) bool {
		a, b := list[i].WaktuCheckin, list[j].WaktuCheckin
		if a == nil || b == nil {
			return a != nil
		}
		return a.Before(*b)
	})
	ids := idPendaftaran(list)
	ukur, err := s.repo.ListPengukuran(ids)
	if err != nil {
		return nil, err
	}
	periksa, err := s.repo.ListPemeriksaan(ids)
	if err != nil {
		return nil, err
	}
	adaUkur := map[uuid.UUID]bool{}
	ukurPer := map[uuid.UUID]uuid.UUID{}
	for _, u := range ukur {
		adaUkur[u.PendaftaranID] = true
		ukurPer[u.PendaftaranID] = u.ID
	}
	nilai, err := s.petaPenilaian(ukur)
	if err != nil {
		return nil, err
	}
	petaGizi := map[uuid.UUID]models.StatusGizi{}
	if s.gizi != nil {
		ukurIDs := make([]uuid.UUID, 0, len(ukur))
		for _, u := range ukur {
			ukurIDs = append(ukurIDs, u.ID)
		}
		if petaGizi, err = s.gizi.PetaPengukuran(ukurIDs); err != nil {
			return nil, err
		}
	}
	adaCatatan := map[uuid.UUID]bool{}
	for _, c := range periksa {
		adaCatatan[c.PendaftaranID] = true
	}

	now := time.Now()
	out := make([]AntreanItem, 0, len(list))
	for _, p := range list {
		it := AntreanItem{
			PendaftaranID:     p.ID,
			AnakID:            p.AnakID,
			NomorAntrean:      p.NomorAntrean,
			StatusKehadiran:   p.StatusKehadiran,
			Sumber:            p.Sumber,
			SudahDiukur:       adaUkur[p.ID],
			SudahDicatatBidan: adaCatatan[p.ID],
		}
		if n, ok := nilai[ukurPer[p.ID]]; ok && adaUkur[p.ID] {
			nn := n
			it.Penilaian = &nn
		}
		if g, ok := petaGizi[ukurPer[p.ID]]; ok && adaUkur[p.ID] {
			gg := g
			it.StatusGizi = &gg
		}
		if p.Anak != nil {
			it.Nama = p.Anak.Nama
			it.JenisKelamin = p.Anak.JenisKelamin
			it.TanggalLahir = p.Anak.TanggalLahir.Format("2006-01-02")
			it.UsiaBulan = usiaBulan(p.Anak.TanggalLahir, now)
		}
		out = append(out, it)
	}
	return out, nil
}

func (s *PelayananService) CatatPengukuran(kaderID uint, pos string, pendaftaranID uuid.UUID, in PengukuranInput) (*models.Pengukuran, error) {
	p, err := s.pendaftaranPos(pendaftaranID, pos)
	if err != nil {
		return nil, err
	}
	if p.StatusKehadiran != "sudah_checkin" {
		return nil, konflik("anak belum check-in, pengukuran belum dapat dicatat")
	}
	if err := cekSesiSudahMulai(p.Jadwal); err != nil {
		return nil, err
	}
	if p.Anak == nil {
		return nil, ErrAnakTidakAda
	}
	if _, err := s.repo.GetPemeriksaan(p.ID); err == nil {
		return nil, konflik("data sudah dicatat bidan dan tidak dapat diubah")
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	// validasi angka
	if err := rentang(in.BbKg, 2, 30, "berat badan (kg)"); err != nil {
		return nil, err
	}
	if err := rentang(in.TbCm, 40, 130, "tinggi/panjang badan (cm)"); err != nil {
		return nil, err
	}
	if in.LingkarKepalaCm != nil {
		if err := rentang(*in.LingkarKepalaCm, 30, 60, "lingkar kepala (cm)"); err != nil {
			return nil, err
		}
	}
	if in.LilaCm != nil {
		if err := rentang(*in.LilaCm, 8, 25, "lingkar lengan atas (cm)"); err != nil {
			return nil, err
		}
	}

	hari := hariIni()
	usia := usiaBulan(p.Anak.TanggalLahir, hari)
	cara := strings.TrimSpace(in.CaraUkur)
	switch cara {
	case "berbaring", "berdiri":
	case "":
		cara = "berdiri"
		if usia < 24 {
			cara = "berbaring"
		}
	default:
		return nil, validasi("cara_ukur harus berbaring atau berdiri")
	}

	// peringatan bila angka berubah tidak wajar dari kunjungan sebelumnya
	var peringatan []string
	prev, err := s.repo.PengukuranSebelumnya(p.AnakID, p.ID)
	switch {
	case err == nil:
		if in.BbKg < prev.BbKg-0.3 {
			peringatan = append(peringatan, fmt.Sprintf("BB lebih rendah dari kunjungan sebelumnya (%.1f kg)", prev.BbKg))
		}
		if in.BbKg > prev.BbKg+3 {
			peringatan = append(peringatan, fmt.Sprintf("BB naik lebih dari 3 kg dari kunjungan sebelumnya (%.1f kg)", prev.BbKg))
		}
		if in.TbCm < prev.TbCm-0.5 {
			peringatan = append(peringatan, fmt.Sprintf("TB lebih rendah dari kunjungan sebelumnya (%.1f cm)", prev.TbCm))
		}
	case errors.Is(err, gorm.ErrRecordNotFound):
	default:
		return nil, err
	}

	m, err := s.repo.GetPengukuran(p.ID)
	baru := false
	if errors.Is(err, gorm.ErrRecordNotFound) {
		baru = true
		m = &models.Pengukuran{
			PendaftaranID: p.ID,
			AnakID:        p.AnakID,
			TanggalUkur:   hari,
			DicatatOleh:   kaderID,
			Version:       1,
		}
	} else if err != nil {
		return nil, err
	} else {
		m.Version++
	}
	m.UsiaBulan = int16(usia)
	m.BbKg = in.BbKg
	m.TbCm = in.TbCm
	m.CaraUkur = cara
	m.LingkarKepalaCm = in.LingkarKepalaCm
	m.LilaCm = in.LilaCm
	m.Keluhan = strings.TrimSpace(in.Keluhan)
	m.SedangSakit = in.SedangSakit
	m.AsiEksklusif = in.AsiEksklusif
	m.Catatan = strings.TrimSpace(in.Catatan)
	m.PeringatanValidasi = strings.Join(peringatan, "; ")

	if baru {
		err = s.repo.CreatePengukuran(m)
	} else {
		err = s.repo.SavePengukuran(m)
	}
	if err != nil {
		return nil, err
	}
	// Hitung z-score dan status gizi (WHO). Kegagalan tidak membatalkan pengukuran.
	if s.gizi != nil {
		if _, err := s.gizi.HitungDanSimpan(p.Anak, m); err != nil {
			log.Printf("status gizi pengukuran %s gagal dihitung: %v", m.ID, err)
		}
	}
	// Penilaian N/T (KBM), 2T, dan BGM. Kegagalan tidak membatalkan pengukuran.
	if s.kbm != nil {
		pengirim := kaderID
		if _, err := s.kbm.NilaiDanKabari(p.Anak, m, &pengirim); err != nil {
			log.Printf("penilaian KBM pengukuran %s gagal: %v", m.ID, err)
		}
	}
	return m, nil
}

// PengukuranKader: data pengukuran satu kunjungan (nil bila belum diinput kader).
func (s *PelayananService) PengukuranKader(pos string, pendaftaranID uuid.UUID) (*models.Pengukuran, error) {
	if _, err := s.pendaftaranPos(pendaftaranID, pos); err != nil {
		return nil, err
	}
	m, err := s.repo.GetPengukuran(pendaftaranID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return m, nil
}