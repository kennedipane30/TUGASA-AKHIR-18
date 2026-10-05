package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Keluarga: satu keluarga balita (alamat dan RT/RW).
// Karena posyandu hanya satu, tidak ada kolom pilihan posyandu.
type Keluarga struct {
	ID            uuid.UUID      `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	NoKK          *string        `gorm:"column:no_kk;size:16;uniqueIndex:ux_keluarga_no_kk,where:deleted_at IS NULL" json:"no_kk,omitempty"`
	Alamat        string         `gorm:"column:alamat;type:text" json:"alamat"`
	RT            string         `gorm:"column:rt;size:5" json:"rt"`
	RW            string         `gorm:"column:rw;size:5" json:"rw"`
	NoKontak      string         `gorm:"column:no_kontak;size:20" json:"no_kontak"`
	TanpaAyah     bool           `gorm:"column:tanpa_ayah;default:false" json:"tanpa_ayah"`
	Status        string         `gorm:"column:status;size:10;default:aktif" json:"status"`
	Version       int            `gorm:"column:version;default:1" json:"version"`
	PerangkatAsal *uuid.UUID     `gorm:"column:perangkat_asal;type:uuid" json:"perangkat_asal,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Keluarga) TableName() string { return "keluarga" }

func (k *Keluarga) BeforeCreate(*gorm.DB) error {
	if k.ID == uuid.Nil {
		k.ID = uuid.New()
	}
	return nil
}
