package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PemeriksaanBidan: Pemeriksaan singkat, evaluasi, dan saran dari bidan.
type PemeriksaanBidan struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	PendaftaranID uuid.UUID `gorm:"column:pendaftaran_id;type:uuid;not null;uniqueIndex:ux_pemeriksaan_bidan_pendaftaran_id,where:deleted_at IS NULL" json:"pendaftaran_id"`
	PengukuranID *uuid.UUID `gorm:"column:pengukuran_id;type:uuid;index" json:"pengukuran_id"`
	BidanID uint `gorm:"column:bidan_id;not null;index" json:"bidan_id"`
	Demam bool `gorm:"column:demam" json:"demam"`
	Diare bool `gorm:"column:diare" json:"diare"`
	Batuk bool `gorm:"column:batuk" json:"batuk"`
	PenyakitPenyerta string `gorm:"column:penyakit_penyerta;type:text" json:"penyakit_penyerta"`
	Keluhan string `gorm:"column:keluhan;type:text" json:"keluhan"`
	CatatanEvaluasi string `gorm:"column:catatan_evaluasi;type:text" json:"catatan_evaluasi"`
	SaranGizi string `gorm:"column:saran_gizi;type:text" json:"saran_gizi"`
	SaranPolaAsuh string `gorm:"column:saran_pola_asuh;type:text" json:"saran_pola_asuh"`
	TanggalKunjunganUlang *time.Time `gorm:"column:tanggal_kunjungan_ulang;type:date" json:"tanggal_kunjungan_ulang"`
	TampilKeOrangTua bool `gorm:"column:tampil_ke_orang_tua;default:true" json:"tampil_ke_orang_tua"`
	Pendaftaran *Pendaftaran `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Pengukuran *Pengukuran `gorm:"foreignKey:PengukuranID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Bidan *User `gorm:"foreignKey:BidanID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (PemeriksaanBidan) TableName() string { return "pemeriksaan_bidan" }

func (m *PemeriksaanBidan) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
