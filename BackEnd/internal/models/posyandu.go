package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Posyandu: profil posyandu. Sistem hanya melayani SATU posyandu, sehingga tabel
// ini hanya boleh berisi satu baris. Kolom Singleton (selalu true, unik, dan
// dibatasi CHECK) menjamin database menolak baris kedua.
type Posyandu struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Singleton    bool      `gorm:"column:singleton;not null;default:true;uniqueIndex:ux_posyandu_singleton;check:chk_posyandu_singleton,singleton = true" json:"-"`
	Kode         string    `gorm:"column:kode;size:20;not null;uniqueIndex:ux_posyandu_kode" json:"kode"`
	Nama         string    `gorm:"column:nama;size:100;not null" json:"nama"`
	Desa         string    `gorm:"column:desa;size:100" json:"desa"`
	Kecamatan    string    `gorm:"column:kecamatan;size:100" json:"kecamatan"`
	Kabupaten    string    `gorm:"column:kabupaten;size:100" json:"kabupaten"`
	Provinsi     string    `gorm:"column:provinsi;size:100" json:"provinsi"`
	RW           string    `gorm:"column:rw;size:5" json:"rw"`
	AlamatLokasi string    `gorm:"column:alamat_lokasi;type:text" json:"alamat_lokasi"`
	NoKontak     string    `gorm:"column:no_kontak;size:20" json:"no_kontak"`
	IsActive     bool      `gorm:"column:is_active;default:true" json:"is_active"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (Posyandu) TableName() string { return "posyandu" }

func (p *Posyandu) BeforeCreate(*gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	p.Singleton = true
	return nil
}
