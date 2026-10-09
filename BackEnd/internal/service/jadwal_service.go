package service

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

var wib = func() *time.Location {
	if l, err := time.LoadLocation("Asia/Jakarta"); err == nil {
		return l
	}
	return time.FixedZone("WIB", 7*3600)
}()

var reJam = regexp.MustCompile(`^([01]\d|2[0-3]):[0-5]\d$`)

// check-in hanya dibuka 1 jam sebelum jadwal dimulai
const bukaCheckinMenit = 60

const prefixQRJadwal = "POSYANDU-CHECKIN:"

type JadwalService struct {
	repo *repository.JadwalRepository
	kel  *repository.KeluargaRepository
}

func NewJadwalService(r *repository.JadwalRepository, k *repository.KeluargaRepository) *JadwalService {
	return &JadwalService{repo: r, kel: k}
}

// ---------------------------------------------------------------- fungsi bantu waktu

// hariIni mengembalikan tanggal hari ini (WIB) sebagai tengah malam UTC agar mudah dibandingkan dengan kolom DATE.
func hariIni() time.Time {
	n := time.Now().In(wib)
	return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, time.UTC)
}

func gabung(tgl time.Time, jam string) time.Time {
	var h, m int
	fmt.Sscanf(jam, "%d:%d", &h, &m)
	y, mo, d := tgl.Date()
	return time.Date(y, mo, d, h, m, 0, 0, wib)
}

func mulaiJadwal(j *models.JadwalPosyandu) time.Time { return gabung(j.Tanggal, j.JamMulai) }

func selesaiJadwal(j *models.JadwalPosyandu) time.Time {
	if j.JamSelesai != nil && *j.JamSelesai != "" {
		return gabung(j.Tanggal, *j.JamSelesai)
	}
	return mulaiJadwal(j).Add(4 * time.Hour)
}

func checkinDibuka(j *models.JadwalPosyandu) time.Time {
	return mulaiJadwal(j).Add(-bukaCheckinMenit * time.Minute)
}

// KodeQRJadwal: isi QR yang dipasang di lokasi posyandu untuk dipindai orang tua.
func KodeQRJadwal(id uuid.UUID) string { return prefixQRJadwal + id.String() }

// ---------------------------------------------------------------- input dan keluaran

type JadwalInput struct {
	Tanggal    string `json:"tanggal" binding:"required"`   // YYYY-MM-DD
	JamMulai   string `json:"jam_mulai" binding:"required"` // HH:MM
	JamSelesai string `json:"jam_selesai"`                  // opsional
	Lokasi     string `json:"lokasi"`                       // opsional
}

// KartuAntrean: kartu yang tampil di orang tua setelah pendaftaran berhasil (aksi: batalkan / check-in).
type KartuAntrean struct {
	PendaftaranID     uuid.UUID  `json:"pendaftaran_id"`
	AnakID            uuid.UUID  `json:"anak_id"`
	NamaAnak          string     `json:"nama_anak"`
	JadwalID          uuid.UUID  `json:"jadwal_id"`
	Tanggal           time.Time  `json:"tanggal"`
	JamMulai          string     `json:"jam_mulai"`
	JamSelesai        *string    `json:"jam_selesai"`
	Lokasi            string     `json:"lokasi"`
	NomorAntrean      *int16     `json:"nomor_antrean"`
	StatusKehadiran   string     `json:"status_kehadiran"` // terdaftar | sudah_checkin | batal | tidak_hadir
	MulaiPada         time.Time  `json:"mulai_pada"`
	CheckinDibukaPada time.Time  `json:"checkin_dibuka_pada"`
	WaktuCheckin      *time.Time `json:"waktu_checkin"`
	BolehBatal        bool       `json:"boleh_batal"`
	BolehCheckin      bool       `json:"boleh_checkin"`
}

type AnakStatus struct {
	AnakID          uuid.UUID     `json:"anak_id"`
	Nama            string        `json:"nama"`
	StatusKehadiran string        `json:"status_kehadiran"` // belum_daftar | terdaftar | sudah_checkin | tidak_hadir
	NomorAntrean    *int16        `json:"nomor_antrean"`
	BolehDaftar     bool          `json:"boleh_daftar"`
	BolehBatal      bool          `json:"boleh_batal"`
	BolehCheckin    bool          `json:"boleh_checkin"`
	Kartu           *KartuAntrean `json:"kartu"`
}

