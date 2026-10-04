package models

import "time"

type Anak struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	KeluargaID   uint      `gorm:"not null;index" json:"keluarga_id"`
	Nama         string    `gorm:"size:100;not null" json:"nama"`
	NIK          string    `gorm:"size:16" json:"nik"`
	TglLahir     time.Time `gorm:"type:date;not null" json:"tgl_lahir"`
	JK           string    `gorm:"size:1;not null" json:"jk"` // L / P
	BeratLahir   *float64  `json:"berat_lahir"`               // kg
	PanjangLahir *float64  `json:"panjang_lahir"`             // cm
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (Anak) TableName() string { return "anak" }