package service

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ============================================================================
// RIWAYAT VAKSIN SEBELUM POSYANDU (dicatat BIDAN pada kunjungan pertama anak)
//
// Orang tua tidak lagi mengisi riwayat vaksin. Saat anak pertama kali datang,
// bidan menanyakan / melihat Buku KIA lalu mencatat:
//   - "belum_pernah": anak belum pernah divaksin, atau
//   - "sudah": daftar dosis vaksin program (centang) + vaksin mandiri di luar program.
// Data langsung sah (dikonfirmasi). Status riwayat anak menjadi "dikonfirmasi",
// sehingga bagian ini tidak muncul lagi pada kunjungan berikutnya.
// ============================================================================

var ErrVaksinMandiriTidakAda = errors.New("catatan vaksin mandiri tidak ditemukan")

// VaksinMandiriInput: vaksin di luar daftar program.
type VaksinMandiriInput struct {
	NamaVaksin       string `json:"nama_vaksin"`
	DosisKe          int16  `json:"dosis_ke"`
	TanggalPemberian string `json:"tanggal_pemberian"` // YYYY-MM-DD
	Tempat           string `json:"tempat"`
	FotoBukti        string `json:"foto_bukti"` // opsional
}

// RiwayatAwalBidanInput: isian bidan untuk riwayat vaksin sebelum posyandu.
type RiwayatAwalBidanInput struct {
	Status  string               `json:"status" binding:"required"` // sudah | belum_pernah
	Items   []RiwayatAwalItem    `json:"items"`                     // vaksin program yang dicentang
	Mandiri []VaksinMandiriInput `json:"mandiri"`                   // vaksin di luar program
}

// VaksinMandiriResp: tampilan vaksin mandiri pada kartu vaksin.
type VaksinMandiriResp struct {
	ID               uuid.UUID `json:"id"`
	NamaVaksin       string    `json:"nama_vaksin"`
	DosisKe          int16     `json:"dosis_ke"`
	TanggalPemberian string    `json:"tanggal_pemberian"`
	UsiaTeks         string    `json:"usia_teks"`
	Tempat           string    `json:"tempat"`
	FotoBukti        string    `json:"foto_bukti"`
}

func vaksinMandiriResp(m *models.VaksinMandiriAnak, lahir time.Time) VaksinMandiriResp {
	t := tglSaja(m.TanggalPemberian)
	return VaksinMandiriResp{
		ID: m.ID, NamaVaksin: m.NamaVaksin, DosisKe: m.DosisKe,
		TanggalPemberian: t.Format(vaksinTglLayout), UsiaTeks: usiaTeks(tglSaja(lahir), t),
		Tempat: m.Tempat, FotoBukti: m.FotoBukti,
	}
}

// daftarVaksinMandiri: untuk KartuAnak.
func (s *VaksinService) daftarVaksinMandiri(anak *models.Anak) []VaksinMandiriResp {
	out := []VaksinMandiriResp{}
	list, err := s.repo.ListVaksinMandiri(anak.ID)
	if err != nil {
		return out
	}
	for i := range list {
		out = append(out, vaksinMandiriResp(&list[i], anak.TanggalLahir))
	}
	return out
}