type JadwalTerdekat struct {
	Jadwal                models.JadwalPosyandu `json:"jadwal"`
	MulaiPada             time.Time             `json:"mulai_pada"`
	PendaftaranDibukaPada time.Time             `json:"pendaftaran_dibuka_pada"`
	CheckinDibukaPada     time.Time             `json:"checkin_dibuka_pada"`
	Anak                  []AnakStatus          `json:"anak"`
}

func cekJadwal(in JadwalInput, baru bool) (time.Time, *string, error) {
	var kosong time.Time
	tgl, err := time.Parse("2006-01-02", strings.TrimSpace(in.Tanggal))
	if err != nil {
		return kosong, nil, validasi("tanggal harus berformat YYYY-MM-DD")
	}
	if baru && tgl.Before(hariIni()) {
		return kosong, nil, validasi("tanggal pelaksanaan tidak boleh sebelum hari ini")
	}
	if !reJam.MatchString(in.JamMulai) {
		return kosong, nil, validasi("jam mulai harus berformat HH:MM")
	}
	var selesai *string
	if s := strings.TrimSpace(in.JamSelesai); s != "" {
		if !reJam.MatchString(s) {
			return kosong, nil, validasi("jam selesai harus berformat HH:MM")
		}
		if s <= in.JamMulai {
			return kosong, nil, validasi("jam selesai harus setelah jam mulai")
		}
		selesai = &s
	}
	return tgl, selesai, nil
}

func buatKartu(j *models.JadwalPosyandu, a *models.Anak, p *models.Pendaftaran) *KartuAntrean {
	now := time.Now()
	mulai := mulaiJadwal(j)
	aktif := j.Status == "terjadwal"
	terdaftar := p.StatusKehadiran == "terdaftar"
	return &KartuAntrean{
		PendaftaranID:     p.ID,
		AnakID:            p.AnakID,
		NamaAnak:          a.Nama,
		JadwalID:          j.ID,
		Tanggal:           j.Tanggal,
		JamMulai:          j.JamMulai,
		JamSelesai:        j.JamSelesai,
		Lokasi:            j.Lokasi,
		NomorAntrean:      p.NomorAntrean,
		StatusKehadiran:   p.StatusKehadiran,
		MulaiPada:         mulai,
		CheckinDibukaPada: checkinDibuka(j),
		WaktuCheckin:      p.WaktuCheckin,
		BolehBatal:        aktif && terdaftar && now.Before(mulai),
		BolehCheckin:      aktif && terdaftar && !now.Before(checkinDibuka(j)) && now.Before(selesaiJadwal(j)),
	}
}

// ---------------------------------------------------------------- admin

func (s *JadwalService) Buat(adminID uint, in JadwalInput) (*models.JadwalPosyandu, error) {
	tgl, selesai, err := cekJadwal(in, true)
	if err != nil {
		return nil, err
	}
	if s.repo.JadwalPadaTanggal(tgl, uuid.Nil) {
		return nil, konflik("sudah ada jadwal pada tanggal tersebut")
	}
	j := &models.JadwalPosyandu{
		Tanggal:          tgl,
		JamMulai:         in.JamMulai,
		JamSelesai:       selesai,
		Lokasi:           strings.TrimSpace(in.Lokasi),
		BukaDaftarHari:   7,
		BukaCheckinMenit: bukaCheckinMenit,
		Status:           "terjadwal",
		DibuatOleh:       adminID,
		Version:          1,
	}
	if err := s.repo.CreateJadwal(j); err != nil {
		return nil, err
	}
	return j, nil
}

func (s *JadwalService) Ubah(id uuid.UUID, in JadwalInput) (*models.JadwalPosyandu, error) {
	j, err := s.repo.GetJadwal(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrJadwalTidakAda
	}
	if err != nil {
		return nil, err
	}
	if j.Status != "terjadwal" {
		return nil, konflik("jadwal berstatus %s tidak dapat diubah", j.Status)
	}
	tgl, selesai, err := cekJadwal(in, false)
	if err != nil {
		return nil, err
	}
	if s.repo.JadwalPadaTanggal(tgl, j.ID) {
		return nil, konflik("sudah ada jadwal pada tanggal tersebut")
	}
	j.Tanggal = tgl
	j.JamMulai = in.JamMulai
	j.JamSelesai = selesai
	j.Lokasi = strings.TrimSpace(in.Lokasi)
	j.BukaCheckinMenit = bukaCheckinMenit
	j.Version++
	if err := s.repo.SaveJadwal(j); err != nil {
		return nil, err
	}
	return j, nil
}

