package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Kode indeks standar antropometri (WHO Child Growth Standards, Permenkes 2/2020).
const (
	IndeksBBU    = "bbu"     // berat badan menurut umur, 0-60 bulan
	IndeksPBU    = "pbu"     // panjang badan menurut umur, 0-24 bulan (diukur berbaring)
	IndeksTBU    = "tbu"     // tinggi badan menurut umur, 24-60 bulan (diukur berdiri)
	IndeksBBPB   = "bbpb"    // berat badan menurut panjang badan, 45-110 cm
	IndeksBBTB   = "bbtb"    // berat badan menurut tinggi badan, 65-120 cm
	IndeksIMTUPB = "imtu_pb" // IMT menurut umur berbasis panjang badan, 0-24 bulan
	IndeksIMTUTB = "imtu_tb" // IMT menurut umur berbasis tinggi badan, 24-60 bulan
	IndeksLKU    = "lku"     // lingkar kepala menurut umur, 0-60 bulan
	IndeksLILAU  = "lilau"   // lingkar lengan atas menurut umur, 3-60 bulan
)

// StandarAntropometri: satu baris tabel rujukan WHO dalam bentuk LMS untuk menghitung status gizi.
// Acuan berisi umur (bulan) atau panjang/tinggi badan (cm) sesuai SatuanAcuan.
// Isi tabel ini dengan: go run ./cmd/import-standar
type StandarAntropometri struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Indeks       string    `gorm:"column:indeks;size:10;not null;uniqueIndex:ux_standar_antropometri_komposit" json:"indeks"`
	JenisKelamin string    `gorm:"column:jenis_kelamin;size:1;not null;uniqueIndex:ux_standar_antropometri_komposit" json:"jenis_kelamin"`
	Acuan        float64   `gorm:"column:acuan;type:numeric(5,1);not null;uniqueIndex:ux_standar_antropometri_komposit" json:"acuan"`
	SatuanAcuan  string    `gorm:"column:satuan_acuan;size:5;not null" json:"satuan_acuan"`
	L            float64   `gorm:"column:l;type:numeric(8,4);not null" json:"l"`
	M            float64   `gorm:"column:m;type:numeric(9,4);not null" json:"m"`
	S            float64   `gorm:"column:s;type:numeric(7,5);not null" json:"s"`
	SdMin3       float64   `gorm:"column:sd_min3;type:numeric(8,3)" json:"sd_min3"`
	SdMin2       float64   `gorm:"column:sd_min2;type:numeric(8,3)" json:"sd_min2"`
	SdMin1       float64   `gorm:"column:sd_min1;type:numeric(8,3)" json:"sd_min1"`
	Median       float64   `gorm:"column:median;type:numeric(8,3)" json:"median"`
	SdPlus1      float64   `gorm:"column:sd_plus1;type:numeric(8,3)" json:"sd_plus1"`
	SdPlus2      float64   `gorm:"column:sd_plus2;type:numeric(8,3)" json:"sd_plus2"`
	SdPlus3      float64   `gorm:"column:sd_plus3;type:numeric(8,3)" json:"sd_plus3"`
	Sumber       string    `gorm:"column:sumber;size:120" json:"sumber"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (StandarAntropometri) TableName() string { return "standar_antropometri" }

func (m *StandarAntropometri) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}