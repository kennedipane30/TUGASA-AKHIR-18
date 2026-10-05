package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// LogAktivitas: Log siapa mengubah apa dan kapan (jejak audit).
type LogAktivitas struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	UserID *uint `gorm:"column:user_id;index" json:"user_id"`
	PerangkatID *uuid.UUID `gorm:"column:perangkat_id;type:uuid;index" json:"perangkat_id"`
	Aksi string `gorm:"column:aksi;size:30;not null" json:"aksi"`
	NamaTabel string `gorm:"column:nama_tabel;size:50" json:"nama_tabel"`
	IDData *uuid.UUID `gorm:"column:id_data;type:uuid" json:"id_data"`
	NilaiSebelum json.RawMessage `gorm:"column:nilai_sebelum;type:jsonb" json:"nilai_sebelum"`
	NilaiSesudah json.RawMessage `gorm:"column:nilai_sesudah;type:jsonb" json:"nilai_sesudah"`
	Alasan string `gorm:"column:alasan;type:text" json:"alasan"`
	Waktu time.Time `gorm:"column:waktu;autoCreateTime" json:"waktu"`
	AlamatIP string `gorm:"column:alamat_ip;size:45" json:"alamat_ip"`
	User *User `gorm:"foreignKey:UserID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Perangkat *Perangkat `gorm:"foreignKey:PerangkatID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (LogAktivitas) TableName() string { return "log_aktivitas" }

func (m *LogAktivitas) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
