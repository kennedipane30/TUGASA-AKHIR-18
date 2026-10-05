package service

import (
	"errors"
	"fmt"
	"sort"
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
}

func NewPelayananService(j *repository.JadwalRepository, p *repository.PelayananRepository, k *repository.KeluargaRepository) *PelayananService {
	return &PelayananService{jadwal: j, repo: p, kel: k}
}

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
	KondisiAnak   string `json:"kondisi_anak"`
	Catatan       string `json:"catatan"`
}

type SuplemenInput struct {
	Jenis           string `json:"jenis" binding:"required,oneof=vitamin_a obat_cacing pmt"`
	KeteranganDosis string `json:"keterangan_dosis"`
	Catatan         string `json:"catatan"`
}

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
	PendaftaranID     uuid.UUID `json:"pendaftaran_id"`
	AnakID            uuid.UUID `json:"anak_id"`
	Nama              string    `json:"nama"`
	JenisKelamin      string    `json:"jenis_kelamin"`
	UsiaBulan         int       `json:"usia_bulan"`
	NomorAntrean      *int16    `json:"nomor_antrean"`
	StatusKehadiran   string    `json:"status_kehadiran"`
	Sumber            string    `json:"sumber"`
	SudahDiukur       bool      `json:"sudah_diukur"`
	SudahDicatatBidan bool      `json:"sudah_dicatat_bidan"`
}

type BidanItem struct {
	PendaftaranID      uuid.UUID `json:"pendaftaran_id"`
	AnakID             uuid.UUID `json:"anak_id"`
	Nama               string    `json:"nama"`
	JenisKelamin       string    `json:"jenis_kelamin"`
	UsiaBulan          int       `json:"usia_bulan"`
	NomorAntrean       *int16    `json:"nomor_antrean"`
	BbKg               float64   `json:"bb_kg"`
	TbCm               float64   `json:"tb_cm"`
	PeringatanValidasi string    `json:"peringatan_validasi"`
	StatusCatatan      string    `json:"status_catatan"` // perlu_catatan | selesai
}

