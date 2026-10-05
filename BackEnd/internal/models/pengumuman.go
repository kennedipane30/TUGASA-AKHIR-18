package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Pengumuman: Pengumuman dari admin kepada semua pengguna atau role tertentu.
type Pengumuman struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Judul string `gorm:"column:judul;size:150;not null" json:"judul"`
	Isi string `gorm:"column:isi;type:text" json:"isi"`
	TargetRole string `gorm:"column:target_role;size:15" json:"target_role"`
	DibuatOleh uint `gorm:"column:dibuat_oleh;not null;index" json:"dibuat_oleh"`
	Status string `gorm:"column:status;size:10;default:draft" json:"status"`
	WaktuKirim *time.Time `gorm:"column:waktu_kirim" json:"waktu_kirim"`
	DibuatOlehUser *User `gorm:"foreignKey:DibuatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Pengumuman) TableName() string { return "pengumuman" }

func (m *Pengumuman) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
