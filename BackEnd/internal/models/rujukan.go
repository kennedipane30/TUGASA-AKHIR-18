package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Status rujukan.
const (
	StatusRujukanDirujuk    = "dirujuk"    // surat dibuat, anak dirujuk ke faskes
	StatusRujukanSelesai    = "selesai"    // rujukan balik (hasil dari faskes) sudah dicatat bidan
	StatusRujukanDibatalkan = "dibatalkan" // dibatalkan bidan beserta alasannya
)

// Rujukan: surat rujukan balita dari bidan posyandu ke fasilitas kesehatan
// (Puskesmas/RS), seperti format rujukan rumah sakit.
//
// Data anak, orang tua, dan pemeriksaan terakhir disimpan sebagai salinan
// (DataAnak, JSON) saat rujukan dibuat, sehingga isi surat tidak berubah
// walaupun data anak diperbarui kemudian.
type Rujukan struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// Nomor: nomor surat rujukan, mis. "RJK/SIL/2026/11/001".
	Nomor string `gorm:"column:nomor;size:40;not null;uniqueIndex:ux_rujukan_nomor" json:"nomor"`

	// Posyandu: kode posyandu perujuk.
	Posyandu string `gorm:"column:posyandu;size:20;not null;index" json:"posyandu"`

	// AnakID: balita yang dirujuk (FK ke anak).
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	Anak   *Anak     `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`

	// BidanID: bidan perujuk (FK ke users) dan namanya saat surat dibuat.
	BidanID   uint   `gorm:"column:bidan_id;not null;index" json:"bidan_id"`
	Bidan     *User  `gorm:"foreignKey:BidanID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	BidanNama string `gorm:"column:bidan_nama;size:100" json:"bidan_nama"`

	// Tanggal: tanggal surat rujukan.
	Tanggal time.Time `gorm:"column:tanggal;type:date;not null;index" json:"tanggal"`

	// NamaAnak: nama anak saat dirujuk (untuk daftar & pencarian).
	NamaAnak string `gorm:"column:nama_anak;size:100" json:"nama_anak"`

	// DataAnak: salinan identitas anak, orang tua, dan pemeriksaan terakhir (JSON).
	DataAnak string `gorm:"column:data_anak;type:text" json:"-"`

	// Isian bidan.
	Keluhan   string `gorm:"column:keluhan;type:text;not null" json:"keluhan"`
	Diagnosis string `gorm:"column:diagnosis;type:text;not null" json:"diagnosis"`
	Tindakan  string `gorm:"column:tindakan;type:text" json:"tindakan"`
	Tujuan    string `gorm:"column:tujuan;type:text;not null" json:"tujuan"`

	// Status: dirujuk | selesai | dibatalkan.
	Status string `gorm:"column:status;size:15;not null;default:'dirujuk';index" json:"status"`

	// Rujukan balik: hasil pemeriksaan dari faskes tujuan, dicatat bidan.
	TanggalDiperiksa *time.Time `gorm:"column:tanggal_diperiksa;type:date" json:"tanggal_diperiksa"`
	HasilDiagnosis   string     `gorm:"column:hasil_diagnosis;type:text" json:"hasil_diagnosis"`
	TerapiSaran      string     `gorm:"column:terapi_saran;type:text" json:"terapi_saran"`
	TindakLanjut     string     `gorm:"column:tindak_lanjut;type:text" json:"tindak_lanjut"`
	BalikDicatatPada *time.Time `gorm:"column:balik_dicatat_pada" json:"balik_dicatat_pada"`

	// Pembatalan.
	AlasanBatal    string     `gorm:"column:alasan_batal;type:text" json:"alasan_batal"`
	DibatalkanPada *time.Time `gorm:"column:dibatalkan_pada" json:"dibatalkan_pada"`

	Version   int            `gorm:"column:version;default:1" json:"version"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Rujukan) TableName() string { return "rujukan" }

func (m *Rujukan) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}