func (s *JadwalService) Batalkan(id uuid.UUID, alasan string) (*models.JadwalPosyandu, error) {
	alasan = strings.TrimSpace(alasan)
	if alasan == "" {
		return nil, validasi("alasan pembatalan wajib diisi")
	}
	j, err := s.repo.GetJadwal(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrJadwalTidakAda
	}
	if err != nil {
		return nil, err
	}
	if j.Status == "dibatalkan" {
		return nil, konflik("jadwal sudah dibatalkan")
	}
	j.Status = "dibatalkan"
	j.AlasanBatal = alasan
	j.Version++
	if err := s.repo.SaveJadwal(j); err != nil {
		return nil, err
	}
	return j, nil
}

func (s *JadwalService) List() ([]models.JadwalPosyandu, error) { return s.repo.ListJadwal() }

// QRJadwal: isi QR check-in untuk satu jadwal (ditampilkan admin/kader di lokasi).
func (s *JadwalService) QRJadwal(id uuid.UUID) (string, error) {
	j, err := s.jadwalAktif(id)
	if err != nil {
		return "", err
	}
	return KodeQRJadwal(j.ID), nil
}

// ---------------------------------------------------------------- jadwal terdekat (semua role)

func (s *JadwalService) Terdekat(userID uint, role string) (*JadwalTerdekat, error) {
	j, err := s.repo.JadwalTerdekat(hariIni().Format("2006-01-02"))
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	mulai := mulaiJadwal(j)
	out := &JadwalTerdekat{
		Jadwal:                *j,
		MulaiPada:             mulai,
		PendaftaranDibukaPada: j.CreatedAt, // pendaftaran terbuka sejak jadwal diterbitkan admin
		CheckinDibukaPada:     checkinDibuka(j),
		Anak:                  []AnakStatus{},
	}
	if role != string(models.RoleOrangTua) {
		return out, nil
	}

	ibu, err := s.kel.FindIbuByUser(userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return out, nil
	}
	if err != nil {
		return nil, err
	}
	anak, err := s.repo.AnakKeluarga(ibu.KeluargaID)
	if err != nil {
		return nil, err
	}
	ids := make([]uuid.UUID, 0, len(anak))
	for _, a := range anak {
		ids = append(ids, a.ID)
	}
	daftar, err := s.repo.ListPendaftaranAnak(ids, j.ID)
	if err != nil {
		return nil, err
	}
	peta := map[uuid.UUID]models.Pendaftaran{}
	for _, p := range daftar {
		peta[p.AnakID] = p
	}

	now := time.Now()
	bukaDaftar := now.Before(selesaiJadwal(j))
	for i := range anak {
		a := anak[i]
		st := AnakStatus{AnakID: a.ID, Nama: a.Nama, StatusKehadiran: "belum_daftar"}
		if p, ok := peta[a.ID]; ok && p.StatusKehadiran != "batal" {
			pp := p
			k := buatKartu(j, &a, &pp)
			st.StatusKehadiran = p.StatusKehadiran
			st.NomorAntrean = p.NomorAntrean
			st.BolehBatal = k.BolehBatal
			st.BolehCheckin = k.BolehCheckin
			st.Kartu = k
		}
		st.BolehDaftar = bukaDaftar && st.StatusKehadiran == "belum_daftar"
		out.Anak = append(out.Anak, st)
	}
	return out, nil
}

// ---------------------------------------------------------------- orang tua: daftar, batal, scan check-in

