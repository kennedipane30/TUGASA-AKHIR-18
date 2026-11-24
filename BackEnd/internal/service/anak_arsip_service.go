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
//   - Manual oleh kader : anak pindah domisili, meninggal, atau alasan lain.
//   - Otomatis (sistem) : anak berusia 60 bulan -> "Lulus balita (usia 5 tahun)".
//
// Anak arsip tidak muncul lagi di pendaftaran, pendataan, daftar balita,
// deteksi dini, rekap, dan pengingat. Riwayat pemeriksaan, kartu vaksin, dan
// rujukan tetap tersimpan dan dapat dilihat.
// ============================================================================

type AnakArsipService struct {
	repo *repository.AnakArsipRepository
}

func NewAnakArsipService(r *repository.AnakArsipRepository) *AnakArsipService {
	return &AnakArsipService{repo: r}
}

// ArsipAnakInput: isian kader saat mengarsipkan anak.
type ArsipAnakInput struct {
	Alasan     string `json:"alasan" binding:"required"`  // pindah | meninggal | lainnya
	Tanggal    string `json:"tanggal" binding:"required"` // YYYY-MM-DD
	Keterangan string `json:"keterangan"`                 // wajib bila alasan = lainnya
}

// anakKader: anak [anakID] yang keluarganya berada di posyandu kader.
func (s *AnakArsipService) anakKader(pos string, anakID uuid.UUID) (*models.Anak, error) {
	pos, err := posKader(pos)
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
	k, err := s.repo.GetKeluarga(a.KeluargaID)
	if err != nil {
		return nil, err
	}
	if kp, _ := models.NormalisasiPosyandu(k.Posyandu); kp != pos {
		return nil, terlarang("anak bukan bagian dari posyandu Anda")
	}
	return a, nil
}

// Arsipkan: kader mengarsipkan anak (pindah / meninggal / lainnya).
func (s *AnakArsipService) Arsipkan(pos string, anakID uuid.UUID, in ArsipAnakInput) (*models.Anak, error) {
	a, err := s.anakKader(pos, anakID)
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

// Aktifkan: kader mengaktifkan kembali anak arsip (salah arsip / kembali ke desa).
// Anak yang sudah berusia 60 bulan tidak dapat diaktifkan (bukan balita lagi).
func (s *AnakArsipService) Aktifkan(pos string, anakID uuid.UUID) (*models.Anak, error) {
	a, err := s.anakKader(pos, anakID)
	if err != nil {
		return nil, err
	}
	if a.Status != models.StatusAnakArsip {
		return nil, konflik("data anak masih aktif")
	}
	if usiaBulan(tglSaja(a.TanggalLahir), hariIni()) > batasUsiaBalita {
		return nil, konflik("anak sudah berusia 5 tahun (lulus balita) sehingga tidak dapat diaktifkan kembali")
	}
	if err := s.repo.Aktifkan(a.ID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, konflik("data anak masih aktif")
		}
		return nil, err
	}
	return s.repo.GetAnak(anakID)
}

// LulusBalita: arsipkan anak yang sudah berusia 60 bulan. Aman dijalankan berulang.
func (s *AnakArsipService) LulusBalita() {
	// usia >= 60 bulan  <=>  lahir pada/sebelum (hari ini - 60 bulan)
	batas := hariIni().AddDate(0, -(batasUsiaBalita + 1), 0)
	n, err := s.repo.LulusBalita(batas)
	if err != nil {
		log.Printf("arsip anak: gagal memproses lulus balita: %v", err)
		return
	}
	if n > 0 {
		log.Printf("arsip anak: %d anak lulus balita diarsipkan otomatis", n)
	}
}

// JalankanLulusBalita: diperiksa saat server mulai, lalu setiap jam
// (diproses sekali per hari, saat tanggal berganti).
func (s *AnakArsipService) JalankanLulusBalita(ctx context.Context) {
	terakhir := hariIni()
	s.LulusBalita()
	t := time.NewTicker(time.Hour)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if h := hariIni(); !h.Equal(terakhir) {
				terakhir = h
				s.LulusBalita()
			}
		}
	}
}