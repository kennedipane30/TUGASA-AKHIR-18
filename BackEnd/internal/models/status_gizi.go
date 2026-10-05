package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// StatusGizi: Hasil perhitungan dan penetapan status gizi per pengukuran.
type StatusGizi struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	PengukuranID uuid.UUID `gorm:"column:pengukuran_id;type:uuid;not null;uniqueIndex:ux_status_gizi_pengukuran_id,where:deleted_at IS NULL" json:"pengukuran_id"`
	ZscoreBbU *float64 `gorm:"column:zscore_bb_u;type:numeric(5,2)" json:"zscore_bb_u"`
	ZscoreTbU *float64 `gorm:"column:zscore_tb_u;type:numeric(5,2)" json:"zscore_tb_u"`
	ZscoreBbTb *float64 `gorm:"column:zscore_bb_tb;type:numeric(5,2)" json:"zscore_bb_tb"`
	KategoriBbU string `gorm:"column:kategori_bb_u;size:30" json:"kategori_bb_u"`
	KategoriTbU string `gorm:"column:kategori_tb_u;size:30" json:"kategori_tb_u"`
	KategoriBbTb string `gorm:"column:kategori_bb_tb;size:30" json:"kategori_bb_tb"`
	Warna string `gorm:"column:warna;size:10" json:"warna"`
	TrenBb string `gorm:"column:tren_bb;size:15" json:"tren_bb"`
	StatusOtomatis string `gorm:"column:status_otomatis;size:30" json:"status_otomatis"`
	StatusAkhir string `gorm:"column:status_akhir;size:30" json:"status_akhir"`
	DitetapkanOleh *uint `gorm:"column:ditetapkan_oleh;index" json:"ditetapkan_oleh"`
	DitetapkanPada *time.Time `gorm:"column:ditetapkan_pada" json:"ditetapkan_pada"`
	Penjelasan string `gorm:"column:penjelasan;type:text" json:"penjelasan"`
	Pengukuran *Pengukuran `gorm:"foreignKey:PengukuranID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	DitetapkanOlehUser *User `gorm:"foreignKey:DitetapkanOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (StatusGizi) TableName() string { return "status_gizi" }

func (m *StatusGizi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
