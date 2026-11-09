package service

import (
	"errors"
	"fmt"
	"log"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PelayananService struct {
	jadwal *repository.JadwalRepository
	repo   *repository.PelayananRepository
	kel    *repository.KeluargaRepository
	gizi   *StatusGiziService
	vaksin *VaksinService
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

// SetVaksin mengaktifkan validasi vaksin berdasarkan jadwal imunisasi Kemenkes.
func (s *PelayananService) SetVaksin(v *VaksinService) { s.vaksin = v }

// SetNotifikasi mengaktifkan "Rencana Hari Ini" (imunisasi, Vitamin A, obat cacing) di catatan bidan.
func (s *PelayananService) SetNotifikasi(n *NotifikasiService) { s.notif = n }

// ---------------------------------------------------------------- input

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

type VaksinInput struct {
	JenisVaksinID string `json:"jenis_vaksin_id" binding:"required"`
	DosisKe       int16  `json:"dosis_ke" binding:"required"`
	KondisiAnak   string `json:"kondisi_anak"` // sehat | demam_ringan (sakit = imunisasi ditunda)
	NomorBatch    string `json:"nomor_batch"`  // opsional
	ReaksiKipi    string `json:"reaksi_kipi"`  // opsional, reaksi setelah imunisasi
	Catatan       string `json:"catatan"`
}

// SuplemenInput: suplemen diinput manual oleh bidan (nama, dosis, jumlah, satuan).
type SuplemenInput struct {
	Nama    string `json:"nama" binding:"required"`
	Dosis   string `json:"dosis"`
	Jumlah  int16  `json:"jumlah"`
	Satuan  string `json:"satuan"`
	Catatan string `json:"catatan"`
}

// CatatanBidanInput: Demam/Diare/Batuk, PenyakitPenyerta, dan SaranPolaAsuh tidak lagi
// ditampilkan di aplikasi (kolom tetap ada untuk data lama). Keluhan diisi manual.
type CatatanBidanInput struct {
	Demam                 bool            `json:"demam"`
	Diare                 bool            `json:"diare"`
	Batuk                 bool            `json:"batuk"`
	PenyakitPenyerta      string          `json:"penyakit_penyerta"`
	Keluhan               string          `json:"keluhan"`
	CatatanEvaluasi       string          `json:"catatan_evaluasi"`
	SaranGizi             string          `json:"saran_gizi"`
	SaranPolaAsuh         string          `json:"saran_pola_asuh"`
	TanggalKunjunganUlang string          `json:"tanggal_kunjungan_ulang"` // YYYY-MM-DD
	Vaksin                []VaksinInput   `json:"vaksin"`
	Suplemen              []SuplemenInput `json:"suplemen"`
}

// ---------------------------------------------------------------- keluaran

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

type BidanItem struct {
	PendaftaranID      uuid.UUID                `json:"pendaftaran_id"`
	AnakID             uuid.UUID                `json:"anak_id"`
	Nama               string                   `json:"nama"`
	JenisKelamin       string                   `json:"jenis_kelamin"`
	TanggalLahir       string                   `json:"tanggal_lahir"` // YYYY-MM-DD, untuk usia detail di aplikasi
	UsiaBulan          int                      `json:"usia_bulan"`
	NomorAntrean       *int16                   `json:"nomor_antrean"`
	SudahDiukur        bool                     `json:"sudah_diukur"`
	BbKg               float64                  `json:"bb_kg"`
	TbCm               float64                  `json:"tb_cm"`
	PeringatanValidasi string                   `json:"peringatan_validasi"`
	StatusCatatan      string                   `json:"status_catatan"` // perlu_catatan | selesai
	StatusGizi         *models.StatusGizi       `json:"status_gizi"`
	Penilaian          *models.PenilaianTimbang `json:"penilaian"`
}

type DetailBidan struct {
	Anak             models.Anak              `json:"anak"`
	Jadwal           models.JadwalPosyandu    `json:"jadwal"`
	UsiaBulan        int                      `json:"usia_bulan"`
	Pengukuran       *models.Pengukuran       `json:"pengukuran"`
	Sebelumnya       *models.Pengukuran       `json:"pengukuran_sebelumnya"`
	StatusGizi       *models.StatusGizi       `json:"status_gizi"`
	Penilaian        *models.PenilaianTimbang `json:"penilaian"`
	Catatan          *models.PemeriksaanBidan `json:"catatan"`
	Imunisasi        []models.ImunisasiAnak   `json:"imunisasi"`
	Suplemen         []models.SuplemenAnak    `json:"suplemen"`
	RiwayatImunisasi []models.ImunisasiAnak   `json:"riwayat_imunisasi"`
	Rencana          *RencanaAnak             `json:"rencana"` // rencana imunisasi & suplemen kunjungan ini

	// Riwayat vaksin sebelum posyandu: harus dikonfirmasi bidan sebelum imunisasi diberikan.
	StatusRiwayatVaksin string              `json:"status_riwayat_vaksin"`
	RiwayatLuar         []RiwayatVaksinResp `json:"riwayat_luar"`
}

type PengukuranRiwayat struct {
	TanggalUkur     time.Time `json:"tanggal_ukur"`
	UsiaBulan       int16     `json:"usia_bulan"`
	BbKg            float64   `json:"bb_kg"`
	TbCm            float64   `json:"tb_cm"`
	CaraUkur        string    `json:"cara_ukur"`
	LingkarKepalaCm *float64  `json:"lingkar_kepala_cm"`
	LilaCm          *float64  `json:"lila_cm"`
}

type RiwayatItem struct {
	PendaftaranID uuid.UUID                `json:"pendaftaran_id"`
	AnakID        uuid.UUID                `json:"anak_id"`
	NamaAnak      string                   `json:"nama_anak"`
	Tanggal       time.Time                `json:"tanggal"`
	JamMulai      string                   `json:"jam_mulai"`
	Pengukuran    *PengukuranRiwayat       `json:"pengukuran"`
	StatusGizi    *models.StatusGizi       `json:"status_gizi"`
	Penilaian     *models.PenilaianTimbang `json:"penilaian"`
	Catatan       *models.PemeriksaanBidan `json:"catatan"`
	Imunisasi     []models.ImunisasiAnak   `json:"imunisasi"`
	Suplemen      []models.SuplemenAnak    `json:"suplemen"`
}

// ---------------------------------------------------------------- fungsi bantu

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

// ---------------------------------------------------------------- kader

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
			StatusData:    "tersinkron",
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

// ---------------------------------------------------------------- bidan

// AntreanBidan: semua anak yang sudah check-in pada satu jadwal di posyandu bidan.
func (s *PelayananService) AntreanBidan(jadwalID uuid.UUID, pos string) ([]BidanItem, error) {
	if _, err := s.jadwalPos(jadwalID, pos); err != nil {
		return nil, err
	}
	list, err := s.jadwal.ListPendaftaranJadwal(jadwalID, "sudah_checkin")
	if err != nil {
		return nil, err
	}
	ids := idPendaftaran(list)
	ukur, err := s.repo.ListPengukuran(ids)
	if err != nil {
		return nil, err
	}
	periksa, err := s.repo.ListPemeriksaan(ids)
	if err != nil {
		return nil, err
	}
	petaUkur := map[uuid.UUID]models.Pengukuran{}
	for _, u := range ukur {
		petaUkur[u.PendaftaranID] = u
	}
	adaCatatan := map[uuid.UUID]bool{}
	for _, c := range periksa {
		adaCatatan[c.PendaftaranID] = true
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
	nilai, err := s.petaPenilaian(ukur)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	out := make([]BidanItem, 0, len(list))
	for _, p := range list {
		u, diukur := petaUkur[p.ID]
		it := BidanItem{
			PendaftaranID:      p.ID,
			AnakID:             p.AnakID,
			NomorAntrean:       p.NomorAntrean,
			SudahDiukur:        diukur,
			BbKg:               u.BbKg,
			TbCm:               u.TbCm,
			PeringatanValidasi: u.PeringatanValidasi,
			StatusCatatan:      "perlu_catatan",
		}
		if adaCatatan[p.ID] {
			it.StatusCatatan = "selesai"
		}
		if g, ok := petaGizi[u.ID]; diukur && ok {
			gg := g
			it.StatusGizi = &gg
		}
		if n, ok := nilai[u.ID]; diukur && ok {
			nn := n
			it.Penilaian = &nn
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

// DetailBidan: pengukuran boleh kosong (kader belum mengukur).
func (s *PelayananService) DetailBidan(pos string, pendaftaranID uuid.UUID) (*DetailBidan, error) {
	p, err := s.pendaftaranPos(pendaftaranID, pos)
	if err != nil {
		return nil, err
	}
	if p.Anak == nil {
		return nil, ErrPendaftaranTidakAda
	}

	d := &DetailBidan{
		Anak:      *p.Anak,
		Jadwal:    *p.Jadwal,
		UsiaBulan: usiaBulan(p.Anak.TanggalLahir, time.Now()),
	}
	if m, err := s.repo.GetPengukuran(p.ID); err == nil {
		d.Pengukuran = m
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if d.Pengukuran != nil && s.gizi != nil {
		if d.StatusGizi, err = s.gizi.UntukPengukuran(d.Pengukuran.ID); err != nil {
			return nil, err
		}
	}
	if d.Pengukuran != nil && s.kbm != nil {
		if d.Penilaian, err = s.kbm.UntukPengukuran(d.Pengukuran.ID); err != nil {
			return nil, err
		}
	}
	if prev, err := s.repo.PengukuranSebelumnya(p.AnakID, p.ID); err == nil {
		d.Sebelumnya = prev
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if c, err := s.repo.GetPemeriksaan(p.ID); err == nil {
		d.Catatan = c
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if d.Imunisasi, err = s.repo.ListImunisasi([]uuid.UUID{p.ID}); err != nil {
		return nil, err
	}
	sup, err := s.repo.ListSuplemen([]uuid.UUID{p.ID})
	if err != nil {
		return nil, err
	}
	d.Suplemen = sup
	if d.RiwayatImunisasi, err = s.repo.ListImunisasiAnak(p.AnakID); err != nil {
		return nil, err
	}
	d.Rencana = s.notif.RencanaPendaftaran(p.Anak, p.Jadwal, p.ID)
	d.StatusRiwayatVaksin = p.Anak.StatusRiwayatVaksin
	if d.StatusRiwayatVaksin == "" {
		d.StatusRiwayatVaksin = models.RiwayatVaksinBelumDitanya
	}
	d.RiwayatLuar = []RiwayatVaksinResp{}
	if s.vaksin != nil {
		if d.RiwayatLuar, err = s.vaksin.RiwayatLuar(p.Anak); err != nil {
			return nil, err
		}
	}
	return d, nil
}

func (s *PelayananService) ListVaksin() ([]models.JenisVaksin, error) {
	list, err := s.repo.ListVaksin()
	if err != nil {
		return nil, err
	}
	sort.SliceStable(list, func(i, j int) bool { return list[i].Urutan < list[j].Urutan })
	return list, nil
}

func (s *PelayananService) SimpanCatatan(bidanID uint, pos string, pendaftaranID uuid.UUID, in CatatanBidanInput) (*DetailBidan, error) {
	p, err := s.pendaftaranPos(pendaftaranID, pos)
	if err != nil {
		return nil, err
	}
	if err := cekSesiSudahMulai(p.Jadwal); err != nil {
		return nil, err
	}
	ukur, err := s.repo.GetPengukuran(p.ID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, konflik("kader belum menginput pengukuran")
	}
	if err != nil {
		return nil, err
	}

	// minimal satu isian
	isi := strings.TrimSpace(in.CatatanEvaluasi + in.SaranGizi + in.SaranPolaAsuh + in.Keluhan + in.PenyakitPenyerta)
	if isi == "" && len(in.Vaksin) == 0 && len(in.Suplemen) == 0 {
		return nil, validasi("isi minimal satu catatan, vaksin, atau suplemen")
	}
	ulang, err := parseTanggalMendatang(in.TanggalKunjunganUlang)
	if err != nil {
		return nil, err
	}

	// validasi vaksin (jadwal imunisasi Kemenkes: usia, urutan dosis, jarak minimal)
	daftarVaksin, err := s.repo.ListVaksin()
	if err != nil {
		return nil, err
	}
	petaVaksin := map[uuid.UUID]models.JenisVaksin{}
	for _, v := range daftarVaksin {
		petaVaksin[v.ID] = v
	}
	pid := p.ID
	tanggal := hariIni()
	vaksin := make([]models.ImunisasiAnak, 0, len(in.Vaksin))
	items := make([]ItemVaksin, 0, len(in.Vaksin))

	if len(in.Vaksin) > 0 && p.Anak != nil && !p.Anak.RiwayatVaksinSudahDikonfirmasi() {
		return nil, konflik("konfirmasi riwayat vaksin anak terlebih dahulu sebelum memberikan imunisasi")
	}

	// data reaksi (KIPI) dari catatan lama sesi ini dipertahankan
	lama := map[string]models.ImunisasiAnak{}
	if sebelumnya, err := s.repo.ListImunisasi([]uuid.UUID{p.ID}); err == nil {
		for _, x := range sebelumnya {
			lama[fmt.Sprintf("%s|%d", x.JenisVaksinID, x.DosisKe)] = x
		}
	}
	tempatPos := "Posyandu"
	if p.Jadwal != nil {
		tempatPos = "Posyandu " + notifNamaPosyandu(p.Jadwal.Posyandu)
	}
	oleh := bidanID
	now := time.Now()

	for _, v := range in.Vaksin {
		id, err := uuid.Parse(strings.TrimSpace(v.JenisVaksinID))
		if err != nil {
			return nil, validasi("jenis_vaksin_id tidak valid")
		}
		jv, ok := petaVaksin[id]
		if !ok {
			return nil, validasi("jenis vaksin tidak ditemukan atau tidak aktif")
		}
		if v.DosisKe < 1 || v.DosisKe > jv.JumlahDosis {
			return nil, validasi("dosis ke-%d tidak sesuai untuk %s (1-%d)", v.DosisKe, jv.Nama, jv.JumlahDosis)
		}
		if strings.EqualFold(jv.Kode, kodeHB0) {
			return nil, validasi("HB0 diberikan di faskes paling lambat usia 7 hari, tidak diberikan di posyandu")
		}
		if s.repo.ImunisasiSudahAda(p.AnakID, id, v.DosisKe, p.ID) {
			return nil, konflik("%s dosis ke-%d sudah tercatat untuk anak ini, tidak boleh diberikan dua kali", jv.Nama, v.DosisKe)
		}
		kondisi := strings.TrimSpace(v.KondisiAnak)
		switch kondisi {
		case models.KondisiAnakSehat, models.KondisiAnakDemamRingan:
		case models.KondisiAnakSakit:
			return nil, validasi("anak sedang sakit, tunda imunisasi sampai anak sehat")
		default:
			return nil, validasi("pilih kondisi anak sebelum imunisasi (sehat atau demam ringan)")
		}
		batch, err := batasTeks(v.NomorBatch, 50, "nomor batch")
		if err != nil {
			return nil, err
		}
		reaksi, err := batasTeks(v.ReaksiKipi, 500, "reaksi setelah imunisasi")
		if err != nil {
			return nil, err
		}
		items = append(items, ItemVaksin{JenisVaksinID: id, DosisKe: v.DosisKe})
		m := models.ImunisasiAnak{
			AnakID:           p.AnakID,
			JenisVaksinID:    id,
			DosisKe:          v.DosisKe,
			TanggalPemberian: tanggal,
			Tempat:           tempatPos,
			Sumber:           models.SumberImunisasiPosyandu,
			StatusKonfirmasi: models.KonfirmasiImunisasiOK,
			NomorBatch:       batch,
			KondisiAnak:      kondisi,
			PendaftaranID:    &pid,
			DiberikanOleh:    bidanID,
			DikonfirmasiOleh: &oleh,
			DikonfirmasiPada: &now,
			Catatan:          strings.TrimSpace(v.Catatan),
			Version:          1,
		}
		if x, ada := lama[fmt.Sprintf("%s|%d", id, v.DosisKe)]; ada {
			m.ReaksiKipi = x.ReaksiKipi
			m.KipiDilaporkanPada = x.KipiDilaporkanPada
			m.KipiTindakLanjut = x.KipiTindakLanjut
			m.KipiDitanganiOleh = x.KipiDitanganiOleh
			m.KipiDitanganiPada = x.KipiDitanganiPada
			m.TanggalPemberian = tglSaja(x.TanggalPemberian)
		}
		if reaksi != "" {
			if m.ReaksiKipi != reaksi {
				m.KipiDilaporkanPada = &now
			}
			m.ReaksiKipi = reaksi
		}
		vaksin = append(vaksin, m)
	}
	if s.vaksin != nil && p.Anak != nil {
		if err := s.vaksin.ValidasiPemberian(p.Anak, tanggal, items, &pid); err != nil {
			return nil, err
		}
	}

	// suplemen (input manual)
	suplemen := make([]models.SuplemenAnak, 0, len(in.Suplemen))
	for _, x := range in.Suplemen {
		nama := strings.TrimSpace(x.Nama)
		if nama == "" {
			return nil, validasi("nama suplemen wajib diisi")
		}
		if len([]rune(nama)) > 100 {
			return nil, validasi("nama suplemen maksimal 100 karakter")
		}
		dosis := strings.TrimSpace(x.Dosis)
		if len([]rune(dosis)) > 60 {
			return nil, validasi("dosis %s maksimal 60 karakter", nama)
		}
		satuan := strings.TrimSpace(x.Satuan)
		if len([]rune(satuan)) > 30 {
			return nil, validasi("satuan %s maksimal 30 karakter", nama)
		}
		if x.Jumlah < 1 || x.Jumlah > 999 {
			return nil, validasi("jumlah %s harus antara 1-999", nama)
		}
		// Vitamin A dan obat cacing: sesuai usia, selalu 1 kapsul/tablet.
		if p.Anak != nil {
			usiaSup := usiaBulan(p.Anak.TanggalLahir, tanggal)
			switch {
			case isVitaminA(nama):
				if usiaSup < 6 || usiaSup > batasUsiaBalita {
					return nil, validasi("Vitamin A diberikan untuk usia 6-59 bulan (usia anak %s)", usiaTeks(p.Anak.TanggalLahir, tanggal))
				}
				x.Jumlah, satuan = 1, "kapsul"
			case isObatCacing(nama):
				if usiaSup < 12 || usiaSup > batasUsiaBalita {
					return nil, validasi("obat cacing diberikan untuk usia 12-59 bulan (usia anak %s)", usiaTeks(p.Anak.TanggalLahir, tanggal))
				}
				x.Jumlah, satuan = 1, "tablet"
			}
		}
		suplemen = append(suplemen, models.SuplemenAnak{
			AnakID:          p.AnakID,
			Jenis:           nama,
			Dosis:           dosis,
			Jumlah:          x.Jumlah,
			Satuan:          satuan,
			Tanggal:         tanggal,
			KeteranganDosis: KeteranganSuplemen(dosis, x.Jumlah, satuan),
			PendaftaranID:   &pid,
			DiberikanOleh:   bidanID,
			Catatan:         strings.TrimSpace(x.Catatan),
			Version:         1,
		})
	}

	// simpan dalam satu transaksi
	err = s.repo.Tx(func(r *repository.PelayananRepository) error {
		c, err := r.GetPemeriksaan(p.ID)
		baru := false
		if errors.Is(err, gorm.ErrRecordNotFound) {
			baru = true
			c = &models.PemeriksaanBidan{
				PendaftaranID:    p.ID,
				PengukuranID:     &ukur.ID,
				BidanID:          bidanID,
				TampilKeOrangTua: true,
				Version:          1,
			}
		} else if err != nil {
			return err
		} else {
			c.BidanID = bidanID
			c.Version++
		}
		c.Demam = in.Demam
		c.Diare = in.Diare
		c.Batuk = in.Batuk
		c.PenyakitPenyerta = strings.TrimSpace(in.PenyakitPenyerta)
		c.Keluhan = strings.TrimSpace(in.Keluhan)
		c.CatatanEvaluasi = strings.TrimSpace(in.CatatanEvaluasi)
		c.SaranGizi = strings.TrimSpace(in.SaranGizi)
		c.SaranPolaAsuh = strings.TrimSpace(in.SaranPolaAsuh)
		c.TanggalKunjunganUlang = ulang
		if baru {
			err = r.CreatePemeriksaan(c)
		} else {
			err = r.SavePemeriksaan(c)
		}
		if err != nil {
			return err
		}
		if err := r.GantiImunisasi(p.ID, vaksin); err != nil {
			return err
		}
		return r.GantiSuplemen(p.ID, suplemen)
	})
	if err != nil {
		return nil, err
	}
	return s.DetailBidan(pos, p.ID)
}

// ---------------------------------------------------------------- orang tua: riwayat

// Riwayat menampilkan kunjungan yang SUDAH diberi catatan bidan, hanya untuk anak keluarga sendiri.
func (s *PelayananService) Riwayat(userID uint, anakID *uuid.UUID) ([]RiwayatItem, error) {
	kosong := []RiwayatItem{}
	ibu, err := s.kel.FindIbuByUser(userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return kosong, nil
	}
	if err != nil {
		return nil, err
	}
	anakList, err := s.kel.ListAnak(ibu.KeluargaID)
	if err != nil {
		return nil, err
	}
	nama := map[uuid.UUID]string{}
	ids := make([]uuid.UUID, 0, len(anakList))
	for _, a := range anakList {
		nama[a.ID] = a.Nama
		ids = append(ids, a.ID)
	}
	if anakID != nil {
		if _, ok := nama[*anakID]; !ok {
			return nil, terlarang("anak bukan bagian dari keluarga Anda")
		}
		ids = []uuid.UUID{*anakID}
	}
	if len(ids) == 0 {
		return kosong, nil
	}

	list, err := s.repo.RiwayatPendaftaran(ids)
	if err != nil {
		return nil, err
	}
	pids := idPendaftaran(list)
	ukur, err := s.repo.ListPengukuran(pids)
	if err != nil {
		return nil, err
	}
	periksa, err := s.repo.ListPemeriksaan(pids)
	if err != nil {
		return nil, err
	}
	imun, err := s.repo.ListImunisasi(pids)
	if err != nil {
		return nil, err
	}
	sup, err := s.repo.ListSuplemen(pids)
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

	nilai, err := s.petaPenilaian(ukur)
	if err != nil {
		return nil, err
	}
	petaUkur := map[uuid.UUID]models.Pengukuran{}
	for _, u := range ukur {
		petaUkur[u.PendaftaranID] = u
	}
	petaCatatan := map[uuid.UUID]models.PemeriksaanBidan{}
	for _, c := range periksa {
		petaCatatan[c.PendaftaranID] = c
	}
	petaImun := map[uuid.UUID][]models.ImunisasiAnak{}
	for _, i := range imun {
		if i.PendaftaranID != nil {
			petaImun[*i.PendaftaranID] = append(petaImun[*i.PendaftaranID], i)
		}
	}
	petaSup := map[uuid.UUID][]models.SuplemenAnak{}
	for _, x := range sup {
		if x.PendaftaranID != nil {
			petaSup[*x.PendaftaranID] = append(petaSup[*x.PendaftaranID], x)
		}
	}

	out := make([]RiwayatItem, 0, len(list))
	for _, p := range list {
		it := RiwayatItem{
			PendaftaranID: p.ID,
			AnakID:        p.AnakID,
			NamaAnak:      nama[p.AnakID],
			Imunisasi:     petaImun[p.ID],
			Suplemen:      petaSup[p.ID],
		}
		if it.Imunisasi == nil {
			it.Imunisasi = []models.ImunisasiAnak{}
		}
		if it.Suplemen == nil {
			it.Suplemen = []models.SuplemenAnak{}
		}
		if p.Jadwal != nil {
			it.Tanggal = p.Jadwal.Tanggal
			it.JamMulai = p.Jadwal.JamMulai
		}
		if u, ok := petaUkur[p.ID]; ok {
			it.Pengukuran = &PengukuranRiwayat{
				TanggalUkur: u.TanggalUkur, UsiaBulan: u.UsiaBulan, BbKg: u.BbKg, TbCm: u.TbCm,
				CaraUkur: u.CaraUkur, LingkarKepalaCm: u.LingkarKepalaCm, LilaCm: u.LilaCm,
			}
			if g, ok := petaGizi[u.ID]; ok {
				gg := g
				it.StatusGizi = &gg
			}
			if n, ok := nilai[u.ID]; ok {
				nn := n
				it.Penilaian = &nn
			}
		}
		if c, ok := petaCatatan[p.ID]; ok {
			cc := c
			it.Catatan = &cc
		}
		out = append(out, it)
	}
	sort.Slice(out, func(i, j int) bool {
		if !out[i].Tanggal.Equal(out[j].Tanggal) {
			return out[i].Tanggal.After(out[j].Tanggal)
		}
		return out[i].JamMulai > out[j].JamMulai
	})
	return out, nil
}