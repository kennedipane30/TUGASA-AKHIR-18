package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KunjunganRumah: Catatan kunjungan rumah kader untuk anak yang tidak hadir.
type KunjunganRumah struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	JadwalID *uuid.UUID `gorm:"column:jadwal_id;type:uuid;index" json:"jadwal_id"`
	KaderID uint `gorm:"column:kader_id;not null;index" json:"kader_id"`
	Tanggal time.Time `gorm:"column:tanggal;type:date;not null" json:"tanggal"`
	Hasil string `gorm:"column:hasil;type:text" json:"hasil"`
	Kendala string `gorm:"column:kendala;type:text" json:"kendala"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Jadwal *JadwalPosyandu `gorm:"foreignKey:JadwalID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Kader *User `gorm:"foreignKey:KaderID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (KunjunganRumah) TableName() string { return "kunjungan_rumah" }

func (m *KunjunganRumah) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
