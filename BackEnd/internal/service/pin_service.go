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

// ErrLoginSalah: identitas atau PIN salah (kode 401).
type ErrLoginSalah struct{ Sisa int }

func (e ErrLoginSalah) Error() string {
	if e.Sisa > 0 {
		return fmt.Sprintf("No. HP/username atau PIN salah, sisa %d percobaan", e.Sisa)
	}
	return "No. HP/username atau PIN salah"
}

// ErrLoginTerkunci: akun dikunci sementara karena terlalu banyak percobaan (kode 429).
type ErrLoginTerkunci struct{ Sisa time.Duration }

func (e ErrLoginTerkunci) Error() string {
	return fmt.Sprintf("terlalu banyak percobaan, akun terkunci. Coba lagi dalam %d menit", int(math.Ceil(e.Sisa.Minutes())))
}

var ErrLoginNonaktif = errors.New("akun tidak aktif, hubungi sekretaris")

// ErrPin: isian PIN tidak memenuhi aturan atau tidak diizinkan (kode 400).
type ErrPin struct{ Pesan string }

func (e ErrPin) Error() string { return e.Pesan }

// pinMudah: bungkus hasil utils.ValidasiPIN menjadi ErrPin.
func pinMudah(pin string) error {
	if err := utils.ValidasiPIN(pin); err != nil {
		return ErrPin{Pesan: err.Error()}
	}
	return nil
}

type PinService struct{ repo *repository.UserRepository }

func NewPinService(r *repository.UserRepository) *PinService { return &PinService{r} }

// Login: semua role masuk dengan identitas (username / NIK / No. HP) + PIN 6 digit.
// Akun dikunci 15 menit setelah 5 kali PIN salah.
func (s *PinService) Login(identifier, pin string) (string, *models.User, error) {
	if !utils.FormatPIN(pin) {
		return "", nil, ErrPin{Pesan: "PIN harus 6 digit angka"}
	}
	u, err := s.repo.FindByIdentifier(identifier)
	if err != nil {
		return "", nil, ErrLoginSalah{}
	}

	now := time.Now()
	if u.TerkunciSampai != nil && now.Before(*u.TerkunciSampai) {
		return "", nil, ErrLoginTerkunci{Sisa: u.TerkunciSampai.Sub(now)}
	}

	if !utils.CekPIN(u.PinHash, pin) {
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

	u.GagalLogin = 0
	u.TerkunciSampai = nil
	u.TerakhirLogin = &now
	_ = s.repo.SimpanStatusLogin(u)

	token, err := utils.GenerateToken(u.ID, string(u.Role))
	if err != nil {
		return "", nil, err
	}
	return token, u, nil
}

// ResetPIN: petugas membuat PIN sementara untuk akun yang lupa PIN.
//   - sekretaris: akun orang tua, kader, dan bidan di posyandunya
//   - kader     : hanya akun orang tua di posyandunya
//
// PIN sementara ditampilkan sekali; pemilik akun wajib menggantinya saat masuk.
func (s *PinService) ResetPIN(id uint, posyandu, rolePeminta string) (string, error) {
	u, err := s.repo.FindByID(id)
	if err != nil || posyandu == "" || u.Posyandu != posyandu {
		return "", ErrPin{Pesan: "akun tidak ditemukan di posyandu Anda"}
	}
	switch rolePeminta {
	case string(models.RoleSekretaris):
		if u.Role == models.RoleSekretaris {
			return "", ErrPin{Pesan: "PIN sekretaris tidak dapat direset dari aplikasi"}
		}
	case string(models.RoleKader):
		if u.Role != models.RoleOrangTua {
			return "", ErrPin{Pesan: "kader hanya dapat mereset PIN akun orang tua"}
		}
	default:
		return "", ErrPin{Pesan: "tidak berwenang mereset PIN"}
	}

	pin := utils.PINAcak()
	hash, err := utils.HashPIN(pin)
	if err != nil {
		return "", err
	}
	u.PinHash = hash
	u.WajibGantiPIN = true
	u.GagalLogin = 0
	u.TerkunciSampai = nil
	if err := s.repo.SimpanPIN(u); err != nil {
		return "", err
	}
	return pin, nil
}

// UbahPIN: pengguna (semua role) mengganti PIN miliknya sendiri.
func (s *PinService) UbahPIN(userID uint, lama, baru string) error {
	u, err := s.repo.FindByID(userID)
	if err != nil {
		return err
	}
	if !utils.CekPIN(u.PinHash, lama) {
		return ErrPin{Pesan: "PIN lama salah"}
	}
	if lama == baru {
		return ErrPin{Pesan: "PIN baru harus berbeda dari PIN lama"}
	}
	if err := pinMudah(baru); err != nil {
		return err
	}
	hash, err := utils.HashPIN(baru)
	if err != nil {
		return err
	}
	u.PinHash = hash
	u.WajibGantiPIN = false
	u.GagalLogin = 0
	u.TerkunciSampai = nil
	return s.repo.SimpanPIN(u)
}