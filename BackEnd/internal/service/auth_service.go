package service

import (
	"errors"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"
	"posyandu-api/internal/utils"
)

var (
	ErrInvalidCredentials = errors.New("identitas atau kata sandi salah")
	ErrInactive           = errors.New("akun tidak aktif, hubungi admin")
	ErrDuplicate          = errors.New("NIK, No. HP, atau username sudah terdaftar")
	ErrInvalidRole        = errors.New("role hanya boleh kader atau bidan")
)

type AuthService struct{ repo *repository.UserRepository }

func NewAuthService(r *repository.UserRepository) *AuthService { return &AuthService{r} }

type RegisterInput struct {
	Nama     string `json:"nama" binding:"required"`
	NIK      string `json:"nik" binding:"required,len=16,numeric"`
	NoHP     string `json:"no_hp" binding:"required,min=10,max=15"`
	Password string `json:"password" binding:"required,len=6,numeric"` // PIN 6 digit
}

// Role selalu orang_tua, tidak diambil dari input client
func (s *AuthService) RegisterOrangTua(in RegisterInput) (*models.User, error) {
	if err := utils.ValidasiPIN(in.Password); err != nil {
		return nil, ErrPin{err.Error()}
	}
	if s.repo.Exists("nik", in.NIK) || s.repo.Exists("no_hp", in.NoHP) {
		return nil, ErrDuplicate
	}
	hash, err := utils.HashPassword(in.Password)
	if err != nil {
		return nil, err
	}
	u := &models.User{Nama: in.Nama, NIK: &in.NIK, NoHP: &in.NoHP,
		Password: hash, Role: models.RoleOrangTua, IsActive: true}
	return u, s.repo.Create(u)
}

type CreateStaffInput struct {
	Nama     string      `json:"nama" binding:"required"`
	Username string      `json:"username" binding:"required,min=4"`
	Password string      `json:"password" binding:"required,min=6"`
	Role     models.Role `json:"role" binding:"required"`
}

func (s *AuthService) CreateStaff(in CreateStaffInput) (*models.User, error) {
	if in.Role != models.RoleKader && in.Role != models.RoleBidan {
		return nil, ErrInvalidRole
	}
	if s.repo.Exists("username", in.Username) {
		return nil, ErrDuplicate
	}
	hash, err := utils.HashPassword(in.Password)
	if err != nil {
		return nil, err
	}
	u := &models.User{Nama: in.Nama, Username: &in.Username, Password: hash,
		Role: in.Role, IsActive: true, MustChangePassword: true}
	return u, s.repo.Create(u)
}

func (s *AuthService) Login(idf, password string) (string, *models.User, error) {
	u, err := s.repo.FindByIdentifier(idf)
	if err != nil || !utils.CheckPassword(u.Password, password) {
		return "", nil, ErrInvalidCredentials // pesan sama agar tidak bocor info
	}
	if !u.IsActive {
		return "", nil, ErrInactive
	}
	token, err := utils.GenerateToken(u.ID, string(u.Role))
	return token, u, err
}

func (s *AuthService) Me(id uint) (*models.User, error) { return s.repo.FindByID(id) }