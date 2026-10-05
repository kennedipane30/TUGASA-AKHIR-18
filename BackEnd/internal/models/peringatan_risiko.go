package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PeringatanRisiko: Peringatan otomatis anak berisiko beserta status penanganannya.
type PeringatanRisiko struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	PengukuranID uuid.UUID `gorm:"column:pengukuran_id;type:uuid;not null;index" json:"pengukuran_id"`
	Jenis string `gorm:"column:jenis;size:20" json:"jenis"`
	Penyebab string `gorm:"column:penyebab;type:text" json:"penyebab"`
	Prioritas int16 `gorm:"column:prioritas" json:"prioritas"`
	StatusPenanganan string `gorm:"column:status_penanganan;size:15;default:baru" json:"status_penanganan"`
	DibuatOtomatis bool `gorm:"column:dibuat_otomatis;default:true" json:"dibuat_otomatis"`
	DitutupPada *time.Time `gorm:"column:ditutup_pada" json:"ditutup_pada"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Pengukuran *Pengukuran `gorm:"foreignKey:PengukuranID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (PeringatanRisiko) TableName() string { return "peringatan_risiko" }

func (m *PeringatanRisiko) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
