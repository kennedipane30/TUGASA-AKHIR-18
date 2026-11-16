package service

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"math/big"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"
	"posyandu-api/internal/utils"

	"gorm.io/gorm"
)

const (
	otpBerlaku       = 5 * time.Minute  // kode 6 digit berlaku 5 menit
	otpJedaKirim     = 60 * time.Second // jeda minimal sebelum kirim ulang
	otpMaksPerJam    = 5                // maksimal kode per nomor dalam 1 jam
	otpMaksPercobaan = 5                // salah 5 kali -> kode hangus
	otpTokenBerlaku  = 15 * time.Minute // token verifikasi berlaku 15 menit
)

// ErrOtpTunggu: terlalu cepat / terlalu sering meminta kode (kode 429).
type ErrOtpTunggu struct{ Pesan string }

func (e ErrOtpTunggu) Error() string { return e.Pesan }

// OtpService: kode OTP WhatsApp untuk registrasi orang tua dan lupa PIN.
//
// Alur registrasi:
//
//	POST /auth/otp/kirim       {no_hp, tujuan:"registrasi"}
//	POST /auth/otp/verifikasi  {no_hp, tujuan:"registrasi", kode}  -> token_otp
//	POST /auth/register-otp    {nama, nik, no_hp, pin, posyandu, token_otp}
//
// Alur lupa PIN (dari halaman login; identitas = No. HP / NIK / username
// yang diketik di login, kode dikirim ke No. WhatsApp terdaftar di akun):
//
//	POST /auth/otp/kirim       {identitas, tujuan:"reset_pin"}
//	POST /auth/otp/verifikasi  {identitas, tujuan:"reset_pin", kode}   -> token_otp
//	POST /auth/lupa-pin        {identitas, pin_baru, token_otp}
type OtpService struct {
	repo  *repository.OtpRepository
	users *repository.UserRepository
	auth  *AuthService
	wa    *WaService
}

func NewOtpService(r *repository.OtpRepository, u *repository.UserRepository, a *AuthService, wa *WaService) *OtpService {
	return &OtpService{repo: r, users: u, auth: a, wa: wa}
}

// NormalisasiNoHP mengubah "+62 812-3456-7890" / "6281234567890" menjadi "081234567890".
func NormalisasiNoHP(s string) (string, bool) {
	s = strings.NewReplacer(" ", "", "-", "", "+", "", "(", "", ")", "").Replace(strings.TrimSpace(s))
	if strings.HasPrefix(s, "62") {
		s = "0" + s[2:]
	}
	if !strings.HasPrefix(s, "08") || len(s) < 10 || len(s) > 14 {
		return "", false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return "", false
		}
	}
	return s, true
}

// NoHPAkun: No. WhatsApp terdaftar milik akun dengan identitas
// (No. HP / NIK / username) yang diketik di halaman login. Dipakai untuk Lupa PIN.
func (s *OtpService) NoHPAkun(identitas string) (string, error) {
	idf := strings.TrimSpace(identitas)
	if idf == "" {
		return "", validasi("isi No. HP, NIK, atau username terlebih dahulu")
	}
	u, err := s.users.FindByIdentifier(idf)
	if err != nil {
		if hp, ok := NormalisasiNoHP(idf); ok {
			u, err = s.users.FindByIdentifier(hp)
		}
	}
	if err != nil {
		return "", konflik("akun tidak ditemukan, periksa kembali No. HP, NIK, atau username")
	}
	if u.NoHP == nil || strings.TrimSpace(*u.NoHP) == "" {
		return "", konflik("akun ini belum memiliki No. WhatsApp, hubungi sekretaris posyandu")
	}
	hp, ok := NormalisasiNoHP(*u.NoHP)
	if !ok {
		return "", konflik("No. WhatsApp akun tidak valid, hubungi sekretaris posyandu")
	}
	return hp, nil
}

// samarkanNoHP: 081234567890 -> 0812****7890 (untuk ditampilkan di aplikasi).
func samarkanNoHP(s string) string {
	if len(s) < 8 {
		return s
	}
	return s[:4] + strings.Repeat("*", len(s)-8) + s[len(s)-4:]
}

func tujuanValid(t string) bool {
	return t == models.TujuanOTPRegistrasi || t == models.TujuanOTPResetPIN
}

