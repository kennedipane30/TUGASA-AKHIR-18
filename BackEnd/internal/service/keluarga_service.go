package service

import (
	"errors"
	"regexp"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"
)

type ValidationError struct{ Msg string }

func (e *ValidationError) Error() string { return e.Msg }

func invalid(msg string) error { return &ValidationError{Msg: msg} }

type AyahInput struct {
	Nama      string `json:"nama"`
	NIK       string `json:"nik"`
	TglLahir  string `json:"tgl_lahir"`
	NoHP      string `json:"no_hp"`
	Pekerjaan string `json:"pekerjaan"`
}

type ProfilInput struct {
	TglLahirIbu  string     `json:"tgl_lahir_ibu"`
	PekerjaanIbu string     `json:"pekerjaan_ibu"`
	Alamat       string     `json:"alamat"`
	RT           string     `json:"rt"`
	RW           string     `json:"rw"`
	PosyanduID   *uint      `json:"posyandu_id"`
	TanpaAyah    bool       `json:"tanpa_ayah"`
	Ayah         *AyahInput `json:"ayah"`
}

type AnakInput struct {
	Nama         string   `json:"nama"`
	NIK          string   `json:"nik"`
	TglLahir     string   `json:"tgl_lahir"`
	JK           string   `json:"jk"`
	BeratLahir   *float64 `json:"berat_lahir"`
	PanjangLahir *float64 `json:"panjang_lahir"`
}

type KeluargaResponse struct {
	Keluarga *models.Keluarga      `json:"keluarga"`
	Status   models.StatusKeluarga `json:"status"`
}

var reAngka = regexp.MustCompile(`^[0-9]*$`)

func parseTgl(s string) (*time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return nil, invalid("format tanggal harus yyyy-mm-dd")
	}
	return &t, nil
}

func cekNIK(nik string) error {
	if nik != "" && (len(nik) != 16 || !reAngka.MatchString(nik)) {
		return invalid("NIK harus 16 digit angka")
	}
	return nil
}

type KeluargaService struct{ repo *repository.KeluargaRepository }

func NewKeluargaService(r *repository.KeluargaRepository) *KeluargaService {
	return &KeluargaService{r}
}

func (s *KeluargaService) ListPosyandu() ([]models.Posyandu, error) {
	return s.repo.ListPosyandu()
}

func (s *KeluargaService) Get(uid uint) (*KeluargaResponse, error) {
	k, err := s.repo.GetByUser(uid)
	if err != nil {
		return nil, err
	}
	return &KeluargaResponse{Keluarga: k, Status: k.Status()}, nil
}

func (s *KeluargaService) SimpanProfil(uid uint, in ProfilInput) (*KeluargaResponse, error) {
	tglIbu, err := parseTgl(in.TglLahirIbu)
	if err != nil {
		return nil, err
	}
	if len(in.RT) > 3 || len(in.RW) > 3 || !reAngka.MatchString(in.RT) || !reAngka.MatchString(in.RW) {
		return nil, invalid("RT/RW harus angka maksimal 3 digit")
	}

	k, err := s.repo.GetByUser(uid)
	if err != nil {
		return nil, err
	}
	k.TglLahirIbu = tglIbu
	k.PekerjaanIbu = strings.TrimSpace(in.PekerjaanIbu)
	k.Alamat = strings.TrimSpace(in.Alamat)
	k.RT = in.RT
	k.RW = in.RW
	k.PosyanduID = in.PosyanduID
	k.TanpaAyah = in.TanpaAyah
	k.Posyandu, k.Ayah, k.Anak = nil, nil, nil

	var ayah *models.Ayah
	if !in.TanpaAyah && in.Ayah != nil && strings.TrimSpace(in.Ayah.Nama) != "" {
		if err := cekNIK(in.Ayah.NIK); err != nil {
			return nil, err
		}
		tglAyah, err := parseTgl(in.Ayah.TglLahir)
		if err != nil {
			return nil, err
		}
		ayah = &models.Ayah{
			Nama:      strings.TrimSpace(in.Ayah.Nama),
			NIK:       in.Ayah.NIK,
			TglLahir:  tglAyah,
			NoHP:      in.Ayah.NoHP,
			Pekerjaan: strings.TrimSpace(in.Ayah.Pekerjaan),
		}
	}

	if err := s.repo.SimpanProfil(k, ayah); err != nil {
		return nil, err
	}
	return s.Get(uid)
}

// pastikan baris keluarga sudah ada sebelum menambah anak
func (s *KeluargaService) pastikanKeluarga(uid uint) (*models.Keluarga, error) {
	k, err := s.repo.GetByUser(uid)
	if err != nil {
		return nil, err
	}
	if k.ID == 0 {
		k.Anak, k.Ayah, k.Posyandu = nil, nil, nil
		if err := s.repo.SimpanProfil(k, nil); err != nil {
			return nil, err
		}
	}
	return k, nil
}

func buatAnak(in AnakInput) (*models.Anak, error) {
	nama := strings.TrimSpace(in.Nama)
	if nama == "" {
		return nil, invalid("nama anak wajib diisi")
	}
	tgl, err := parseTgl(in.TglLahir)
	if err != nil {
		return nil, err
	}
	if tgl == nil {
		return nil, invalid("tanggal lahir wajib diisi")
	}
	if tgl.After(time.Now()) {
		return nil, invalid("tanggal lahir tidak boleh di masa depan")
	}
	if in.JK != "L" && in.JK != "P" {
		return nil, invalid("jenis kelamin harus L atau P")
	}
	if err := cekNIK(in.NIK); err != nil {
		return nil, err
	}
	if in.BeratLahir != nil && (*in.BeratLahir < 0.5 || *in.BeratLahir > 7) {
		return nil, invalid("berat lahir tidak wajar (0.5-7 kg)")
	}
	if in.PanjangLahir != nil && (*in.PanjangLahir < 30 || *in.PanjangLahir > 65) {
		return nil, invalid("panjang lahir tidak wajar (30-65 cm)")
	}
	return &models.Anak{
		Nama:         nama,
		NIK:          in.NIK,
		TglLahir:     *tgl,
		JK:           in.JK,
		BeratLahir:   in.BeratLahir,
		PanjangLahir: in.PanjangLahir,
	}, nil
}

func (s *KeluargaService) TambahAnak(uid uint, in AnakInput) (*models.Anak, error) {
	a, err := buatAnak(in)
	if err != nil {
		return nil, err
	}
	k, err := s.pastikanKeluarga(uid)
	if err != nil {
		return nil, err
	}
	a.KeluargaID = k.ID
	if err := s.repo.TambahAnak(a); err != nil {
		return nil, err
	}
	return a, nil
}

func (s *KeluargaService) UbahAnak(uid, id uint, in AnakInput) (*models.Anak, error) {
	a, err := buatAnak(in)
	if err != nil {
		return nil, err
	}
	k, err := s.repo.GetByUser(uid)
	if err != nil {
		return nil, err
	}
	if k.ID == 0 {
		return nil, errors.New("data keluarga belum ada")
	}
	a.ID = id
	a.KeluargaID = k.ID
	if err := s.repo.UbahAnak(a); err != nil {
		return nil, err
	}
	return a, nil
}

func (s *KeluargaService) HapusAnak(uid, id uint) error {
	k, err := s.repo.GetByUser(uid)
	if err != nil {
		return err
	}
	if k.ID == 0 {
		return errors.New("data keluarga belum ada")
	}
	return s.repo.HapusAnak(id, k.ID)
}