// CatatRiwayatAwal: bidan mencatat riwayat vaksin anak sebelum posyandu (sekali, kunjungan pertama).
func (s *VaksinService) CatatRiwayatAwal(bidanID uint, pos string, anakID uuid.UUID, in RiwayatAwalBidanInput) (*KartuVaksinResp, error) {
	anak, err := s.CekAkses(anakID, bidanID, "bidan", pos)
	if err != nil {
		return nil, err
	}
	if anak.StatusRiwayatVaksin == models.RiwayatVaksinDikonfirmasi {
		return nil, konflik("riwayat vaksin anak ini sudah dicatat; vaksin dari luar posyandu berikutnya dicatat lewat menu Vaksin Susulan")
	}
	if n := s.repo.JumlahMenungguKonfirmasi(anak.ID); n > 0 {
		return nil, konflik("masih ada %d laporan vaksin lama dari orang tua yang belum dicek; benarkan atau batalkan terlebih dahulu", n)
	}

	status := strings.TrimSpace(in.Status)
	switch status {
	case "belum_pernah":
		if len(in.Items) > 0 || len(in.Mandiri) > 0 {
			return nil, validasi("pilihan \"belum pernah\" tidak boleh disertai daftar vaksin")
		}
	case "sudah":
		if len(in.Items) == 0 && len(in.Mandiri) == 0 {
			// boleh kosong bila sudah ada catatan vaksin luar sebelumnya (mis. laporan lama yang sudah dibenarkan)
			if luar, err := s.RiwayatLuar(anak); err != nil || len(luar) == 0 {
				return nil, validasi("centang minimal satu vaksin atau tambahkan vaksin mandiri")
			}
		}
	default:
		return nil, validasi("status riwayat vaksin harus sudah atau belum_pernah")
	}

	lahir := tglSaja(anak.TanggalLahir)
	hari := hariIni()

	err = s.repo.Tx(func(r *repository.VaksinRepository) error {
		// ------------------------------------------------ vaksin program (centang)
		items := make([]itemRiwayat, 0, len(in.Items))
		baru := make([]models.ImunisasiAnak, 0, len(in.Items))
		for _, x := range in.Items {
			if x.JenisVaksinID == uuid.Nil || x.DosisKe < 1 {
				return validasi("vaksin yang dicentang tidak valid, muat ulang halaman")
			}
			tgl, err := time.Parse(vaksinTglLayout, strings.TrimSpace(x.TanggalPemberian))
			if err != nil {
				return validasi("tanggal pemberian setiap vaksin wajib diisi (YYYY-MM-DD)")
			}
			tempat, err := batasTeks(x.Tempat, 100, "tempat")
			if err != nil {
				return err
			}
			if tempat == "" {
				return validasi("tempat pemberian setiap vaksin wajib diisi (mis. RSUD Porsea)")
			}
			foto, err := cekNamaBukti(x.FotoBukti)
			if err != nil {
				return err
			}
			items = append(items, itemRiwayat{JenisVaksinID: x.JenisVaksinID, DosisKe: x.DosisKe, Tanggal: tgl})
			baru = append(baru, models.ImunisasiAnak{
				AnakID: anak.ID, JenisVaksinID: x.JenisVaksinID, DosisKe: x.DosisKe,
				TanggalPemberian: tglSaja(tgl), Tempat: tempat, FotoBukti: foto,
				Sumber: models.SumberImunisasiLuar, StatusKonfirmasi: models.KonfirmasiImunisasiOK,
				DiberikanOleh: bidanID, Version: 1,
			})
		}
		// dosis dobel, urutan dosis, usia, jarak minimal, tanggal (aturan yang sama dengan posyandu)
		if err := validasiRiwayat(r, anak, items, nil, nil); err != nil {
			return err
		}
		for i := range baru {
			if err := r.CreateRiwayat(&baru[i]); err != nil {
				return err
			}
		}

		// ------------------------------------------------ vaksin mandiri (di luar program)
		dipakai := map[string]bool{}
		for _, x := range in.Mandiri {
			nama, err := batasTeks(x.NamaVaksin, 100, "nama vaksin")
			if err != nil {
				return err
			}
			if nama == "" {
				return validasi("nama vaksin mandiri wajib diisi")
			}
			if x.DosisKe < 1 || x.DosisKe > 10 {
				return validasi("dosis %s harus antara 1 dan 10", nama)
			}
			kunci := fmt.Sprintf("%s|%d", strings.ToLower(nama), x.DosisKe)
			if dipakai[kunci] || r.VaksinMandiriAda(anak.ID, nama, x.DosisKe) {
				return konflik("%s dosis %d sudah tercatat", nama, x.DosisKe)
			}
			dipakai[kunci] = true
			tgl, err := time.Parse(vaksinTglLayout, strings.TrimSpace(x.TanggalPemberian))
			if err != nil {
				return validasi("tanggal pemberian %s wajib diisi (YYYY-MM-DD)", nama)
			}
			tgl = tglSaja(tgl)
			if tgl.Before(lahir) || tgl.After(hari) {
				return validasi("tanggal %s harus antara tanggal lahir anak dan hari ini", nama)
			}
			tempat, err := batasTeks(x.Tempat, 100, "tempat")
			if err != nil {
				return err
			}
			if tempat == "" {
				return validasi("tempat pemberian %s wajib diisi", nama)
			}
			foto, err := cekNamaBukti(x.FotoBukti)
			if err != nil {
				return err
			}
			m := models.VaksinMandiriAnak{
				AnakID: anak.ID, NamaVaksin: nama, DosisKe: x.DosisKe, TanggalPemberian: tgl,
				Tempat: tempat, FotoBukti: foto, DicatatOleh: bidanID,
			}
			if err := r.CreateVaksinMandiri(&m); err != nil {
				return err
			}
		}

		// ------------------------------------------------ status: sudah dicatat bidan
		now := time.Now()
		oleh := bidanID
		return r.SimpanStatusRiwayat(anak.ID, models.RiwayatVaksinDikonfirmasi, &oleh, &now)
	})
	if err != nil {
		return nil, err
	}
	return s.KartuAnak(anak.ID, bidanID, "bidan", pos)
}

// HapusVaksinMandiri: bidan menghapus catatan vaksin mandiri yang salah.
func (s *VaksinService) HapusVaksinMandiri(bidanID uint, pos string, id uuid.UUID) error {
	m, err := s.repo.GetVaksinMandiri(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrVaksinMandiriTidakAda
	}
	if err != nil {
		return err
	}
	if _, err := s.CekAkses(m.AnakID, bidanID, "bidan", pos); err != nil {
		return err
	}
	return s.repo.HapusVaksinMandiri(id)
}