package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Rujukan: Surat rujukan ke puskesmas dan status tindak lanjutnya.
type Rujukan struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	PeringatanID *uuid.UUID `gorm:"column:peringatan_id;type:uuid;index" json:"peringatan_id"`
	BidanID uint `gorm:"column:bidan_id;not null;index" json:"bidan_id"`
	FaskesTujuan string `gorm:"column:faskes_tujuan;size:150" json:"faskes_tujuan"`
	Alasan string `gorm:"column:alasan;type:text" json:"alasan"`
	TanggalRujukan time.Time `gorm:"column:tanggal_rujukan;type:date;not null" json:"tanggal_rujukan"`
	StatusTindakLanjut string `gorm:"column:status_tindak_lanjut;size:15;default:dibuat" json:"status_tindak_lanjut"`
	CatatanTindakLanjut string `gorm:"column:catatan_tindak_lanjut;type:text" json:"catatan_tindak_lanjut"`
	TanggalSelesai *time.Time `gorm:"column:tanggal_selesai;type:date" json:"tanggal_selesai"`
	Anak *Anak `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Peringatan *PeringatanRisiko `gorm:"foreignKey:PeringatanID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Bidan *User `gorm:"foreignKey:BidanID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Rujukan) TableName() string { return "rujukan" }

func (m *Rujukan) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
