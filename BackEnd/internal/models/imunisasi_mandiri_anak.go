package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// VaksinMandiriAnak: vaksin di luar jadwal imunisasi program (mis. Rotavirus, PCV,
// Influenza, Varisela, Hepatitis A) yang pernah diterima anak di RS, puskesmas,
// klinik, atau bidan praktik. Dicatat bidan saat kunjungan pertama anak.
// Hanya catatan riwayat: tidak memengaruhi jadwal imunisasi program.
type VaksinMandiriAnak struct {
	ID     uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	Anak   *Anak     `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`

	// NamaVaksin: nama vaksin sesuai keterangan / Buku KIA, mis. "Rotavirus".
	NamaVaksin string `gorm:"column:nama_vaksin;size:100;not null" json:"nama_vaksin"`
	DosisKe    int16  `gorm:"column:dosis_ke;not null;default:1" json:"dosis_ke"`

	TanggalPemberian time.Time `gorm:"column:tanggal_pemberian;type:date;not null" json:"tanggal_pemberian"`
	Tempat           string    `gorm:"column:tempat;size:100;not null" json:"tempat"`
	FotoBukti        string    `gorm:"column:foto_bukti;size:120" json:"foto_bukti"` // opsional

	// DicatatOleh: bidan yang mencatat.
	DicatatOleh     uint  `gorm:"column:dicatat_oleh;not null" json:"dicatat_oleh"`
	DicatatOlehUser *User `gorm:"foreignKey:DicatatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`

	Version       int            `gorm:"column:version;default:1" json:"version"`
	PerangkatAsal *uuid.UUID     `gorm:"column:perangkat_asal;type:uuid" json:"perangkat_asal,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `gorm:"index" json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (VaksinMandiriAnak) TableName() string { return "vaksin_mandiri_anak" }

func (m *VaksinMandiriAnak) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}