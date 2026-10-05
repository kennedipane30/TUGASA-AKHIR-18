package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// StandarAntropometri: Tabel standar antropometri anak untuk menghitung status gizi.
type StandarAntropometri struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Indikator string `gorm:"column:indikator;size:10;not null;uniqueIndex:ux_standar_antropometri_komposit" json:"indikator"`
	JenisKelamin string `gorm:"column:jenis_kelamin;size:1;not null;uniqueIndex:ux_standar_antropometri_komposit" json:"jenis_kelamin"`
	Acuan float64 `gorm:"column:acuan;type:numeric(5,1);not null;uniqueIndex:ux_standar_antropometri_komposit" json:"acuan"`
	SdMin3 *float64 `gorm:"column:sd_min3;type:numeric(5,2)" json:"sd_min3"`
	SdMin2 *float64 `gorm:"column:sd_min2;type:numeric(5,2)" json:"sd_min2"`
	SdMin1 *float64 `gorm:"column:sd_min1;type:numeric(5,2)" json:"sd_min1"`
	Median *float64 `gorm:"column:median;type:numeric(5,2)" json:"median"`
	SdPlus1 *float64 `gorm:"column:sd_plus1;type:numeric(5,2)" json:"sd_plus1"`
	SdPlus2 *float64 `gorm:"column:sd_plus2;type:numeric(5,2)" json:"sd_plus2"`
	SdPlus3 *float64 `gorm:"column:sd_plus3;type:numeric(5,2)" json:"sd_plus3"`
	Sumber string `gorm:"column:sumber;size:50" json:"sumber"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (StandarAntropometri) TableName() string { return "standar_antropometri" }

func (m *StandarAntropometri) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
