package service

// PelayananService menangani satu sesi pelayanan posyandu, dari pendataan
// kader sampai pemeriksaan bidan.
//
// Berkas ini berisi rangka service-nya beserta pembantu yang dipakai bersama:
// perhitungan usia, waktu mulai sesi, validasi rentang angka, dan pencarian
// pendaftaran/jadwal beserta pemeriksaan hak akses posyandu.
//
// Tiap fiturnya ada di berkas tersendiri:
//
//	pengukuran_service.go           pendataan kader: antrean dan pengukuran anak
//	pemeriksaan_service.go          pemeriksaan bidan: antrean, detail, simpan catatan
//	kpsp_service.go                 skrining perkembangan (KPSP)
//	riwayat_pemeriksaan_service.go  riwayat pemeriksaan untuk orang tua
//	riwayat_jadwal_service.go       riwayat jadwal posyandu

import (
	"errors"
	"regexp"
	"strconv"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PelayananService menangani pelayanan posyandu: pendataan kader, pemeriksaan
// bidan, KPSP, dan riwayat untuk orang tua.
//
// Berkas ini hanya berisi rangka service-nya. Tiap fitur ada di berkasnya
// sendiri, satu berkas satu fitur:
//
//	pelayanan_bantu.go    pembantu bersama: usia, waktu sesi, pencarian pendaftaran
//	pelayanan_kader.go    antrean kader dan pencatatan pengukuran
//	pelayanan_bidan.go    antrean bidan, detail, dan penyimpanan catatan
//	pelayanan_kpsp.go     skrining perkembangan (KPSP)
//	pelayanan_riwayat.go  riwayat pemeriksaan untuk orang tua


type PelayananService struct {
	jadwal *repository.JadwalRepository
	repo   *repository.PelayananRepository
	kel    *repository.KeluargaRepository
	gizi   *StatusGiziService
	imunisasi *ImunisasiService
	kbm    *KbmService
	notif  *NotifikasiService
}

func NewPelayananService(j *repository.JadwalRepository, p *repository.PelayananRepository, k *repository.KeluargaRepository) *PelayananService {
	return &PelayananService{jadwal: j, repo: p, kel: k}
}

// SetStatusGizi mengaktifkan perhitungan status gizi otomatis setiap pengukuran disimpan.
func (s *PelayananService) SetStatusGizi(g *StatusGiziService) { s.gizi = g }

// SetKbm mengaktifkan penilaian N/T (KBM), 2T, dan BGM setiap pengukuran disimpan.
func (s *PelayananService) SetKbm(k *KbmService) { s.kbm = k }

// SetImunisasi mengaktifkan validasi imunisasi berdasarkan jadwal imunisasi Kemenkes.
func (s *PelayananService) SetImunisasi(v *ImunisasiService) { s.imunisasi = v }

// SetNotifikasi mengaktifkan "Rencana Hari Ini" (imunisasi, Vitamin A, obat cacing) di catatan bidan.
func (s *PelayananService) SetNotifikasi(n *NotifikasiService) { s.notif = n }
// Pembantu bersama PelayananService: perhitungan usia, waktu mulai sesi
// posyandu, validasi rentang angka, dan pencarian pendaftaran/jadwal beserta
// pemeriksaan hak akses posyandu.


func usiaBulan(lahir, pada time.Time) int {
	b := (pada.Year()-lahir.Year())*12 + int(pada.Month()-lahir.Month())
	if pada.Day() < lahir.Day() {
		b--
	}
	if b < 0 {
		b = 0
	}
	return b
}

func parseTanggalMendatang(s string) (*time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return nil, validasi("tanggal kunjungan ulang harus berformat YYYY-MM-DD")
	}
	if t.Before(hariIni()) {
		return nil, validasi("tanggal kunjungan ulang tidak boleh sebelum hari ini")
	}
	return &t, nil
}

// ---------------------------------------------------------------- waktu sesi

var polaJamSesi = regexp.MustCompile(`(\d{1,2})[:.](\d{2})`)

// mulaiSesiPendataan: waktu mulai sesi posyandu (tanggal jadwal + jam mulai, zona waktu server).
func mulaiSesiPendataan(j *models.JadwalPosyandu) (time.Time, bool) {
	if j == nil {
		return time.Time{}, false
	}
	m := polaJamSesi.FindStringSubmatch(j.JamMulai)
	if m == nil {
		return time.Time{}, false
	}
	jam, _ := strconv.Atoi(m[1])
	menit, _ := strconv.Atoi(m[2])
	t := j.Tanggal
	return time.Date(t.Year(), t.Month(), t.Day(), jam, menit, 0, 0, time.Local), true
}

// cekSesiSudahMulai: pendataan kader dan bidan hanya boleh setelah sesi posyandu dimulai.
func cekSesiSudahMulai(j *models.JadwalPosyandu) error {
	mulai, ok := mulaiSesiPendataan(j)
	if !ok {
		return nil
	}
	if time.Now().Before(mulai) {
		return konflik("sesi posyandu belum dimulai, pendataan dapat dilakukan mulai %s pukul %s WIB",
			mulai.Format("02-01-2006"), mulai.Format("15:04"))
	}
	return nil
}

func rentang(v float64, min, maks float64, nama string) error {
	if v < min || v > maks {
		return validasi("%s tidak wajar (%.0f-%.0f)", nama, min, maks)
	}
	return nil
}

func (s *PelayananService) pendaftaran(id uuid.UUID) (*models.Pendaftaran, error) {
	p, err := s.jadwal.GetPendaftaran(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrPendaftaranTidakAda
	}
	return p, err
}

// pendaftaranPos: pendaftaran hanya boleh diakses staf dari posyandu pemilik jadwal.
func (s *PelayananService) pendaftaranPos(id uuid.UUID, pos string) (*models.Pendaftaran, error) {
	p, err := s.pendaftaran(id)
	if err != nil {
		return nil, err
	}
	if p.Jadwal == nil {
		return nil, ErrJadwalTidakAda
	}
	if err := jadwalMilik(p.Jadwal, pos); err != nil {
		return nil, err
	}
	return p, nil
}

// jadwalPos: jadwal hanya boleh diakses staf dari posyandu pemilik jadwal.
func (s *PelayananService) jadwalPos(jadwalID uuid.UUID, pos string) (*models.JadwalPosyandu, error) {
	j, err := s.jadwal.GetJadwal(jadwalID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrJadwalTidakAda
	}
	if err != nil {
		return nil, err
	}
	if err := jadwalMilik(j, pos); err != nil {
		return nil, err
	}
	return j, nil
}

// petaPenilaian: penilaian N/T per pengukuran_id (kosong bila KBM tidak aktif).
func (s *PelayananService) petaPenilaian(ukur []models.Pengukuran) (map[uuid.UUID]models.PenilaianTimbang, error) {
	if s.kbm == nil {
		return map[uuid.UUID]models.PenilaianTimbang{}, nil
	}
	ids := make([]uuid.UUID, 0, len(ukur))
	for _, u := range ukur {
		ids = append(ids, u.ID)
	}
	return s.kbm.PetaPengukuran(ids)
}

func idPendaftaran(list []models.Pendaftaran) []uuid.UUID {
	ids := make([]uuid.UUID, 0, len(list))
	for _, p := range list {
		ids = append(ids, p.ID)
	}
	return ids
}