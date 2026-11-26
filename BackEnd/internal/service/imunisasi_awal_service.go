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
// RIWAYAT IMUNISASI SEBELUM POSYANDU (dicatat BIDAN pada kunjungan pertama balita)
//
// Orang tua tidak lagi mengisi riwayat imunisasi. Saat balita pertama kali datang,
// bidan menanyakan / melihat Buku KIA lalu mencatat:
//   - "belum_pernah": balita belum pernah diimunisasi, atau
//   - "sudah": daftar dosis imunisasi program (centang) + imunisasi mandiri di luar program.
// Data langsung sah (dikonfirmasi). Status riwayat balita menjadi "dikonfirmasi",
// sehingga bagian ini tidak muncul lagi pada kunjungan berikutnya.
// ============================================================================

var ErrImunisasiMandiriTidakAda = errors.New("catatan imunisasi mandiri tidak ditemukan")

// ImunisasiMandiriInput: imunisasi di luar daftar program.
type ImunisasiMandiriInput struct {
	NamaImunisasi    string `json:"nama_imunisasi"`
	DosisKe          int16  `json:"dosis_ke"`
	TanggalPemberian string `json:"tanggal_pemberian"` // YYYY-MM-DD
	Tempat           string `json:"tempat"`
	FotoBukti        string `json:"foto_bukti"` // opsional
}

// RiwayatAwalBidanInput: isian bidan untuk riwayat imunisasi sebelum posyandu.
type RiwayatAwalBidanInput struct {
	Status  string                  `json:"status" binding:"required"` // sudah | belum_pernah
	Items   []RiwayatAwalItem       `json:"items"`                     // imunisasi program yang dicentang
	Mandiri []ImunisasiMandiriInput `json:"mandiri"`                   // imunisasi di luar program
}

// ImunisasiMandiriResp: tampilan imunisasi mandiri pada kartu imunisasi.
type ImunisasiMandiriResp struct {
	ID               uuid.UUID `json:"id"`
	NamaImunisasi    string    `json:"nama_imunisasi"`
	DosisKe          int16     `json:"dosis_ke"`
	TanggalPemberian string    `json:"tanggal_pemberian"`
	UsiaTeks         string    `json:"usia_teks"`
	Tempat           string    `json:"tempat"`
	FotoBukti        string    `json:"foto_bukti"`
}

func imunisasiMandiriResp(m *models.ImunisasiMandiriBalita, lahir time.Time) ImunisasiMandiriResp {
	t := tglSaja(m.TanggalPemberian)
	return ImunisasiMandiriResp{
		ID: m.ID, NamaImunisasi: m.NamaImunisasi, DosisKe: m.DosisKe,
		TanggalPemberian: t.Format(imunisasiTglLayout), UsiaTeks: usiaTeks(tglSaja(lahir), t),
		Tempat: m.Tempat, FotoBukti: m.FotoBukti,
	}
}

// daftarImunisasiMandiri: untuk KartuBalita.
func (s *ImunisasiService) daftarImunisasiMandiri(balita *models.Balita) []ImunisasiMandiriResp {
	out := []ImunisasiMandiriResp{}
	list, err := s.repo.ListImunisasiMandiri(balita.ID)
	if err != nil {
		return out
	}
	for i := range list {
		out = append(out, imunisasiMandiriResp(&list[i], balita.TanggalLahir))
	}
	return out
}

