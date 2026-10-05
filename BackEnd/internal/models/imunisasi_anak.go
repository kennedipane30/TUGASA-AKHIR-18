package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ImunisasiAnak: Riwayat vaksin yang sudah diberikan kepada anak.
type ImunisasiAnak struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	JenisVaksinID uuid.UUID `gorm:"column:jenis_vaksin_id;type:uuid;not null;index" json:"jenis_vaksin_id"`
	DosisKe int16 `gorm:"column:dosis_ke;not null" json:"dosis_ke"`
	TanggalPemberian time.Time `gorm:"column:tanggal_pemberian;type:date;not null" json:"tanggal_pemberian"`
	KondisiAnak string `gorm:"column:kondisi_anak;type:text" json:"kondisi_anak"`
	PendaftaranID *uuid.UUID `gorm:"column:pendaftaran_id;type:uuid;index" json:"pendaftaran_id"`
	DiberikanOleh uint `gorm:"column:diberikan_oleh;not null;index" json:"diberikan_oleh"`
	Catatan string `gorm:"column:catatan;type:text" json:"catatan"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	JenisVaksin *JenisVaksin `gorm:"foreignKey:JenisVaksinID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Pendaftaran *Pendaftaran `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DiberikanOlehUser *User `gorm:"foreignKey:DiberikanOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ImunisasiAnak) TableName() string { return "imunisasi_anak" }

func (m *ImunisasiAnak) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
