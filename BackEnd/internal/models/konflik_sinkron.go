package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KonflikSinkron: Catatan konflik data antar perangkat dan cara penyelesaiannya.
type KonflikSinkron struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	PerangkatID uuid.UUID `gorm:"column:perangkat_id;type:uuid;not null;index" json:"perangkat_id"`
	NamaTabel string `gorm:"column:nama_tabel;size:50" json:"nama_tabel"`
	IDData *uuid.UUID `gorm:"column:id_data;type:uuid" json:"id_data"`
	NilaiServer json.RawMessage `gorm:"column:nilai_server;type:jsonb" json:"nilai_server"`
	NilaiPerangkat json.RawMessage `gorm:"column:nilai_perangkat;type:jsonb" json:"nilai_perangkat"`
	AturanDiterapkan string `gorm:"column:aturan_diterapkan;size:50" json:"aturan_diterapkan"`
	Status string `gorm:"column:status;size:20;default:selesai_otomatis" json:"status"`
	DiselesaikanOleh *uint `gorm:"column:diselesaikan_oleh;index" json:"diselesaikan_oleh"`
	WaktuTerjadi time.Time `gorm:"column:waktu_terjadi;autoCreateTime" json:"waktu_terjadi"`
	WaktuSelesai *time.Time `gorm:"column:waktu_selesai" json:"waktu_selesai"`
	Perangkat *Perangkat `gorm:"foreignKey:PerangkatID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DiselesaikanOlehUser *User `gorm:"foreignKey:DiselesaikanOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (KonflikSinkron) TableName() string { return "konflik_sinkron" }

func (m *KonflikSinkron) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
