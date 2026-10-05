package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SuplemenAnak: Pemberian vitamin A, obat cacing, dan makanan tambahan (PMT).
type SuplemenAnak struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	Jenis string `gorm:"column:jenis;size:15" json:"jenis"`
	Tanggal time.Time `gorm:"column:tanggal;type:date;not null" json:"tanggal"`
	KeteranganDosis string `gorm:"column:keterangan_dosis;size:100" json:"keterangan_dosis"`
	PendaftaranID *uuid.UUID `gorm:"column:pendaftaran_id;type:uuid;index" json:"pendaftaran_id"`
	DiberikanOleh uint `gorm:"column:diberikan_oleh;not null;index" json:"diberikan_oleh"`
	Catatan string `gorm:"column:catatan;type:text" json:"catatan"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Pendaftaran *Pendaftaran `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DiberikanOlehUser *User `gorm:"foreignKey:DiberikanOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (SuplemenAnak) TableName() string { return "suplemen_anak" }

func (m *SuplemenAnak) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
