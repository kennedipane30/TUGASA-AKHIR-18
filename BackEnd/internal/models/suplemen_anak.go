package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SuplemenAnak adalah riwayat pemberian suplemen kepada anak
// (Vitamin A, obat cacing, PMT, zinc, dll.) yang diinput manual oleh bidan
// pada form Catatan Bidan saat sesi posyandu.
//
// Tabel : suplemen_anak
//
// Contoh satu baris:
//
//	Jenis = "Vitamin A (kapsul merah)", Dosis = "200.000 IU",
//	Jumlah = 1, Satuan = "kapsul",
//	KeteranganDosis = "200.000 IU · 1 kapsul".
//
// Data lama (sebelum input manual) berisi Jenis berupa kode
// "vitamin_a" / "obat_cacing" / "pmt" dengan Jumlah = 0; aplikasi
// menampilkannya sebagai nama yang mudah dibaca.
type SuplemenAnak struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// AnakID: anak penerima suplemen (FK ke anak).
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`

	// Jenis: nama suplemen, mis. "Obat Cacing (Albendazol)".
	Jenis string `gorm:"column:jenis;size:100" json:"jenis"`

	// Dosis: kekuatan dosis, mis. "200.000 IU", "400 mg".
	Dosis string `gorm:"column:dosis;size:60" json:"dosis"`

	// Jumlah: banyaknya yang diberikan (1-999).
	Jumlah int16 `gorm:"column:jumlah" json:"jumlah"`

	// Satuan: satuan jumlah, mis. kapsul, tablet, sachet, porsi.
	Satuan string `gorm:"column:satuan;size:30" json:"satuan"`

	// Tanggal: tanggal suplemen diberikan.
	Tanggal time.Time `gorm:"column:tanggal;type:date;not null" json:"tanggal"`

	// KeteranganDosis: ringkasan otomatis "dosis · jumlah satuan" untuk tampilan.
	KeteranganDosis string `gorm:"column:keterangan_dosis;size:120" json:"keterangan_dosis"`

	// PendaftaranID: kunjungan posyandu saat suplemen diberikan.
	PendaftaranID *uuid.UUID `gorm:"column:pendaftaran_id;type:uuid;index" json:"pendaftaran_id"`

	// DiberikanOleh: user bidan yang mencatat (FK ke users).
	DiberikanOleh uint `gorm:"column:diberikan_oleh;not null;index" json:"diberikan_oleh"`

	// Catatan: catatan tambahan (opsional).
	Catatan string `gorm:"column:catatan;type:text" json:"catatan"`

	// Relasi
	Anak              *Anak        `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Pendaftaran       *Pendaftaran `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DiberikanOlehUser *User        `gorm:"foreignKey:DiberikanOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`

	// Sinkronisasi offline-first
	Version       int        `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (SuplemenAnak) TableName() string { return "suplemen_anak" }

func (m *SuplemenAnak) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}