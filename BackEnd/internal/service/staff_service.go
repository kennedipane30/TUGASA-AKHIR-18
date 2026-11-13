package service

import (
	"errors"

	"posyandu-api/internal/models"
	"posyandu-api/internal/utils"
)

var (
	ErrNotFound = errors.New("akun tidak ditemukan")
	ErrNotStaff = errors.New("hanya akun kader atau bidan yang dapat dikelola")
)

type UpdateStaffInput struct {
	Nama     string      `json:"nama" binding:"required"`
	Username string      `json:"username" binding:"required,min=4"`
	NoHP     string      `json:"no_hp" binding:"omitempty,min=10,max=15,numeric"`
	Pin      string      `json:"pin" binding:"omitempty,len=6,numeric"` // PIN baru (opsional)
	Role     models.Role `json:"role" binding:"required"`
}

// ListStaff: kader dan bidan pada posyandu milik sekretaris.
func (s *AuthService) ListStaff(role, posyandu string) ([]models.User, error) {
	roles := []string{string(models.RoleKader), string(models.RoleBidan)}
	if role == string(models.RoleKader) || role == string(models.RoleBidan) {
		roles = []string{role}
	}
	return s.repo.FindByRoles(roles, posyandu)
}

// staffByID: akun di posyandu lain diperlakukan seperti tidak ada.
func (s *AuthService) staffByID(id uint, posyandu string) (*models.User, error) {
	u, err := s.repo.FindByID(id)
	if err != nil {
		return nil, ErrNotFound
	}
	if posyandu == "" || u.Posyandu != posyandu {
		return nil, ErrNotFound
	}
	if u.Role != models.RoleKader && u.Role != models.RoleBidan {
		return nil, ErrNotStaff
	}
	// Akun yang sudah dihapus (diarsipkan) tidak dapat diubah lagi.
	if u.DiarsipkanPada != nil {
		return nil, ErrNotFound
	}
	return u, nil
}

func (s *AuthService) UpdateStaff(id uint, posyandu string, in UpdateStaffInput) (*models.User, error) {
	u, err := s.staffByID(id, posyandu)
	if err != nil {
		return nil, err
	}
	if in.Role != models.RoleKader && in.Role != models.RoleBidan {
		return nil, ErrInvalidRole
	}
	if in.Pin != "" {
		if err := pinMudah(in.Pin); err != nil {
			return nil, err
		}
	}
	if s.repo.ExistsExcept("username", in.Username, u.ID) {
		return nil, ErrDuplicate
	}
	if in.NoHP != "" && s.repo.ExistsExcept("no_hp", in.NoHP, u.ID) {
		return nil, ErrDuplicate
	}
	u.Nama = in.Nama
	u.Username = &in.Username
	if in.NoHP != "" {
		u.NoHP = &in.NoHP
	}
	u.Role = in.Role
	if in.Pin != "" {
		hash, err := utils.HashPIN(in.Pin)
		if err != nil {
			return nil, err
		}
		u.PinHash = hash
		u.WajibGantiPIN = false
		u.GagalLogin = 0
		u.TerkunciSampai = nil
	}
	return u, s.repo.Save(u)
}

func (s *AuthService) SetStaffActive(id uint, posyandu string, aktif bool) (*models.User, error) {
	u, err := s.staffByID(id, posyandu)
	if err != nil {
		return nil, err
	}
	u.IsActive = aktif
	return u, s.repo.Save(u)
}

// DeleteStaff: akun petugas diarsipkan, bukan dihapus permanen, karena
// namanya tercatat pada data pemeriksaan, imunisasi, suplemen, dan notifikasi.
// Akun tidak bisa login lagi dan hilang dari daftar Kelola Akun.
func (s *AuthService) DeleteStaff(id uint, posyandu string) error {
	u, err := s.staffByID(id, posyandu)
	if err != nil {
		return err
	}
	return s.repo.Arsipkan(u)
}