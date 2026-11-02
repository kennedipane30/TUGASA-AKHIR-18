package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Tingkat ringkas status gizi untuk pewarnaan tampilan.
const (
	TingkatBaik    = "baik"
	TingkatWaspada = "waspada"
	TingkatRisiko  = "risiko"
)

// StatusGizi: hasil perhitungan z-score satu pengukuran terhadap standar WHO (Permenkes 2/2020).
// Satu pengukuran memiliki tepat satu status gizi; dihitung ulang setiap kader mengubah pengukuran.
// Nilai z bernilai null bila indeks tidak dapat dihitung (di luar rentang umur/tinggi standar
// atau data tidak diinput).
type StatusGizi struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	PengukuranID uuid.UUID `gorm:"column:pengukuran_id;type:uuid;not null;uniqueIndex:ux_status_gizi_pengukuran,where:deleted_at IS NULL" json:"pengukuran_id"`
	AnakID       uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	TanggalUkur  time.Time `gorm:"column:tanggal_ukur;type:date;not null" json:"tanggal_ukur"`
	UsiaBulan    int16     `gorm:"column:usia_bulan" json:"usia_bulan"`
	JenisKelamin string    `gorm:"column:jenis_kelamin;size:1" json:"jenis_kelamin"`
	CaraUkur     string    `gorm:"column:cara_ukur;size:10" json:"cara_ukur"`

	// Panjang/tinggi setelah koreksi 0,7 cm (dipakai untuk PB/U, TB/U, BB/PB, BB/TB, IMT/U).
	TbKoreksiCm float64  `gorm:"column:tb_koreksi_cm;type:numeric(5,1)" json:"tb_koreksi_cm"`
	Imt         *float64 `gorm:"column:imt;type:numeric(5,2)" json:"imt"`

	ZBbu         *float64 `gorm:"column:z_bbu;type:numeric(5,2)" json:"z_bbu"`
	KategoriBbu  string   `gorm:"column:kategori_bbu;size:40" json:"kategori_bbu"`
	ZTbu         *float64 `gorm:"column:z_tbu;type:numeric(5,2)" json:"z_tbu"` // PB/U (< 24 bln) atau TB/U (>= 24 bln)
	KategoriTbu  string   `gorm:"column:kategori_tbu;size:40" json:"kategori_tbu"`
	IndeksTbu    string   `gorm:"column:indeks_tbu;size:10" json:"indeks_tbu"`
	ZBbtb        *float64 `gorm:"column:z_bbtb;type:numeric(5,2)" json:"z_bbtb"` // BB/PB (< 24 bln) atau BB/TB (>= 24 bln)
	KategoriBbtb string   `gorm:"column:kategori_bbtb;size:40" json:"kategori_bbtb"`
	IndeksBbtb   string   `gorm:"column:indeks_bbtb;size:10" json:"indeks_bbtb"`
	ZImtu        *float64 `gorm:"column:z_imtu;type:numeric(5,2)" json:"z_imtu"`
	KategoriImtu string   `gorm:"column:kategori_imtu;size:40" json:"kategori_imtu"`
	ZLku         *float64 `gorm:"column:z_lku;type:numeric(5,2)" json:"z_lku"`
	KategoriLku  string   `gorm:"column:kategori_lku;size:40" json:"kategori_lku"`
	ZLila        *float64 `gorm:"column:z_lila;type:numeric(5,2)" json:"z_lila"`
	KategoriLila string   `gorm:"column:kategori_lila;size:40" json:"kategori_lila"`

	Stunting      bool   `gorm:"column:stunting;index" json:"stunting"`       // PB/U atau TB/U < -2 SD
	Wasting       bool   `gorm:"column:wasting;index" json:"wasting"`         // BB/PB atau BB/TB < -2 SD
	Underweight   bool   `gorm:"column:underweight;index" json:"underweight"` // BB/U < -2 SD
	Overweight    bool   `gorm:"column:overweight;index" json:"overweight"`   // BB/PB atau BB/TB > +2 SD
	Tingkat       string `gorm:"column:tingkat;size:10;index" json:"tingkat"` // baik | waspada | risiko
	PerluCekUlang bool   `gorm:"column:perlu_cek_ulang" json:"perlu_cek_ulang"`
	Catatan       string `gorm:"column:catatan;type:text" json:"catatan"`
	Standar       string `gorm:"column:standar;size:60" json:"standar"`

	Pengukuran    *Pengukuran    `gorm:"foreignKey:PengukuranID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Anak          *Anak          `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version       int            `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID     `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (StatusGizi) TableName() string { return "status_gizi" }

func (m *StatusGizi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}