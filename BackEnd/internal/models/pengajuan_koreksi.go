package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PengajuanKoreksi: Pengajuan koreksi data anak oleh orang tua beserta status penanganannya.
type PengajuanKoreksi struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	KolomDikoreksi string `gorm:"column:kolom_dikoreksi;size:50" json:"kolom_dikoreksi"`
	NilaiLama string `gorm:"column:nilai_lama;type:text" json:"nilai_lama"`
	NilaiBaru string `gorm:"column:nilai_baru;type:text" json:"nilai_baru"`
	Alasan string `gorm:"column:alasan;type:text" json:"alasan"`
	DiajukanOleh uint `gorm:"column:diajukan_oleh;not null;index" json:"diajukan_oleh"`
	Status string `gorm:"column:status;size:20;default:menunggu" json:"status"`
	DitanganiOleh *uint `gorm:"column:ditangani_oleh;index" json:"ditangani_oleh"`
	DitanganiPada *time.Time `gorm:"column:ditangani_pada" json:"ditangani_pada"`
	CatatanPenanganan string `gorm:"column:catatan_penanganan;type:text" json:"catatan_penanganan"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DiajukanOlehUser *User `gorm:"foreignKey:DiajukanOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DitanganiOlehUser *User `gorm:"foreignKey:DitanganiOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (PengajuanKoreksi) TableName() string { return "pengajuan_koreksi" }

func (m *PengajuanKoreksi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