func buatKodeOTP() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func buatTokenOTP() (token, hash string, err error) {
	b := make([]byte, 32)
	if _, err = rand.Read(b); err != nil {
		return "", "", err
	}
	token = hex.EncodeToString(b)
	return token, hashToken(token), nil
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

// ---------------------------------------------------------------- kirim kode

type KirimOTPHasil struct {
	NoHP            string `json:"no_hp"` // sudah disamarkan
	BerlakuDetik    int    `json:"berlaku_detik"`
	KirimUlangDetik int    `json:"kirim_ulang_detik"`
	ModeUji         bool   `json:"mode_uji"` // true bila WA_API_TOKEN kosong (kode hanya di log server)
}

func (s *OtpService) Kirim(noHP, tujuan, ip string) (*KirimOTPHasil, error) {
	hp, ok := NormalisasiNoHP(noHP)
	if !ok {
		return nil, validasi("No. WhatsApp tidak valid, gunakan format 08xxxxxxxxxx")
	}
	if !tujuanValid(tujuan) {
		return nil, validasi("tujuan kode tidak valid")
	}

	switch tujuan {
	case models.TujuanOTPRegistrasi:
		if s.repo.NoHPTerdaftar(hp) {
			return nil, konflik("No. WhatsApp sudah terdaftar. Silakan masuk, atau pilih Lupa PIN")
		}
	case models.TujuanOTPResetPIN:
		u, err := s.repo.CariUserByNoHP(hp)
		if err != nil {
			return nil, konflik("No. WhatsApp belum terdaftar")
		}
		if !u.IsActive {
			return nil, terlarang("akun tidak aktif, hubungi sekretaris")
		}
	}

	now := time.Now()
	if akhir, err := s.repo.Terakhir(hp, tujuan); err == nil {
		if sisa := akhir.CreatedAt.Add(otpJedaKirim).Sub(now); sisa > 0 {
			return nil, ErrOtpTunggu{Pesan: fmt.Sprintf("tunggu %d detik sebelum mengirim ulang kode", int(math.Ceil(sisa.Seconds())))}
		}
	}
	if s.repo.JumlahKirimSejak(hp, now.Add(-time.Hour)) >= otpMaksPerJam {
		return nil, ErrOtpTunggu{Pesan: "terlalu sering meminta kode, coba lagi 1 jam lagi"}
	}

	kode, err := buatKodeOTP()
	if err != nil {
		return nil, err
	}
	hash, err := utils.HashPIN(kode) // bcrypt, sama seperti PIN
	if err != nil {
		return nil, err
	}

	if err := s.repo.HanguskanYangAktif(hp, tujuan, now); err != nil {
		return nil, err
	}
	k := &models.KodeOTP{
		NoHP:            hp,
		Tujuan:          tujuan,
		KodeHash:        hash,
		KedaluwarsaPada: now.Add(otpBerlaku),
		IP:              ip,
	}
	if err := s.repo.Simpan(k); err != nil {
		return nil, err
	}

	if err := s.wa.Kirim(hp, pesanOTP(kode, tujuan)); err != nil {
		_ = s.repo.Hanguskan(k.ID, time.Now())
		return nil, err
	}

	return &KirimOTPHasil{
		NoHP:            samarkanNoHP(hp),
		BerlakuDetik:    int(otpBerlaku.Seconds()),
		KirimUlangDetik: int(otpJedaKirim.Seconds()),
		ModeUji:         !s.wa.Aktif(),
	}, nil
}

func pesanOTP(kode, tujuan string) string {
	keperluan := "pendaftaran akun"
	if tujuan == models.TujuanOTPResetPIN {
		keperluan = "atur ulang PIN"
	}
	return fmt.Sprintf(
		"*PosyanduCare*\n\nKode verifikasi %s Anda:\n\n*%s*\n\nBerlaku %d menit. Jangan berikan kode ini kepada siapa pun, termasuk petugas posyandu.",
		keperluan, kode, int(otpBerlaku.Minutes()),
	)
}

// ---------------------------------------------------------------- verifikasi kode

type VerifikasiOTPHasil struct {
	TokenOTP     string `json:"token_otp"`
	BerlakuDetik int    `json:"berlaku_detik"`
}

func (s *OtpService) Verifikasi(noHP, tujuan, kode string) (*VerifikasiOTPHasil, error) {
	hp, ok := NormalisasiNoHP(noHP)
	if !ok || !tujuanValid(tujuan) {
		return nil, validasi("permintaan verifikasi tidak valid")
	}
	kode = strings.TrimSpace(kode)
	if !utils.FormatPIN(kode) { // sama-sama 6 digit angka
		return nil, validasi("kode harus 6 digit angka")
	}

	now := time.Now()
	k, err := s.repo.KodeAktif(hp, tujuan, now)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, validasi("kode sudah tidak berlaku, silakan kirim ulang kode")
		}
		return nil, err
	}

	if !utils.CekPIN(k.KodeHash, kode) {
		_ = s.repo.TambahPercobaan(k.ID)
		sisa := otpMaksPercobaan - (k.Percobaan + 1)
		if sisa <= 0 {
			_ = s.repo.Hanguskan(k.ID, now)
			return nil, validasi("kode salah terlalu banyak, silakan kirim ulang kode")
		}
		return nil, validasi("kode salah, sisa %d percobaan", sisa)
	}

	token, hash, err := buatTokenOTP()
	if err != nil {
		return nil, err
	}
	if err := s.repo.TandaiTerverifikasi(k.ID, hash, now, now.Add(otpTokenBerlaku)); err != nil {
		return nil, err
	}
	return &VerifikasiOTPHasil{TokenOTP: token, BerlakuDetik: int(otpTokenBerlaku.Seconds())}, nil
}

