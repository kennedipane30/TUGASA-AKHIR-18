package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Tujuan kode OTP.
const (
	TujuanOTPRegistrasi = "registrasi" // daftar akun orang tua baru
	TujuanOTPResetPIN   = "reset_pin"  // lupa PIN, atur PIN baru sendiri
)

// KodeOTP adalah kode verifikasi 6 digit yang dikirim lewat WhatsApp.
//
// Tabel : kode_otp
// Alur  :
//  1. Kirim     : baris baru dibuat, KodeHash = hash bcrypt kode (kode asli tidak disimpan).
//  2. Verifikasi: kode cocok -> DiverifikasiPada terisi dan server membuat token
//     verifikasi sekali pakai (TokenHash = sha256 token, berlaku 15 menit).
//  3. Pakai     : token dipakai untuk registrasi / reset PIN -> TokenDipakaiPada terisi.
//
// Kode hangus bila lewat KedaluwarsaPada (5 menit), salah 5 kali, atau
// diganti kode baru (kirim ulang).
type KodeOTP struct {
	ID     uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	NoHP   string    `gorm:"column:no_hp;size:20;not null;index:ix_kode_otp_hp_tujuan" json:"no_hp"`
	Tujuan string    `gorm:"column:tujuan;size:20;not null;index:ix_kode_otp_hp_tujuan" json:"tujuan"`

	// KodeHash: hash bcrypt kode 6 digit.
	KodeHash        string    `gorm:"column:kode_hash;not null" json:"-"`
	KedaluwarsaPada time.Time `gorm:"column:kedaluwarsa_pada;not null" json:"kedaluwarsa_pada"`
	Percobaan       int       `gorm:"column:percobaan;default:0" json:"-"`

	// DiverifikasiPada: terisi setelah kode yang diketik pengguna cocok.
	DiverifikasiPada *time.Time `gorm:"column:diverifikasi_pada" json:"diverifikasi_pada,omitempty"`

	// TokenHash: sha256 token verifikasi yang dikirim ke aplikasi setelah kode cocok.
	TokenHash          string     `gorm:"column:token_hash;size:64;index" json:"-"`
	TokenBerlakuSampai *time.Time `gorm:"column:token_berlaku_sampai" json:"-"`
	TokenDipakaiPada   *time.Time `gorm:"column:token_dipakai_pada" json:"-"`

	IP        string    `gorm:"column:ip;size:64" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (KodeOTP) TableName() string { return "kode_otp" }

func (m *KodeOTP) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}