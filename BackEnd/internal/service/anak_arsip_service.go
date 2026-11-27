package service

import (
	"context"
	"errors"
	"log"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ============================================================================
// ARSIP DATA ANAK
//
//   - Manual oleh orang tua (Data Keluarga > Data Anak): anak pindah domisili,
//     meninggal, atau alasan lain.
//   - Otomatis (sistem) : anak berusia 60 bulan -> "Lulus posyandu (usia 5 tahun)".
//
// Anak arsip tidak muncul lagi di pendaftaran, pendataan, daftar anak,
// deteksi dini, rekap, dan pengingat. Riwayat pemeriksaan, kartu imunisasi, dan
// rujukan tetap tersimpan dan dapat dilihat.
// ============================================================================

type AnakArsipService struct {
	repo *repository.AnakArsipRepository
}

func NewAnakArsipService(r *repository.AnakArsipRepository) *AnakArsipService {
	return &AnakArsipService{repo: r}
}

// ArsipAnakInput: isian orang tua saat mengarsipkan anak.
type ArsipAnakInput struct {
	Alasan     string `json:"alasan" binding:"required"`  // pindah | meninggal | lainnya
	Tanggal    string `json:"tanggal" binding:"required"` // YYYY-MM-DD
	Keterangan string `json:"keterangan"`                 // wajib bila alasan = lainnya
}

// anakOrangTua: anak [anakID] yang terdaftar di keluarga milik akun orang tua [uid].
func (s *AnakArsipService) anakOrangTua(uid uint, anakID uuid.UUID) (*models.Anak, error) {
	kid, err := s.repo.KeluargaIDOrangTua(uid)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, terlarang("data keluarga belum ada")
	}
	if err != nil {
		return nil, err
	}
	a, err := s.repo.GetAnak(anakID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAnakTidakAda
	}
	if err != nil {
		return nil, err
	}
	if a.KeluargaID != kid {
		return nil, terlarang("anak bukan bagian dari keluarga Anda")
	}
	return a, nil
}

// Arsipkan: orang tua mengarsipkan anaknya (pindah / meninggal / lainnya).
func (s *AnakArsipService) Arsipkan(uid uint, anakID uuid.UUID, in ArsipAnakInput) (*models.Anak, error) {
	a, err := s.anakOrangTua(uid, anakID)
	if err != nil {
		return nil, err
	}
	if a.Status == models.StatusAnakArsip {
		return nil, konflik("data anak sudah diarsipkan")
	}

	var alasan string
	switch strings.ToLower(strings.TrimSpace(in.Alasan)) {
	case "pindah":
		alasan = models.AlasanArsipPindah
	case "meninggal":
		alasan = models.AlasanArsipMeninggal
	case "lainnya":
		alasan = models.AlasanArsipLainnya
	default:
		return nil, validasi("alasan arsip tidak valid (pindah | meninggal | lainnya)")
	}
	ket, err := batasTeks(in.Keterangan, 80, "keterangan")
	if err != nil {
		return nil, err
	}
	if alasan == models.AlasanArsipLainnya && ket == "" {
		return nil, validasi("keterangan wajib diisi untuk alasan lainnya")
	}
	if ket != "" {
		alasan += ": " + ket
	}

	tgl, err := time.Parse("2006-01-02", strings.TrimSpace(in.Tanggal))
	if err != nil {
		return nil, validasi("format tanggal harus YYYY-MM-DD")
	}
	if tgl.After(hariIni()) {
		return nil, validasi("tanggal arsip tidak boleh melewati hari ini")
	}
	if tgl.Before(tglSaja(a.TanggalLahir)) {
		return nil, validasi("tanggal arsip tidak boleh sebelum tanggal lahir anak")
	}

	if err := s.repo.Arsipkan(a.ID, tgl, alasan); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, konflik("data anak sudah diarsipkan")
		}
		return nil, err
	}
	return s.repo.GetAnak(anakID)
}

// Aktifkan: orang tua mengaktifkan kembali anak arsip (salah arsip / kembali ke desa).
// Anak yang sudah berusia 60 bulan tidak dapat diaktifkan (sudah melewati batas usia layanan).
func (s *AnakArsipService) Aktifkan(uid uint, anakID uuid.UUID) (*models.Anak, error) {
	a, err := s.anakOrangTua(uid, anakID)
	if err != nil {
		return nil, err
	}
	if a.Status != models.StatusAnakArsip {
		return nil, konflik("data anak masih aktif")
	}
	if usiaBulan(tglSaja(a.TanggalLahir), hariIni()) > batasUsiaAnak {
		return nil, konflik("anak sudah berusia 5 tahun (lulus posyandu) sehingga tidak dapat diaktifkan kembali")
	}
	if err := s.repo.Aktifkan(a.ID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, konflik("data anak masih aktif")
		}
		return nil, err
	}
	return s.repo.GetAnak(anakID)
}

// LulusAnak: arsipkan anak yang sudah berusia 60 bulan. Aman dijalankan berulang.
func (s *AnakArsipService) LulusAnak() {
	// usia >= 60 bulan  <=>  lahir pada/sebelum (hari ini - 60 bulan)
	batas := hariIni().AddDate(0, -(batasUsiaAnak + 1), 0)
	n, err := s.repo.LulusAnak(batas)
	if err != nil {
		log.Printf("arsip anak: gagal memproses lulus posyandu: %v", err)
		return
	}
	if n > 0 {
		log.Printf("arsip anak: %d anak lulus posyandu diarsipkan otomatis", n)
	}
}

// JalankanLulusAnak: diperiksa saat server mulai, lalu setiap jam
// (diproses sekali per hari, saat tanggal berganti).
func (s *AnakArsipService) JalankanLulusAnak(ctx context.Context) {
	terakhir := hariIni()
	s.LulusAnak()
	t := time.NewTicker(time.Hour)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if h := hariIni(); !h.Equal(terakhir) {
				terakhir = h
				s.LulusAnak()
			}
		}
	}
}