// CatatRiwayatAwal: bidan mencatat riwayat imunisasi balita sebelum posyandu (sekali, kunjungan pertama).
func (s *ImunisasiService) CatatRiwayatAwal(bidanID uint, pos string, balitaID uuid.UUID, in RiwayatAwalBidanInput) (*KartuImunisasiResp, error) {
	balita, err := s.CekAkses(balitaID, bidanID, "bidan", pos)
	if err != nil {
		return nil, err
	}
	if balita.StatusRiwayatImunisasi == models.RiwayatImunisasiDikonfirmasi {
		return nil, konflik("riwayat imunisasi balita ini sudah dicatat; imunisasi dari luar posyandu berikutnya dicatat lewat menu Imunisasi Susulan")
	}
	if n := s.repo.JumlahMenungguKonfirmasi(balita.ID); n > 0 {
		return nil, konflik("masih ada %d laporan imunisasi lama dari orang tua yang belum dicek; benarkan atau batalkan terlebih dahulu", n)
	}

	status := strings.TrimSpace(in.Status)
	switch status {
	case "belum_pernah":
		if len(in.Items) > 0 || len(in.Mandiri) > 0 {
			return nil, validasi("pilihan \"belum pernah\" tidak boleh disertai daftar imunisasi")
		}
	case "sudah":
		if len(in.Items) == 0 && len(in.Mandiri) == 0 {
			// boleh kosong bila sudah ada catatan imunisasi luar sebelumnya (mis. laporan lama yang sudah dibenarkan)
			if luar, err := s.RiwayatLuar(balita); err != nil || len(luar) == 0 {
				return nil, validasi("centang minimal satu imunisasi atau tambahkan imunisasi mandiri")
			}
		}
	default:
		return nil, validasi("status riwayat imunisasi harus sudah atau belum_pernah")
	}

	lahir := tglSaja(balita.TanggalLahir)
	hari := hariIni()

	err = s.repo.Tx(func(r *repository.ImunisasiRepository) error {
		// ------------------------------------------------ imunisasi program (centang)
		items := make([]itemRiwayat, 0, len(in.Items))
		baru := make([]models.ImunisasiBalita, 0, len(in.Items))
		for _, x := range in.Items {
			if x.JenisImunisasiID == uuid.Nil || x.DosisKe < 1 {
				return validasi("imunisasi yang dicentang tidak valid, muat ulang halaman")
			}
			tgl, err := time.Parse(imunisasiTglLayout, strings.TrimSpace(x.TanggalPemberian))
			if err != nil {
				return validasi("tanggal pemberian setiap imunisasi wajib diisi (YYYY-MM-DD)")
			}
			tempat, err := batasTeks(x.Tempat, 100, "tempat")
			if err != nil {
				return err
			}
			if tempat == "" {
				return validasi("tempat pemberian setiap imunisasi wajib diisi (mis. RSUD Porsea)")
			}
			foto, err := cekNamaBukti(x.FotoBukti)
			if err != nil {
				return err
			}
			items = append(items, itemRiwayat{JenisImunisasiID: x.JenisImunisasiID, DosisKe: x.DosisKe, Tanggal: tgl})
			baru = append(baru, models.ImunisasiBalita{
				BalitaID: balita.ID, JenisImunisasiID: x.JenisImunisasiID, DosisKe: x.DosisKe,
				TanggalPemberian: tglSaja(tgl), Tempat: tempat, FotoBukti: foto,
				Sumber: models.SumberImunisasiLuar, StatusKonfirmasi: models.KonfirmasiImunisasiOK,
				DiberikanOleh: bidanID, Version: 1,
			})
		}
		// dosis dobel, urutan dosis, usia, jarak minimal, tanggal (aturan yang sama dengan posyandu)
		if err := validasiRiwayat(r, balita, items, nil, nil); err != nil {
			return err
		}
		for i := range baru {
			if err := r.CreateRiwayat(&baru[i]); err != nil {
				return err
			}
		}

		// ------------------------------------------------ imunisasi mandiri (di luar program)
		dipakai := map[string]bool{}
		for _, x := range in.Mandiri {
			nama, err := batasTeks(x.NamaImunisasi, 100, "nama imunisasi")
			if err != nil {
				return err
			}
			if nama == "" {
				return validasi("nama imunisasi mandiri wajib diisi")
			}
			if x.DosisKe < 1 || x.DosisKe > 10 {
				return validasi("dosis %s harus antara 1 dan 10", nama)
			}
			kunci := fmt.Sprintf("%s|%d", strings.ToLower(nama), x.DosisKe)
			if dipakai[kunci] || r.ImunisasiMandiriAda(balita.ID, nama, x.DosisKe) {
				return konflik("%s dosis %d sudah tercatat", nama, x.DosisKe)
			}
			dipakai[kunci] = true
			tgl, err := time.Parse(imunisasiTglLayout, strings.TrimSpace(x.TanggalPemberian))
			if err != nil {
				return validasi("tanggal pemberian %s wajib diisi (YYYY-MM-DD)", nama)
			}
			tgl = tglSaja(tgl)
			if tgl.Before(lahir) || tgl.After(hari) {
				return validasi("tanggal %s harus antara tanggal lahir balita dan hari ini", nama)
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
			m := models.ImunisasiMandiriBalita{
				BalitaID: balita.ID, NamaImunisasi: nama, DosisKe: x.DosisKe, TanggalPemberian: tgl,
				Tempat: tempat, FotoBukti: foto, DicatatOleh: bidanID,
			}
			if err := r.CreateImunisasiMandiri(&m); err != nil {
				return err
			}
		}

		// ------------------------------------------------ status: sudah dicatat bidan
		now := time.Now()
		oleh := bidanID
		return r.SimpanStatusRiwayat(balita.ID, models.RiwayatImunisasiDikonfirmasi, &oleh, &now)
	})
	if err != nil {
		return nil, err
	}
	return s.KartuBalita(balita.ID, bidanID, "bidan", pos)
}

// HapusImunisasiMandiri: bidan menghapus catatan imunisasi mandiri yang salah.
func (s *ImunisasiService) HapusImunisasiMandiri(bidanID uint, pos string, id uuid.UUID) error {
	m, err := s.repo.GetImunisasiMandiri(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrImunisasiMandiriTidakAda
	}
	if err != nil {
		return err
	}
	if _, err := s.CekAkses(m.BalitaID, bidanID, "bidan", pos); err != nil {
		return err
	}
	return s.repo.HapusImunisasiMandiri(id)
}