package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Pengukuran: Hasil pengukuran antropometri anak pada satu kehadiran.
type Pengukuran struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	PendaftaranID uuid.UUID `gorm:"column:pendaftaran_id;type:uuid;not null;uniqueIndex:ux_pengukuran_pendaftaran_id,where:deleted_at IS NULL" json:"pendaftaran_id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	TanggalUkur time.Time `gorm:"column:tanggal_ukur;type:date;not null" json:"tanggal_ukur"`
	UsiaBulan int16 `gorm:"column:usia_bulan" json:"usia_bulan"`
	BbKg float64 `gorm:"column:bb_kg;type:numeric(5,2);not null" json:"bb_kg"`
	TbCm float64 `gorm:"column:tb_cm;type:numeric(5,1);not null" json:"tb_cm"`
	CaraUkur string `gorm:"column:cara_ukur;size:10" json:"cara_ukur"`
	LingkarKepalaCm *float64 `gorm:"column:lingkar_kepala_cm;type:numeric(4,1)" json:"lingkar_kepala_cm"`
	LilaCm *float64 `gorm:"column:lila_cm;type:numeric(4,1)" json:"lila_cm"`
	Keluhan string `gorm:"column:keluhan;type:text" json:"keluhan"`
	SedangSakit bool `gorm:"column:sedang_sakit" json:"sedang_sakit"`
	AsiEksklusif bool `gorm:"column:asi_eksklusif" json:"asi_eksklusif"`
	Catatan string `gorm:"column:catatan;type:text" json:"catatan"`
	PeringatanValidasi string `gorm:"column:peringatan_validasi;type:text" json:"peringatan_validasi"`
	StatusData string `gorm:"column:status_data;size:20;default:draft" json:"status_data"`
	Terkunci bool `gorm:"column:terkunci" json:"terkunci"`
	DicatatOleh uint `gorm:"column:dicatat_oleh;not null;index" json:"dicatat_oleh"`
	DiverifikasiOleh *uint `gorm:"column:diverifikasi_oleh;index" json:"diverifikasi_oleh"`
	DiverifikasiPada *time.Time `gorm:"column:diverifikasi_pada" json:"diverifikasi_pada"`
	Pendaftaran *Pendaftaran `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DicatatOlehUser *User `gorm:"foreignKey:DicatatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DiverifikasiOlehUser *User `gorm:"foreignKey:DiverifikasiOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Pengukuran) TableName() string { return "pengukuran" }

func (m *Pengukuran) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
