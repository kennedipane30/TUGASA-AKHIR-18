package models

import "time"

type Role string

const (
	RoleAdmin    Role = "admin"
	RoleBidan    Role = "bidan"
	RoleKader    Role = "kader"
	RoleOrangTua Role = "orang_tua"
)

// User: akun untuk keempat role. ID tetap berupa angka agar akun admin yang
// sudah ada tidak hilang; kunci asing dari tabel lain ke users bertipe BIGINT.
type User struct {
	ID                 uint       `gorm:"primaryKey" json:"id"`
	Nama               string     `gorm:"size:100;not null" json:"nama"`
	Username           *string    `gorm:"size:50;uniqueIndex" json:"username,omitempty"`
	NIK                *string    `gorm:"size:16;uniqueIndex" json:"nik,omitempty"`
	NoHP               *string    `gorm:"size:20;uniqueIndex" json:"no_hp,omitempty"`
	Password           string     `gorm:"not null" json:"-"`
	Role               Role       `gorm:"size:20;not null;index" json:"role"`
	Bahasa             string     `gorm:"size:10;default:id" json:"bahasa"`
	UkuranHuruf        string     `gorm:"size:10;default:normal" json:"ukuran_huruf"`
	IsActive           bool       `gorm:"default:true" json:"is_active"`
	MustChangePassword bool       `json:"must_change_password"`
	GagalLogin         int        `gorm:"default:0" json:"-"`
	TerkunciSampai     *time.Time `json:"-"`
	TerakhirLogin      *time.Time `json:"terakhir_login,omitempty"`
	DiarsipkanPada     *time.Time `json:"diarsipkan_pada,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}