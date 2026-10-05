package service

import (
	"errors"
	"regexp"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
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
	TanpaIbu     bool       `json:"tanpa_ibu"`
	TglLahirIbu  string     `json:"tgl_lahir_ibu"`
	PekerjaanIbu string     `json:"pekerjaan_ibu"`
	Alamat       string     `json:"alamat"`
	RT           string     `json:"rt"`
	RW           string     `json:"rw"`
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

type StatusKeluarga struct {
	ProfilLengkap bool `json:"profil_lengkap"`
	JumlahAnak    int  `json:"jumlah_anak"`
}

type KeluargaResponse struct {
	Keluarga *models.Keluarga `json:"keluarga"`
	Ibu      *models.OrangTua `json:"ibu"`
	Ayah     *models.OrangTua `json:"ayah"`
	Anak     []models.Anak    `json:"anak"`
	Status   StatusKeluarga   `json:"status"`
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

func strPtr(s string) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	return &s
}

type KeluargaService struct{ repo *repository.KeluargaRepository }

func NewKeluargaService(r *repository.KeluargaRepository) *KeluargaService {
	return &KeluargaService{r}
}

func (s *KeluargaService) Get(uid uint) (*KeluargaResponse, error) {
	d, err := s.repo.GetByUser(uid)
	if err != nil {
		return nil, err
	}
	st := StatusKeluarga{JumlahAnak: len(d.Anak)}
	if d.Keluarga != nil {
		st.ProfilLengkap = d.Keluarga.Alamat != "" && d.Keluarga.RT != "" && d.Keluarga.RW != ""
	}
	return &KeluargaResponse{
		Keluarga: d.Keluarga,
		Ibu:      d.Ibu,
		Ayah:     d.Ayah,
		Anak:     d.Anak,
		Status:   st,
	}, nil
}

func (s *KeluargaService) SimpanProfil(uid uint, in ProfilInput) (*KeluargaResponse, error) {
	tglIbu, err := parseTgl(in.TglLahirIbu)
	if err != nil {
		return nil, err
	}
	if len(in.RT) > 3 || len(in.RW) > 3 || !reAngka.MatchString(in.RT) || !reAngka.MatchString(in.RW) {
		return nil, invalid("RT/RW harus angka maksimal 3 digit")
	}

	var ayah *models.OrangTua
	if !in.TanpaAyah && in.Ayah != nil && strings.TrimSpace(in.Ayah.Nama) != "" {
		if err := cekNIK(in.Ayah.NIK); err != nil {
			return nil, err
		}
		tglAyah, err := parseTgl(in.Ayah.TglLahir)
		if err != nil {
			return nil, err
		}
		ayah = &models.OrangTua{
			PeranKeluarga: "ayah",
			Nama:          strings.TrimSpace(in.Ayah.Nama),
			NIK:           strPtr(in.Ayah.NIK),
			TanggalLahir:  tglAyah,
			NoHP:          strings.TrimSpace(in.Ayah.NoHP),
			Pekerjaan:     strings.TrimSpace(in.Ayah.Pekerjaan),
		}
	}

	err = s.repo.SimpanProfil(uid, repository.ProfilData{
		Alamat:       strings.TrimSpace(in.Alamat),
		RT:           in.RT,
		RW:           in.RW,
		TanpaAyah:    in.TanpaAyah,
		TglLahirIbu:  tglIbu,
		PekerjaanIbu: strings.TrimSpace(in.PekerjaanIbu),
		Ayah:         ayah,
	})
	if err != nil {
		return nil, err
	}
	return s.Get(uid)
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
		Nama:           nama,
		NIK:            strPtr(in.NIK),
		TanggalLahir:   *tgl,
		JenisKelamin:   in.JK,
		BeratLahirKg:   in.BeratLahir,
		PanjangLahirCm: in.PanjangLahir,
	}, nil
}

func (s *KeluargaService) cekDuplikatAnak(keluargaID uuid.UUID, a *models.Anak, kecuali uuid.UUID) error {
	if a.NIK != nil && s.repo.NIKAnakSudahAda(*a.NIK, kecuali) {
		return konflik("NIK anak sudah terdaftar")
	}
	if s.repo.AnakSudahAda(keluargaID, a.Nama, a.TanggalLahir, kecuali) {
		return konflik("data anak dengan nama dan tanggal lahir yang sama sudah ada")
	}
	return nil
}

func (s *KeluargaService) TambahAnak(uid uint, in AnakInput) (*models.Anak, error) {
	a, err := buatAnak(in)
	if err != nil {
		return nil, err
	}
	kid, err := s.repo.PastikanKeluarga(uid)
	if err != nil {
		return nil, err
	}
	if err := s.cekDuplikatAnak(kid, a, uuid.Nil); err != nil {
		return nil, err
	}
	a.KeluargaID = kid
	if err := s.repo.TambahAnak(a); err != nil {
		return nil, err
	}
	return a, nil
}

func (s *KeluargaService) UbahAnak(uid uint, id uuid.UUID, in AnakInput) (*models.Anak, error) {
	a, err := buatAnak(in)
	if err != nil {
		return nil, err
	}
	d, err := s.repo.GetByUser(uid)
	if err != nil {
		return nil, err
	}
	if d.Keluarga == nil {
		return nil, errors.New("data keluarga belum ada")
	}
	if err := s.cekDuplikatAnak(d.Keluarga.ID, a, id); err != nil {
		return nil, err
	}
	a.ID = id
	a.KeluargaID = d.Keluarga.ID
	if err := s.repo.UbahAnak(a); err != nil {
		return nil, err
	}
	return a, nil
}

func (s *KeluargaService) HapusAnak(uid uint, id uuid.UUID) error {
	d, err := s.repo.GetByUser(uid)
	if err != nil {
		return err
	}
	if d.Keluarga == nil {
		return errors.New("data keluarga belum ada")
	}
	return s.repo.HapusAnak(id, d.Keluarga.ID)
}