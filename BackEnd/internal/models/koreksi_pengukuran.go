package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KoreksiPengukuran: Riwayat koreksi data pengukuran beserta alasan dan pelaku.
type KoreksiPengukuran struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	PengukuranID uuid.UUID `gorm:"column:pengukuran_id;type:uuid;not null;index" json:"pengukuran_id"`
	DikoreksiOleh uint `gorm:"column:dikoreksi_oleh;not null;index" json:"dikoreksi_oleh"`
	Alasan string `gorm:"column:alasan;type:text" json:"alasan"`
	NilaiSebelum json.RawMessage `gorm:"column:nilai_sebelum;type:jsonb" json:"nilai_sebelum"`
	NilaiSesudah json.RawMessage `gorm:"column:nilai_sesudah;type:jsonb" json:"nilai_sesudah"`
	WaktuKoreksi time.Time `gorm:"column:waktu_koreksi;autoCreateTime" json:"waktu_koreksi"`
	Pengukuran *Pengukuran `gorm:"foreignKey:PengukuranID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DikoreksiOlehUser *User `gorm:"foreignKey:DikoreksiOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (KoreksiPengukuran) TableName() string { return "koreksi_pengukuran" }

func (m *KoreksiPengukuran) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
