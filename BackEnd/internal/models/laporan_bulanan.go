package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// LaporanBulanan: Rekap bulanan SKDN, cakupan imunisasi, dan jumlah anak berisiko.
type LaporanBulanan struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Bulan int16 `gorm:"column:bulan;not null;uniqueIndex:ux_laporan_bulanan_komposit" json:"bulan"`
	Tahun int16 `gorm:"column:tahun;not null;uniqueIndex:ux_laporan_bulanan_komposit" json:"tahun"`
	SSasaran int `gorm:"column:s_sasaran" json:"s_sasaran"`
	KPunyaKms int `gorm:"column:k_punya_kms" json:"k_punya_kms"`
	DDitimbang int `gorm:"column:d_ditimbang" json:"d_ditimbang"`
	NNaikBb int `gorm:"column:n_naik_bb" json:"n_naik_bb"`
	JumlahHadir int `gorm:"column:jumlah_hadir" json:"jumlah_hadir"`
	JumlahStunting int `gorm:"column:jumlah_stunting" json:"jumlah_stunting"`
	JumlahGiziKurang int `gorm:"column:jumlah_gizi_kurang" json:"jumlah_gizi_kurang"`
	CakupanImunisasi *float64 `gorm:"column:cakupan_imunisasi;type:numeric(5,2)" json:"cakupan_imunisasi"`
	CakupanVitaminA *float64 `gorm:"column:cakupan_vitamin_a;type:numeric(5,2)" json:"cakupan_vitamin_a"`
	Status string `gorm:"column:status;size:10;default:draft" json:"status"`
	FileURL string `gorm:"column:file_url;size:255" json:"file_url"`
	DibuatOleh uint `gorm:"column:dibuat_oleh;not null;index" json:"dibuat_oleh"`
	DibuatPada *time.Time `gorm:"column:dibuat_pada" json:"dibuat_pada"`
	DibuatOlehUser *User `gorm:"foreignKey:DibuatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (LaporanBulanan) TableName() string { return "laporan_bulanan" }

func (m *LaporanBulanan) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
