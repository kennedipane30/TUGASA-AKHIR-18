package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PengaturanSistem: Pengaturan sistem: masa simpan sesi, kebijakan kata sandi, aturan waktu bawaan.
type PengaturanSistem struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Kunci string `gorm:"column:kunci;size:80;not null;uniqueIndex:ux_pengaturan_sistem_kunci" json:"kunci"`
	Nilai string `gorm:"column:nilai;type:text" json:"nilai"`
	Deskripsi string `gorm:"column:deskripsi;size:200" json:"deskripsi"`
	DiubahOleh *uint `gorm:"column:diubah_oleh;index" json:"diubah_oleh"`
	DiubahPada time.Time `gorm:"column:diubah_pada" json:"diubah_pada"`
	DiubahOlehUser *User `gorm:"foreignKey:DiubahOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (PengaturanSistem) TableName() string { return "pengaturan_sistem" }

func (m *PengaturanSistem) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