type DetailBidan struct {
	Anak             models.Anak              `json:"anak"`
	Jadwal           models.JadwalPosyandu    `json:"jadwal"`
	UsiaBulan        int                      `json:"usia_bulan"`
	Pengukuran       *models.Pengukuran       `json:"pengukuran"`
	Sebelumnya       *models.Pengukuran       `json:"pengukuran_sebelumnya"`
	Catatan          *models.PemeriksaanBidan `json:"catatan"`
	Imunisasi        []models.ImunisasiAnak   `json:"imunisasi"`
	Suplemen         []models.SuplemenAnak    `json:"suplemen"`
	RiwayatImunisasi []models.ImunisasiAnak   `json:"riwayat_imunisasi"`
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

func idPendaftaran(list []models.Pendaftaran) []uuid.UUID {
	ids := make([]uuid.UUID, 0, len(list))
	for _, p := range list {
		ids = append(ids, p.ID)
	}
	return ids
}

// ---------------------------------------------------------------- kader

// AntreanKader: anak yang terdaftar atau sudah check-in pada satu jadwal.
func (s *PelayananService) AntreanKader(jadwalID uuid.UUID) ([]AntreanItem, error) {
	list, err := s.jadwal.ListPendaftaranJadwal(jadwalID, "terdaftar", "sudah_checkin")
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
	adaUkur := map[uuid.UUID]bool{}
	for _, u := range ukur {
		adaUkur[u.PendaftaranID] = true
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
		if p.Anak != nil {
			it.Nama = p.Anak.Nama
			it.JenisKelamin = p.Anak.JenisKelamin
			it.UsiaBulan = usiaBulan(p.Anak.TanggalLahir, now)
		}
		out = append(out, it)
	}
	return out, nil
}

func (s *PelayananService) CatatPengukuran(kaderID uint, pendaftaranID uuid.UUID, in PengukuranInput) (*models.Pengukuran, error) {
	p, err := s.pendaftaran(pendaftaranID)
	if err != nil {
		return nil, err
	}
	if p.StatusKehadiran != "sudah_checkin" {
		return nil, konflik("anak belum check-in, pengukuran belum dapat dicatat")
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
	return m, nil
}

// ---------------------------------------------------------------- bidan

// AntreanBidan: kunjungan yang sudah diinput kader pada satu jadwal.
func (s *PelayananService) AntreanBidan(jadwalID uuid.UUID) ([]BidanItem, error) {
	list, err := s.repo.PendaftaranBerpengukuran(jadwalID)
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

	now := time.Now()
	out := make([]BidanItem, 0, len(list))
	for _, p := range list {
		u := petaUkur[p.ID]
		it := BidanItem{
			PendaftaranID:      p.ID,
			AnakID:             p.AnakID,
			NomorAntrean:       p.NomorAntrean,
			BbKg:               u.BbKg,
			TbCm:               u.TbCm,
			PeringatanValidasi: u.PeringatanValidasi,
			StatusCatatan:      "perlu_catatan",
		}
		if adaCatatan[p.ID] {
			it.StatusCatatan = "selesai"
		}
		if p.Anak != nil {
			it.Nama = p.Anak.Nama
			it.JenisKelamin = p.Anak.JenisKelamin
			it.UsiaBulan = usiaBulan(p.Anak.TanggalLahir, now)
		}
		out = append(out, it)
	}
	return out, nil
}

func (s *PelayananService) DetailBidan(pendaftaranID uuid.UUID) (*DetailBidan, error) {
	p, err := s.pendaftaran(pendaftaranID)
	if err != nil {
		return nil, err
	}
	if p.Anak == nil || p.Jadwal == nil {
		return nil, ErrPendaftaranTidakAda
	}
	ukur, err := s.repo.GetPengukuran(p.ID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, konflik("kader belum menginput pengukuran")
	}
	if err != nil {
		return nil, err
	}

	d := &DetailBidan{
		Anak:       *p.Anak,
		Jadwal:     *p.Jadwal,
		UsiaBulan:  usiaBulan(p.Anak.TanggalLahir, time.Now()),
		Pengukuran: ukur,
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
	return d, nil
}

func (s *PelayananService) ListVaksin() ([]models.JenisVaksin, error) { return s.repo.ListVaksin() }

func (s *PelayananService) SimpanCatatan(bidanID uint, pendaftaranID uuid.UUID, in CatatanBidanInput) (*DetailBidan, error) {
	p, err := s.pendaftaran(pendaftaranID)
	if err != nil {
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

	// validasi vaksin
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
	for _, v := range in.Vaksin {
		id, err := uuid.Parse(strings.TrimSpace(v.JenisVaksinID))
		if err != nil {
			return nil, validasi("jenis_vaksin_id tidak valid")
		}
		jv, ok := petaVaksin[id]
		if !ok {
			return nil, validasi("jenis vaksin tidak ditemukan")
		}
		if v.DosisKe < 1 || v.DosisKe > jv.JumlahDosis {
			return nil, validasi("dosis ke-%d tidak sesuai untuk %s (1-%d)", v.DosisKe, jv.Nama, jv.JumlahDosis)
		}
		if s.repo.ImunisasiSudahAda(p.AnakID, id, v.DosisKe, p.ID) {
			return nil, konflik("%s dosis ke-%d sudah pernah dicatat untuk anak ini", jv.Nama, v.DosisKe)
		}
		vaksin = append(vaksin, models.ImunisasiAnak{
			AnakID:           p.AnakID,
			JenisVaksinID:    id,
			DosisKe:          v.DosisKe,
			TanggalPemberian: tanggal,
			KondisiAnak:      strings.TrimSpace(v.KondisiAnak),
			PendaftaranID:    &pid,
			DiberikanOleh:    bidanID,
			Catatan:          strings.TrimSpace(v.Catatan),
			Version:          1,
		})
	}
	suplemen := make([]models.SuplemenAnak, 0, len(in.Suplemen))
	for _, x := range in.Suplemen {
		suplemen = append(suplemen, models.SuplemenAnak{
			AnakID:          p.AnakID,
			Jenis:           x.Jenis,
			Tanggal:         tanggal,
			KeteranganDosis: strings.TrimSpace(x.KeteranganDosis),
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
	return s.DetailBidan(p.ID)
}

// ---------------------------------------------------------------- orang tua: riwayat

// Riwayat menampilkan kunjungan yang SUDAH diberi catatan bidan.
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
