package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// JenisVaksin: Master jenis vaksin.
type JenisVaksin struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Kode string `gorm:"column:kode;size:20;not null;uniqueIndex:ux_jenis_vaksin_kode" json:"kode"`
	Nama string `gorm:"column:nama;size:100;not null" json:"nama"`
	Keterangan string `gorm:"column:keterangan;type:text" json:"keterangan"`
	JumlahDosis int16 `gorm:"column:jumlah_dosis" json:"jumlah_dosis"`
	IsActive bool `gorm:"column:is_active;default:true" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (JenisVaksin) TableName() string { return "jenis_vaksin" }

func (m *JenisVaksin) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
