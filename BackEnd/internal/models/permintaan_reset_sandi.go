package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PermintaanResetSandi: Permintaan lupa kata sandi dari pengguna kepada admin.
type PermintaanResetSandi struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	UserID *uint `gorm:"column:user_id;index" json:"user_id"`
	IdentitasPengaju string `gorm:"column:identitas_pengaju;size:50" json:"identitas_pengaju"`
	Alasan string `gorm:"column:alasan;type:text" json:"alasan"`
	Status string `gorm:"column:status;size:20;default:menunggu" json:"status"`
	DiprosesOleh *uint `gorm:"column:diproses_oleh;index" json:"diproses_oleh"`
	DiprosesPada *time.Time `gorm:"column:diproses_pada" json:"diproses_pada"`
	Catatan string `gorm:"column:catatan;type:text" json:"catatan"`
	CreatedAt time.Time `gorm:"column:created_at" json:"created_at"`
	User *User `gorm:"foreignKey:UserID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DiprosesOlehUser *User `gorm:"foreignKey:DiprosesOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (PermintaanResetSandi) TableName() string { return "permintaan_reset_sandi" }

func (m *PermintaanResetSandi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
