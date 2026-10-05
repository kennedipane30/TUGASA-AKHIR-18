package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Anak: data identitas balita.
type Anak struct {
	ID             uuid.UUID      `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	KeluargaID     uuid.UUID      `gorm:"column:keluarga_id;type:uuid;not null;index" json:"keluarga_id"`
	Keluarga       *Keluarga      `gorm:"foreignKey:KeluargaID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	NIK            *string        `gorm:"column:nik;size:16;uniqueIndex:ux_anak_nik,where:deleted_at IS NULL" json:"nik,omitempty"`
	Nama           string         `gorm:"column:nama;size:100;not null" json:"nama"`
	TanggalLahir   time.Time      `gorm:"column:tanggal_lahir;type:date;not null" json:"tanggal_lahir"`
	JenisKelamin   string         `gorm:"column:jenis_kelamin;size:1;not null" json:"jenis_kelamin"` // L | P
	BeratLahirKg   *float64       `gorm:"column:berat_lahir_kg;type:numeric(4,2)" json:"berat_lahir_kg"`
	PanjangLahirCm *float64       `gorm:"column:panjang_lahir_cm;type:numeric(4,1)" json:"panjang_lahir_cm"`
	KodeQR         string         `gorm:"column:kode_qr;size:64;not null;uniqueIndex:ux_anak_kode_qr" json:"kode_qr"`
	Status         string         `gorm:"column:status;size:10;default:aktif" json:"status"` // aktif | arsip
	TanggalArsip   *time.Time     `gorm:"column:tanggal_arsip;type:date" json:"tanggal_arsip,omitempty"`
	AlasanArsip    string         `gorm:"column:alasan_arsip;size:100" json:"alasan_arsip,omitempty"`
	DigabungKeID   *uuid.UUID     `gorm:"column:digabung_ke_id;type:uuid" json:"digabung_ke_id,omitempty"`
	Version        int            `gorm:"column:version;default:1" json:"version"`
	PerangkatAsal  *uuid.UUID     `gorm:"column:perangkat_asal;type:uuid" json:"perangkat_asal,omitempty"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Anak) TableName() string { return "anak" }

func (a *Anak) BeforeCreate(*gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	if a.KodeQR == "" {
		a.KodeQR = "PSY-" + a.ID.String()
	}
	return nil
}
