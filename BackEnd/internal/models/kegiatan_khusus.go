package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KegiatanKhusus: Kegiatan khusus pada jadwal tertentu.
type KegiatanKhusus struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	JadwalID uuid.UUID `gorm:"column:jadwal_id;type:uuid;not null;index" json:"jadwal_id"`
	Jenis string `gorm:"column:jenis;size:30" json:"jenis"`
	Nama string `gorm:"column:nama;size:100;not null" json:"nama"`
	Keterangan string `gorm:"column:keterangan;type:text" json:"keterangan"`
	Jadwal *JadwalPosyandu `gorm:"foreignKey:JadwalID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (KegiatanKhusus) TableName() string { return "kegiatan_khusus" }

func (m *KegiatanKhusus) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
