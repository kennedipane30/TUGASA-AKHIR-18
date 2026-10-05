package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// VerifikasiPengukuran: Keputusan bidan: menyetujui atau mengembalikan data ke kader.
type VerifikasiPengukuran struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	PengukuranID uuid.UUID `gorm:"column:pengukuran_id;type:uuid;not null;index" json:"pengukuran_id"`
	BidanID uint `gorm:"column:bidan_id;not null;index" json:"bidan_id"`
	Keputusan string `gorm:"column:keputusan;size:15;not null" json:"keputusan"`
	Alasan string `gorm:"column:alasan;type:text" json:"alasan"`
	Waktu time.Time `gorm:"column:waktu;autoCreateTime" json:"waktu"`
	Pengukuran *Pengukuran `gorm:"foreignKey:PengukuranID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Bidan *User `gorm:"foreignKey:BidanID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (VerifikasiPengukuran) TableName() string { return "verifikasi_pengukuran" }

func (m *VerifikasiPengukuran) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
