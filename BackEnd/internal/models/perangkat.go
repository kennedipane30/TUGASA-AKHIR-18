package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Perangkat: HP pengguna beserta token push (FCM). ID perangkat dipakai sebagai
// perangkat_asal pada data yang dikirim dari HP tersebut (delta sync).
type Perangkat struct {
	ID              uuid.UUID  `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	UserID          uint       `gorm:"column:user_id;not null;index" json:"user_id"`
	NamaPerangkat   string     `gorm:"column:nama_perangkat;size:100" json:"nama_perangkat"`
	Platform        string     `gorm:"column:platform;size:20" json:"platform"`
	VersiAplikasi   string     `gorm:"column:versi_aplikasi;size:20" json:"versi_aplikasi"`
	TokenFCM        string     `gorm:"column:token_fcm;size:255;not null;default:'';index" json:"-"`
	TokenDiperbarui *time.Time `gorm:"column:token_diperbarui" json:"token_diperbarui"`
	User            *User      `gorm:"foreignKey:UserID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

func (Perangkat) TableName() string { return "perangkat" }

func (m *Perangkat) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}