package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PetugasJadwal: Kader dan bidan yang bertugas pada suatu jadwal (relasi banyak-ke-banyak).
type PetugasJadwal struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	JadwalID uuid.UUID `gorm:"column:jadwal_id;type:uuid;not null;uniqueIndex:ux_petugas_jadwal_komposit,where:deleted_at IS NULL" json:"jadwal_id"`
	UserID uint `gorm:"column:user_id;not null;uniqueIndex:ux_petugas_jadwal_komposit,where:deleted_at IS NULL" json:"user_id"`
	PeranTugas string `gorm:"column:peran_tugas;size:10;not null" json:"peran_tugas"`
	Jadwal *JadwalPosyandu `gorm:"foreignKey:JadwalID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	User *User `gorm:"foreignKey:UserID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (PetugasJadwal) TableName() string { return "petugas_jadwal" }

func (m *PetugasJadwal) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
