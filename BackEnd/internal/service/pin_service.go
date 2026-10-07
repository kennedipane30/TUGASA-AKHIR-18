package service

import (
	"errors"
	"fmt"
	"math"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"
	"posyandu-api/internal/utils"
)

const (
	maksGagalLogin = 5
	durasiKunci    = 15 * time.Minute
)

// ErrLoginSalah: identitas atau PIN/kata sandi salah (kode 401).
type ErrLoginSalah struct{ Sisa int }

func (e ErrLoginSalah) Error() string {
	if e.Sisa > 0 {
		return fmt.Sprintf("identitas atau PIN/kata sandi salah, sisa %d percobaan", e.Sisa)
	}
	return "identitas atau PIN/kata sandi salah"
}

// ErrLoginTerkunci: akun dikunci sementara karena terlalu banyak percobaan (kode 429).
type ErrLoginTerkunci struct{ Sisa time.Duration }

func (e ErrLoginTerkunci) Error() string {
	return fmt.Sprintf("terlalu banyak percobaan, akun terkunci. Coba lagi dalam %d menit", int(math.Ceil(e.Sisa.Minutes())))
}

var ErrLoginNonaktif = errors.New("akun tidak aktif, hubungi admin")

// ErrPin: isian PIN/kata sandi tidak memenuhi aturan (kode 400).
type ErrPin struct{ Pesan string }

func (e ErrPin) Error() string { return e.Pesan }

type PinService struct{ repo *repository.UserRepository }

func NewPinService(r *repository.UserRepository) *PinService { return &PinService{r} }

// Login menggantikan AuthService.Login: ditambah penguncian setelah 5 kali salah.
func (s *PinService) Login(identifier, password string) (string, *models.User, error) {
	u, err := s.repo.FindByIdentifier(identifier)
	if err != nil {
		return "", nil, ErrLoginSalah{}
	}

	now := time.Now()
	if u.TerkunciSampai != nil && now.Before(*u.TerkunciSampai) {
		return "", nil, ErrLoginTerkunci{Sisa: u.TerkunciSampai.Sub(now)}
	}

	if !utils.CheckPassword(u.Password, password) {
		u.GagalLogin++
		if u.GagalLogin >= maksGagalLogin {
			sampai := now.Add(durasiKunci)
			u.TerkunciSampai = &sampai
			u.GagalLogin = 0
			_ = s.repo.SimpanStatusLogin(u)
			return "", nil, ErrLoginTerkunci{Sisa: durasiKunci}
		}
		_ = s.repo.SimpanStatusLogin(u)
		return "", nil, ErrLoginSalah{Sisa: maksGagalLogin - u.GagalLogin}
	}

	if !u.IsActive {
		return "", nil, ErrLoginNonaktif
	}

	if u.GagalLogin != 0 || u.TerkunciSampai != nil {
		u.GagalLogin = 0
		u.TerkunciSampai = nil
		_ = s.repo.SimpanStatusLogin(u)
	}

	token, err := utils.GenerateToken(u.ID, string(u.Role))
	if err != nil {
		return "", nil, err
	}
	return token, u, nil
}

// ResetPIN dipakai admin/kader untuk akun orang tua yang lupa PIN.
// Mengembalikan PIN sementara (ditampilkan sekali); orang tua wajib menggantinya.
func (s *PinService) ResetPIN(id uint) (string, error) {
	u, err := s.repo.FindByID(id)
	if err != nil {
		return "", err
	}
	if u.Role != models.RoleOrangTua {
		return "", ErrPin{"hanya akun orang tua yang dapat direset PIN-nya"}
	}
	pin := utils.PINAcak()
	hash, err := utils.HashPassword(pin)
	if err != nil {
		return "", err
	}
	u.Password = hash
	u.MustChangePassword = true
	u.GagalLogin = 0
	u.TerkunciSampai = nil
	if err := s.repo.SimpanSandi(u); err != nil {
		return "", err
	}
	return pin, nil
}

// UbahSandi: pengguna mengganti PIN (orang tua) atau kata sandi (petugas) miliknya.
func (s *PinService) UbahSandi(userID uint, lama, baru string) error {
	u, err := s.repo.FindByID(userID)
	if err != nil {
		return err
	}
	if !utils.CheckPassword(u.Password, lama) {
		return ErrPin{"PIN/kata sandi lama salah"}
	}
	if lama == baru {
		return ErrPin{"PIN/kata sandi baru harus berbeda dari yang lama"}
	}
	if u.Role == models.RoleOrangTua {
		if err := utils.ValidasiPIN(baru); err != nil {
			return ErrPin{err.Error()}
		}
	} else if len(baru) < 6 {
		return ErrPin{"kata sandi minimal 6 karakter"}
	}
	hash, err := utils.HashPassword(baru)
	if err != nil {
		return err
	}
	u.Password = hash
	u.MustChangePassword = false
	u.GagalLogin = 0
	u.TerkunciSampai = nil
	return s.repo.SimpanSandi(u)
}