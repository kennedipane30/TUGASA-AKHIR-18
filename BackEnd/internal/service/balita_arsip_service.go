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
// ARSIP DATA BALITA
//
//   - Manual oleh kader : balita pindah domisili, meninggal, atau alasan lain.
//   - Otomatis (sistem) : balita berusia 60 bulan -> "Lulus balita (usia 5 tahun)".
//
// Balita arsip tidak muncul lagi di pendaftaran, pendataan, daftar balita,
// deteksi dini, rekap, dan pengingat. Riwayat pemeriksaan, kartu imunisasi, dan
// rujukan tetap tersimpan dan dapat dilihat.
// ============================================================================

type BalitaArsipService struct {
	repo *repository.BalitaArsipRepository
}

func NewBalitaArsipService(r *repository.BalitaArsipRepository) *BalitaArsipService {
	return &BalitaArsipService{repo: r}
}

// ArsipBalitaInput: isian kader saat mengarsipkan balita.
type ArsipBalitaInput struct {
	Alasan     string `json:"alasan" binding:"required"`  // pindah | meninggal | lainnya
	Tanggal    string `json:"tanggal" binding:"required"` // YYYY-MM-DD
	Keterangan string `json:"keterangan"`                 // wajib bila alasan = lainnya
}

// balitaKader: balita [balitaID] yang keluarganya berada di posyandu kader.
func (s *BalitaArsipService) balitaKader(pos string, balitaID uuid.UUID) (*models.Balita, error) {
	pos, err := posKader(pos)
	if err != nil {
		return nil, err
	}
	a, err := s.repo.GetBalita(balitaID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrBalitaTidakAda
	}
	if err != nil {
		return nil, err
	}
	k, err := s.repo.GetKeluarga(a.KeluargaID)
	if err != nil {
		return nil, err
	}
	if kp, _ := models.NormalisasiPosyandu(k.Posyandu); kp != pos {
		return nil, terlarang("balita bukan bagian dari posyandu Anda")
	}
	return a, nil
}

// Arsipkan: kader mengarsipkan balita (pindah / meninggal / lainnya).
func (s *BalitaArsipService) Arsipkan(pos string, balitaID uuid.UUID, in ArsipBalitaInput) (*models.Balita, error) {
	a, err := s.balitaKader(pos, balitaID)
	if err != nil {
		return nil, err
	}
	if a.Status == models.StatusBalitaArsip {
		return nil, konflik("data balita sudah diarsipkan")
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
		return nil, validasi("tanggal arsip tidak boleh sebelum tanggal lahir balita")
	}

	if err := s.repo.Arsipkan(a.ID, tgl, alasan); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, konflik("data balita sudah diarsipkan")
		}
		return nil, err
	}
	return s.repo.GetBalita(balitaID)
}

// Aktifkan: kader mengaktifkan kembali balita arsip (salah arsip / kembali ke desa).
// Balita yang sudah berusia 60 bulan tidak dapat diaktifkan (bukan balita lagi).
func (s *BalitaArsipService) Aktifkan(pos string, balitaID uuid.UUID) (*models.Balita, error) {
	a, err := s.balitaKader(pos, balitaID)
	if err != nil {
		return nil, err
	}
	if a.Status != models.StatusBalitaArsip {
		return nil, konflik("data balita masih aktif")
	}
	if usiaBulan(tglSaja(a.TanggalLahir), hariIni()) > batasUsiaBalita {
		return nil, konflik("balita sudah berusia 5 tahun (lulus balita) sehingga tidak dapat diaktifkan kembali")
	}
	if err := s.repo.Aktifkan(a.ID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, konflik("data balita masih aktif")
		}
		return nil, err
	}
	return s.repo.GetBalita(balitaID)
}

// LulusBalita: arsipkan balita yang sudah berusia 60 bulan. Aman dijalankan berulang.
func (s *BalitaArsipService) LulusBalita() {
	// usia >= 60 bulan  <=>  lahir pada/sebelum (hari ini - 60 bulan)
	batas := hariIni().AddDate(0, -(batasUsiaBalita + 1), 0)
	n, err := s.repo.LulusBalita(batas)
	if err != nil {
		log.Printf("arsip balita: gagal memproses lulus balita: %v", err)
		return
	}
	if n > 0 {
		log.Printf("arsip balita: %d balita lulus balita diarsipkan otomatis", n)
	}
}

// JalankanLulusBalita: diperiksa saat server mulai, lalu setiap jam
// (diproses sekali per hari, saat tanggal berganti).
func (s *BalitaArsipService) JalankanLulusBalita(ctx context.Context) {
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