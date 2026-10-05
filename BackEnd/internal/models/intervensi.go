package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Intervensi: Intervensi yang diberikan dan hasil pemantauan lanjutan.
type Intervensi struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	PeringatanID *uuid.UUID `gorm:"column:peringatan_id;type:uuid;index" json:"peringatan_id"`
	RujukanID *uuid.UUID `gorm:"column:rujukan_id;type:uuid;index" json:"rujukan_id"`
	Jenis string `gorm:"column:jenis;size:50" json:"jenis"`
	Deskripsi string `gorm:"column:deskripsi;type:text" json:"deskripsi"`
	Tanggal time.Time `gorm:"column:tanggal;type:date;not null" json:"tanggal"`
	HasilPemantauan string `gorm:"column:hasil_pemantauan;type:text" json:"hasil_pemantauan"`
	DicatatOleh uint `gorm:"column:dicatat_oleh;not null;index" json:"dicatat_oleh"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Peringatan *PeringatanRisiko `gorm:"foreignKey:PeringatanID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Rujukan *Rujukan `gorm:"foreignKey:RujukanID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DicatatOlehUser *User `gorm:"foreignKey:DicatatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Intervensi) TableName() string { return "intervensi" }

func (m *Intervensi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
