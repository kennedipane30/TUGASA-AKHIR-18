package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// RencanaImunisasi: Saran vaksin berikutnya, vaksin terlewat, dan penyesuaian bidan.
type RencanaImunisasi struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	JadwalImunisasiID uuid.UUID `gorm:"column:jadwal_imunisasi_id;type:uuid;not null;index" json:"jadwal_imunisasi_id"`
	PerkiraanTanggal time.Time `gorm:"column:perkiraan_tanggal;type:date;not null" json:"perkiraan_tanggal"`
	Status string `gorm:"column:status;size:15;default:direncanakan" json:"status"`
	DisesuaikanOleh *uint `gorm:"column:disesuaikan_oleh;index" json:"disesuaikan_oleh"`
	AlasanPenyesuaian string `gorm:"column:alasan_penyesuaian;type:text" json:"alasan_penyesuaian"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	JadwalImunisasi *JadwalImunisasi `gorm:"foreignKey:JadwalImunisasiID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DisesuaikanOlehUser *User `gorm:"foreignKey:DisesuaikanOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (RencanaImunisasi) TableName() string { return "rencana_imunisasi" }

func (m *RencanaImunisasi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