func (s *JadwalService) cekAnakMilik(userID uint, anakID uuid.UUID) (*models.Anak, error) {
	ibu, err := s.kel.FindIbuByUser(userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, terlarang("data keluarga belum dilengkapi")
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
	if a.KeluargaID != ibu.KeluargaID {
		return nil, terlarang("anak bukan bagian dari keluarga Anda")
	}
	return a, nil
}

func (s *JadwalService) jadwalAktif(id uuid.UUID) (*models.JadwalPosyandu, error) {
	j, err := s.repo.GetJadwal(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrJadwalTidakAda
	}
	if err != nil {
		return nil, err
	}
	if j.Status != "terjadwal" {
		return nil, konflik("jadwal berstatus %s", j.Status)
	}
	return j, nil
}

// Daftar: orang tua dapat mendaftar kapan saja selama jadwal yang diterbitkan admin belum selesai.
func (s *JadwalService) Daftar(userID uint, jadwalID, anakID uuid.UUID) (*KartuAntrean, error) {
	a, err := s.cekAnakMilik(userID, anakID)
	if err != nil {
		return nil, err
	}
	j, err := s.jadwalAktif(jadwalID)
	if err != nil {
		return nil, err
	}
	now := time.Now()
	if !now.Before(selesaiJadwal(j)) {
		return nil, konflik("jadwal sudah selesai, pendaftaran ditutup")
	}

	var hasil *models.Pendaftaran
	err = s.repo.Tx(func(r *repository.JadwalRepository) error {
		p, err := r.FindPendaftaran(j.ID, a.ID)
		if err == nil {
			if p.StatusKehadiran != "batal" {
				return konflik("anak sudah terdaftar pada jadwal ini")
			}
			p.StatusKehadiran = "terdaftar"
			p.Sumber = "mandiri"
			p.WaktuBatal = nil
			p.WaktuCheckin = nil
			p.MetodeCheckin = ""
			p.Version++
			hasil = p
			return r.SavePendaftaran(p)
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		n := r.NomorAntreanBerikut(j.ID)
		p = &models.Pendaftaran{
			JadwalID:        j.ID,
			AnakID:          a.ID,
			StatusKehadiran: "terdaftar",
			Sumber:          "mandiri",
			NomorAntrean:    &n,
			WaktuDaftar:     now,
			Version:         1,
		}
		hasil = p
		return r.CreatePendaftaran(p)
	})
	if err != nil {
		return nil, err
	}
	return buatKartu(j, a, hasil), nil
}

func (s *JadwalService) BatalDaftar(userID uint, jadwalID, anakID uuid.UUID) (*KartuAntrean, error) {
	a, err := s.cekAnakMilik(userID, anakID)
	if err != nil {
		return nil, err
	}
	j, err := s.jadwalAktif(jadwalID)
	if err != nil {
		return nil, err
	}
	p, err := s.repo.FindPendaftaran(j.ID, a.ID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrPendaftaranTidakAda
	}
	if err != nil {
		return nil, err
	}
	if p.StatusKehadiran != "terdaftar" {
		return nil, konflik("pendaftaran berstatus %s tidak dapat dibatalkan", p.StatusKehadiran)
	}
	now := time.Now()
	if !now.Before(mulaiJadwal(j)) {
		return nil, konflik("jadwal sudah dimulai, pendaftaran tidak dapat dibatalkan")
	}
	p.StatusKehadiran = "batal"
	p.WaktuBatal = &now
	p.Version++
	if err := s.repo.SavePendaftaran(p); err != nil {
		return nil, err
	}
	return buatKartu(j, a, p), nil
}

// ScanCheckin: orang tua memindai QR jadwal di lokasi, lalu anak otomatis check-in
// dan masuk ke antrean pendataan kader. Check-in hanya dibuka 1 jam sebelum jadwal dimulai.
func (s *JadwalService) ScanCheckin(userID uint, jadwalID, anakID uuid.UUID, kode string) (*KartuAntrean, error) {
	kode = strings.TrimSpace(kode)
	if kode == "" {
		return nil, validasi("kode QR kosong")
	}
	a, err := s.cekAnakMilik(userID, anakID)
	if err != nil {
		return nil, err
	}
	j, err := s.jadwalAktif(jadwalID)
	if err != nil {
		return nil, err
	}
	if !strings.EqualFold(kode, KodeQRJadwal(j.ID)) {
		return nil, validasi("kode QR tidak sesuai dengan jadwal ini")
	}
	p, err := s.repo.FindPendaftaran(j.ID, a.ID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, konflik("anak belum terdaftar pada jadwal ini")
	}
	if err != nil {
		return nil, err
	}
	if p.StatusKehadiran == "sudah_checkin" {
		return nil, konflik("anak sudah check-in")
	}
	if p.StatusKehadiran != "terdaftar" {
		return nil, konflik("anak berstatus %s, check-in tidak dapat dilakukan", p.StatusKehadiran)
	}
	now := time.Now()
	buka := checkinDibuka(j)
	if now.Before(buka) {
		return nil, konflik("check-in dibuka pukul %s WIB (1 jam sebelum jadwal dimulai)", buka.In(wib).Format("15:04"))
	}
	if !now.Before(selesaiJadwal(j)) {
		return nil, konflik("jadwal sudah selesai")
	}
	p.StatusKehadiran = "sudah_checkin"
	p.WaktuCheckin = &now
	p.MetodeCheckin = "mandiri"
	p.Version++
	if err := s.repo.SavePendaftaran(p); err != nil {
		return nil, err
	}
	return buatKartu(j, a, p), nil
}

// KartuAntrean: kartu antrean satu anak pada satu jadwal.
func (s *JadwalService) KartuAntrean(userID uint, jadwalID, anakID uuid.UUID) (*KartuAntrean, error) {
	a, err := s.cekAnakMilik(userID, anakID)
	if err != nil {
		return nil, err
	}
	j, err := s.repo.GetJadwal(jadwalID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrJadwalTidakAda
	}
	if err != nil {
		return nil, err
	}
	p, err := s.repo.FindPendaftaran(j.ID, a.ID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrPendaftaranTidakAda
	}
	if err != nil {
		return nil, err
	}
	return buatKartu(j, a, p), nil
}

// ---------------------------------------------------------------- kader: cari anak, walk-in, check-in manual (cadangan)

func (s *JadwalService) CariAnak(kata string) ([]models.Anak, error) {
	kata = strings.TrimSpace(kata)
	if len(kata) < 2 {
		return nil, validasi("kata kunci minimal 2 karakter")
	}
	return s.repo.CariAnak(kata)
}

func (s *JadwalService) WalkIn(kaderID uint, jadwalID, anakID uuid.UUID) (*models.Pendaftaran, error) {
	j, err := s.jadwalAktif(jadwalID)
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
	now := time.Now()
	if !now.Before(selesaiJadwal(j)) {
		return nil, konflik("jadwal sudah selesai")
	}

	var hasil *models.Pendaftaran
	err = s.repo.Tx(func(r *repository.JadwalRepository) error {
		p, err := r.FindPendaftaran(j.ID, a.ID)
		switch {
		case err == nil:
			if p.StatusKehadiran == "sudah_checkin" {
				return konflik("anak sudah check-in")
			}
			p.Version++
		case errors.Is(err, gorm.ErrRecordNotFound):
			n := r.NomorAntreanBerikut(j.ID)
			p = &models.Pendaftaran{
				JadwalID:     j.ID,
				AnakID:       a.ID,
				Sumber:       "walk_in",
				NomorAntrean: &n,
				WaktuDaftar:  now,
				Version:      1,
			}
		default:
			return err
		}
		p.StatusKehadiran = "sudah_checkin"
		p.WaktuCheckin = &now
		p.MetodeCheckin = "manual"
		p.DiverifikasiOleh = &kaderID
		p.WaktuBatal = nil
		hasil = p
		if p.CreatedAt.IsZero() {
			return r.CreatePendaftaran(p)
		}
		return r.SavePendaftaran(p)
	})
	if err != nil {
		return nil, err
	}
	return hasil, nil
}

func (s *JadwalService) CheckinManual(kaderID uint, pendaftaranID uuid.UUID) (*models.Pendaftaran, error) {
	p, err := s.repo.GetPendaftaran(pendaftaranID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrPendaftaranTidakAda
	}
	if err != nil {
		return nil, err
	}
	if p.Jadwal == nil || p.Jadwal.Status != "terjadwal" {
		return nil, konflik("jadwal tidak aktif")
	}
	if p.StatusKehadiran != "terdaftar" {
		return nil, konflik("anak berstatus %s, check-in tidak dapat dilakukan", p.StatusKehadiran)
	}
	now := time.Now()
	p.StatusKehadiran = "sudah_checkin"
	p.WaktuCheckin = &now
	p.MetodeCheckin = "manual"
	p.DiverifikasiOleh = &kaderID
	p.Version++
	if err := s.repo.SavePendaftaran(p); err != nil {
		return nil, err
	}
	return p, nil
}