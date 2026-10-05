package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Pendaftaran: Pendaftaran, check-in, dan kehadiran anak pada satu jadwal.
type Pendaftaran struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	JadwalID uuid.UUID `gorm:"column:jadwal_id;type:uuid;not null;uniqueIndex:ux_pendaftaran_komposit,where:deleted_at IS NULL" json:"jadwal_id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;uniqueIndex:ux_pendaftaran_komposit,where:deleted_at IS NULL" json:"anak_id"`
	StatusKehadiran string `gorm:"column:status_kehadiran;size:20;default:terdaftar" json:"status_kehadiran"`
	Sumber string `gorm:"column:sumber;size:10;default:mandiri" json:"sumber"`
	NomorAntrean *int16 `gorm:"column:nomor_antrean" json:"nomor_antrean"`
	WaktuDaftar time.Time `gorm:"column:waktu_daftar;autoCreateTime" json:"waktu_daftar"`
	WaktuCheckin *time.Time `gorm:"column:waktu_checkin" json:"waktu_checkin"`
	MetodeCheckin string `gorm:"column:metode_checkin;size:10" json:"metode_checkin"`
	DiverifikasiOleh *uint `gorm:"column:diverifikasi_oleh;index" json:"diverifikasi_oleh"`
	WaktuBatal *time.Time `gorm:"column:waktu_batal" json:"waktu_batal"`
	Jadwal *JadwalPosyandu `gorm:"foreignKey:JadwalID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DiverifikasiOlehUser *User `gorm:"foreignKey:DiverifikasiOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Pendaftaran) TableName() string { return "pendaftaran" }

func (m *Pendaftaran) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
