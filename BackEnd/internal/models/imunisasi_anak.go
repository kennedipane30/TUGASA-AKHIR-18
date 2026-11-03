package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ImunisasiAnak adalah riwayat vaksin yang sudah diberikan kepada seorang anak.
//
// Tabel : imunisasi_anak
// Diisi oleh bidan melalui dua cara:
//  1. Saat sesi posyandu (form Catatan Bidan):
//     PendaftaranID terisi, Tempat = "Posyandu".
//  2. Vaksin susulan dari luar posyandu (puskesmas, RS, bidan praktik):
//     PendaftaranID kosong, Tempat diisi bidan.
//
// Usia anak saat divaksin tidak disimpan, melainkan dihitung dari
// TanggalPemberian dikurangi tanggal lahir anak.
//
// Validasi saat pencatatan (service.VaksinService.ValidasiPemberian):
//   - dosis ada pada JadwalImunisasi,
//   - usia anak >= UsiaMinBulan dan <= UsiaMaksBulan,
//   - dosis sebelumnya sudah diberikan dan jarak minimal terpenuhi,
//   - dosis yang sama belum pernah diberikan.
type ImunisasiAnak struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// AnakID: anak penerima vaksin (FK ke anak).
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`

	// JenisVaksinID: vaksin yang diberikan (FK ke jenis_vaksin).
	JenisVaksinID uuid.UUID `gorm:"column:jenis_vaksin_id;type:uuid;not null;index" json:"jenis_vaksin_id"`

	// DosisKe: dosis ke berapa yang diberikan.
	DosisKe int16 `gorm:"column:dosis_ke;not null" json:"dosis_ke"`

	// TanggalPemberian: tanggal vaksin diberikan.
	TanggalPemberian time.Time `gorm:"column:tanggal_pemberian;type:date;not null" json:"tanggal_pemberian"`

	// Tempat: lokasi pemberian, mis. "Posyandu", "Puskesmas Balige".
	Tempat string `gorm:"column:tempat;size:100" json:"tempat"`

	// KondisiAnak: kondisi anak saat divaksin (opsional).
	KondisiAnak string `gorm:"column:kondisi_anak;type:text" json:"kondisi_anak"`

	// PendaftaranID: kunjungan posyandu saat vaksin diberikan; nil = vaksin susulan.
	PendaftaranID *uuid.UUID `gorm:"column:pendaftaran_id;type:uuid;index" json:"pendaftaran_id"`

	// DiberikanOleh: user bidan yang mencatat (FK ke users).
	DiberikanOleh uint `gorm:"column:diberikan_oleh;not null;index" json:"diberikan_oleh"`

	// Catatan: catatan tambahan (opsional).
	Catatan string `gorm:"column:catatan;type:text" json:"catatan"`

	// Relasi
	Anak              *Anak        `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	JenisVaksin       *JenisVaksin `gorm:"foreignKey:JenisVaksinID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"jenis_vaksin,omitempty"`
	Pendaftaran       *Pendaftaran `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DiberikanOlehUser *User        `gorm:"foreignKey:DiberikanOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`

	// Sinkronisasi offline-first
	Version       int        `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ImunisasiAnak) TableName() string { return "imunisasi_anak" }

func (m *ImunisasiAnak) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}