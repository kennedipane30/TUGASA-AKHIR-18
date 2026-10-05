package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KontenEdukasi: Konten Buku KIA digital, materi edukasi, dan panduan aplikasi.
type KontenEdukasi struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Jenis string `gorm:"column:jenis;size:20" json:"jenis"`
	Kategori string `gorm:"column:kategori;size:20" json:"kategori"`
	Judul string `gorm:"column:judul;size:150;not null" json:"judul"`
	Isi string `gorm:"column:isi;type:text" json:"isi"`
	LampiranURL string `gorm:"column:lampiran_url;size:255" json:"lampiran_url"`
	Urutan *int16 `gorm:"column:urutan" json:"urutan"`
	TersediaOffline bool `gorm:"column:tersedia_offline" json:"tersedia_offline"`
	Dipublikasikan bool `gorm:"column:dipublikasikan" json:"dipublikasikan"`
	DibuatOleh uint `gorm:"column:dibuat_oleh;not null;index" json:"dibuat_oleh"`
	DibuatOlehUser *User `gorm:"foreignKey:DibuatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (KontenEdukasi) TableName() string { return "konten_edukasi" }

func (m *KontenEdukasi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
