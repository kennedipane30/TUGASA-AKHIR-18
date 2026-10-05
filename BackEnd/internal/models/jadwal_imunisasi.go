package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// JadwalImunisasi: Master jadwal imunisasi: usia pemberian tiap dosis.
type JadwalImunisasi struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	JenisVaksinID uuid.UUID `gorm:"column:jenis_vaksin_id;type:uuid;not null;uniqueIndex:ux_jadwal_imunisasi_komposit" json:"jenis_vaksin_id"`
	DosisKe int16 `gorm:"column:dosis_ke;not null;uniqueIndex:ux_jadwal_imunisasi_komposit" json:"dosis_ke"`
	UsiaMinBulan int16 `gorm:"column:usia_min_bulan" json:"usia_min_bulan"`
	UsiaIdealBulan int16 `gorm:"column:usia_ideal_bulan" json:"usia_ideal_bulan"`
	UsiaMaksBulan *int16 `gorm:"column:usia_maks_bulan" json:"usia_maks_bulan"`
	JarakMinimalHari *int16 `gorm:"column:jarak_minimal_hari" json:"jarak_minimal_hari"`
	JenisVaksin *JenisVaksin `gorm:"foreignKey:JenisVaksinID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (JadwalImunisasi) TableName() string { return "jadwal_imunisasi" }

func (m *JadwalImunisasi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
