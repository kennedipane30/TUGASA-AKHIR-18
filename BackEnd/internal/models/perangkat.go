package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Perangkat: Perangkat yang menyinkronkan data dan status sinkronnya.
type Perangkat struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	UserID uint `gorm:"column:user_id;not null;index" json:"user_id"`
	NamaPerangkat string `gorm:"column:nama_perangkat;size:100" json:"nama_perangkat"`
	Platform string `gorm:"column:platform;size:20" json:"platform"`
	VersiAplikasi string `gorm:"column:versi_aplikasi;size:20" json:"versi_aplikasi"`
	TerakhirSinkron *time.Time `gorm:"column:terakhir_sinkron" json:"terakhir_sinkron"`
	JumlahDataTertunda int `gorm:"column:jumlah_data_tertunda" json:"jumlah_data_tertunda"`
	StatusSinkron string `gorm:"column:status_sinkron;size:15;default:berhasil" json:"status_sinkron"`
	PesanTerakhir string `gorm:"column:pesan_terakhir;type:text" json:"pesan_terakhir"`
	User *User `gorm:"foreignKey:UserID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Perangkat) TableName() string { return "perangkat" }

func (m *Perangkat) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
