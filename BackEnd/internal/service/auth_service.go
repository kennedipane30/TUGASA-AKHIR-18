package service

import (
	"errors"
	"strings"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"
	"posyandu-api/internal/utils"
)

var (
	ErrInactive    = errors.New("akun tidak aktif, hubungi sekretaris")
	ErrDuplicate   = errors.New("NIK, No. HP, atau username sudah terdaftar")
	ErrInvalidRole = errors.New("role hanya boleh kader atau bidan")
	ErrPosyandu    = errors.New("posyandu tidak valid: pilih sitoluama, silimbat, atau aekbolon")
)

// AuthService: registrasi orang tua, profil, dan pembuatan akun petugas.
// Proses masuk (login), ubah PIN, dan reset PIN ada di PinService.
type AuthService struct{ repo *repository.UserRepository }

func NewAuthService(r *repository.UserRepository) *AuthService { return &AuthService{r} }

// PilihanPosyandu: daftar titik untuk halaman registrasi.
type PilihanPosyandu struct {
	ID   string `json:"id"`
	Nama string `json:"nama"`
}

func (s *AuthService) ListPosyandu() []PilihanPosyandu {
	return []PilihanPosyandu{
		{ID: "sitoluama", Nama: "Sitoluama"},
		{ID: "silimbat", Nama: "Silimbat"},
		{ID: "aekbolon", Nama: "Aek Bolon"},
	}
}

type RegisterInput struct {
	Nama       string `json:"nama" binding:"required"`
	NIK        string `json:"nik" binding:"required,len=16,numeric"`
	NoHP       string `json:"no_hp" binding:"required,min=10,max=15"`
	Pin        string `json:"pin" binding:"required,len=6,numeric"`
	Posyandu   string `json:"posyandu"`
	PosyanduID string `json:"posyandu_id"` // alias dari Posyandu
}

// Role selalu orang_tua, tidak diambil dari input client
func (s *AuthService) RegisterOrangTua(in RegisterInput) (*models.User, error) {
	if err := pinMudah(in.Pin); err != nil {
		return nil, err
	}
	raw := strings.TrimSpace(in.Posyandu)
	if raw == "" {
		raw = strings.TrimSpace(in.PosyanduID)
	}
	pos, ok := models.NormalisasiPosyandu(raw)
	if !ok {
		return nil, ErrPosyandu
	}
	if s.repo.Exists("nik", in.NIK) || s.repo.Exists("no_hp", in.NoHP) {
		return nil, ErrDuplicate
	}
	hash, err := utils.HashPIN(in.Pin)
	if err != nil {
		return nil, err
	}
	u := &models.User{Nama: in.Nama, NIK: &in.NIK, NoHP: &in.NoHP,
		PinHash: hash, Role: models.RoleOrangTua, Posyandu: pos, IsActive: true}
	return u, s.repo.Create(u)
}

type CreateStaffInput struct {
	Nama     string      `json:"nama" binding:"required"`
	Username string      `json:"username" binding:"required,min=4"`
	NoHP     string      `json:"no_hp" binding:"required,min=10,max=15,numeric"`
	Pin      string      `json:"pin" binding:"required,len=6,numeric"` // PIN awal
	Role     models.Role `json:"role" binding:"required"`
}

// Akun kader/bidan selalu dibuat pada posyandu milik sekretaris yang membuatnya.
// Petugas langsung masuk ke beranda dengan PIN dari sekretaris (tidak wajib ganti PIN).
func (s *AuthService) CreateStaff(posyandu string, in CreateStaffInput) (*models.User, error) {
	if in.Role != models.RoleKader && in.Role != models.RoleBidan {
		return nil, ErrInvalidRole
	}
	if err := pinMudah(in.Pin); err != nil {
		return nil, err
	}
	pos, ok := models.NormalisasiPosyandu(posyandu)
	if !ok {
		return nil, ErrPosyandu
	}
	if s.repo.Exists("username", in.Username) || s.repo.Exists("no_hp", in.NoHP) {
		return nil, ErrDuplicate
	}
	hash, err := utils.HashPIN(in.Pin)
	if err != nil {
		return nil, err
	}
	u := &models.User{Nama: in.Nama, Username: &in.Username, NoHP: &in.NoHP, PinHash: hash,
		Role: in.Role, Posyandu: pos, IsActive: true, WajibGantiPIN: false}
	return u, s.repo.Create(u)
}

func (s *AuthService) Me(id uint) (*models.User, error) { return s.repo.FindByID(id) }