// pakaiToken: cek token verifikasi lalu tandai sudah dipakai (sekali pakai).
func (s *OtpService) pakaiToken(token, noHP, tujuan string) (*models.KodeOTP, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return nil, validasi("verifikasi WhatsApp wajib dilakukan")
	}
	now := time.Now()
	k, err := s.repo.CariToken(hashToken(token), noHP, tujuan, now)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, validasi("verifikasi WhatsApp sudah kedaluwarsa, silakan ulangi kirim kode")
		}
		return nil, err
	}
	ok, err := s.repo.PakaiToken(k.ID, now)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, validasi("verifikasi WhatsApp sudah dipakai, silakan ulangi kirim kode")
	}
	return k, nil
}

// ---------------------------------------------------------------- registrasi

// RegisterOTPInput: data registrasi biasa + token dari langkah verifikasi.
type RegisterOTPInput struct {
	RegisterInput
	TokenOTP string `json:"token_otp" binding:"required"`
}

// RegisterDenganOTP: daftar akun orang tua setelah No. WhatsApp terverifikasi.
// Pembuatan akun tetap memakai AuthService.RegisterOrangTua (aturan sama persis).
func (s *OtpService) RegisterDenganOTP(in RegisterOTPInput) (*models.User, error) {
	hp, ok := NormalisasiNoHP(in.NoHP)
	if !ok {
		return nil, validasi("No. WhatsApp tidak valid")
	}
	in.NoHP = hp

	k, err := s.pakaiToken(in.TokenOTP, hp, models.TujuanOTPRegistrasi)
	if err != nil {
		return nil, err
	}
	u, err := s.auth.RegisterOrangTua(in.RegisterInput)
	if err != nil {
		// mis. NIK sudah terdaftar: token dikembalikan agar pengguna cukup memperbaiki data
		_ = s.repo.BatalPakaiToken(k.ID)
		return nil, err
	}
	return u, nil
}

// ---------------------------------------------------------------- lupa PIN

// ResetPINDenganOTP: pemilik akun mengatur PIN baru sendiri setelah No. WhatsApp terverifikasi.
func (s *OtpService) ResetPINDenganOTP(noHP, tokenOTP, pinBaru string) error {
	hp, ok := NormalisasiNoHP(noHP)
	if !ok {
		return validasi("No. WhatsApp tidak valid")
	}
	if err := pinMudah(pinBaru); err != nil {
		return err
	}
	u, err := s.repo.CariUserByNoHP(hp)
	if err != nil {
		return konflik("No. WhatsApp belum terdaftar")
	}
	if !u.IsActive {
		return terlarang("akun tidak aktif, hubungi sekretaris")
	}
	if utils.CekPIN(u.PinHash, pinBaru) {
		return ErrPin{Pesan: "PIN baru harus berbeda dari PIN lama"}
	}

	k, err := s.pakaiToken(tokenOTP, hp, models.TujuanOTPResetPIN)
	if err != nil {
		return err
	}
	hash, err := utils.HashPIN(pinBaru)
	if err != nil {
		_ = s.repo.BatalPakaiToken(k.ID)
		return err
	}
	u.PinHash = hash
	u.WajibGantiPIN = false
	u.GagalLogin = 0
	u.TerkunciSampai = nil // akun yang terkunci karena salah PIN ikut terbuka
	if err := s.users.SimpanPIN(u); err != nil {
		_ = s.repo.BatalPakaiToken(k.ID)
		return err
	}
	return nil
}