package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// JadwalPosyandu: Jadwal pelaksanaan posyandu beserta aturan waktu pendaftaran dan check-in.
type JadwalPosyandu struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Tanggal time.Time `gorm:"column:tanggal;type:date;not null" json:"tanggal"`
	JamMulai   string  `gorm:"column:jam_mulai;type:time;not null" json:"jam_mulai"`
JamSelesai *string `gorm:"column:jam_selesai;type:time" json:"jam_selesai"`
	Lokasi string `gorm:"column:lokasi;size:150" json:"lokasi"`
	BukaDaftarHari int16 `gorm:"column:buka_daftar_hari;default:7" json:"buka_daftar_hari"`
	BukaCheckinMenit int16 `gorm:"column:buka_checkin_menit;default:60" json:"buka_checkin_menit"`
	Status string `gorm:"column:status;size:20;default:terjadwal" json:"status"`
	AlasanBatal string `gorm:"column:alasan_batal;type:text" json:"alasan_batal"`
	DibuatOleh uint `gorm:"column:dibuat_oleh;not null;index" json:"dibuat_oleh"`
	DibuatOlehUser *User `gorm:"foreignKey:DibuatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (JadwalPosyandu) TableName() string { return "jadwal_posyandu" }

func (m *JadwalPosyandu) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
