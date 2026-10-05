package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Notifikasi: Notifikasi dan pengingat per pengguna beserta status baca.
type Notifikasi struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	UserID uint `gorm:"column:user_id;not null;index" json:"user_id"`
	Jenis string `gorm:"column:jenis;size:40" json:"jenis"`
	Judul string `gorm:"column:judul;size:150;not null" json:"judul"`
	Isi string `gorm:"column:isi;type:text" json:"isi"`
	PengumumanID *uuid.UUID `gorm:"column:pengumuman_id;type:uuid;index" json:"pengumuman_id"`
	ObjekTabel string `gorm:"column:objek_tabel;size:40" json:"objek_tabel"`
	ObjekID *uuid.UUID `gorm:"column:objek_id;type:uuid" json:"objek_id"`
	DikirimOleh *uint `gorm:"column:dikirim_oleh;index" json:"dikirim_oleh"`
	DikirimPada *time.Time `gorm:"column:dikirim_pada" json:"dikirim_pada"`
	SudahDibaca bool `gorm:"column:sudah_dibaca" json:"sudah_dibaca"`
	DibacaPada *time.Time `gorm:"column:dibaca_pada" json:"dibaca_pada"`
	User *User `gorm:"foreignKey:UserID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Pengumuman *Pengumuman `gorm:"foreignKey:PengumumanID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DikirimOlehUser *User `gorm:"foreignKey:DikirimOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Version int `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Notifikasi) TableName() string { return "notifikasi" }

func (m *Notifikasi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
