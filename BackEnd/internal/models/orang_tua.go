package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// OrangTua: ibu/ayah/wali dalam satu keluarga.
// UserID terisi untuk pemegang akun (ibu yang mendaftar).
type OrangTua struct {
	ID             uuid.UUID      `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	KeluargaID     uuid.UUID      `gorm:"column:keluarga_id;type:uuid;not null;index" json:"keluarga_id"`
	Keluarga       *Keluarga      `gorm:"foreignKey:KeluargaID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	UserID         *uint          `gorm:"column:user_id;uniqueIndex:ux_orang_tua_user_id" json:"user_id,omitempty"`
	User           *User          `gorm:"foreignKey:UserID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	PeranKeluarga  string         `gorm:"column:peran_keluarga;size:10;not null" json:"peran_keluarga"` // ibu | ayah | wali
	NIK            *string        `gorm:"column:nik;size:16;uniqueIndex:ux_orang_tua_nik,where:deleted_at IS NULL" json:"nik,omitempty"`
	Nama           string         `gorm:"column:nama;size:100" json:"nama"`
	TanggalLahir   *time.Time     `gorm:"column:tanggal_lahir;type:date" json:"tanggal_lahir"`
	NoHP           string         `gorm:"column:no_hp;size:20" json:"no_hp"`
	Pekerjaan      string         `gorm:"column:pekerjaan;size:100" json:"pekerjaan"`
	StatusAktivasi string         `gorm:"column:status_aktivasi;size:10;default:aktif" json:"status_aktivasi"`
	Version        int            `gorm:"column:version;default:1" json:"version"`
	PerangkatAsal  *uuid.UUID     `gorm:"column:perangkat_asal;type:uuid" json:"perangkat_asal,omitempty"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (OrangTua) TableName() string { return "orang_tua" }

func (o *OrangTua) BeforeCreate(*gorm.DB) error {
	if o.ID == uuid.Nil {
		o.ID = uuid.New()
	}
	return nil
}
