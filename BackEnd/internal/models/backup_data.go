package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// BackupData: Riwayat backup dan restore data.
type BackupData struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	Jenis string `gorm:"column:jenis;size:10" json:"jenis"`
	NamaFile string `gorm:"column:nama_file;size:150" json:"nama_file"`
	UkuranByte int64 `gorm:"column:ukuran_byte" json:"ukuran_byte"`
	Status string `gorm:"column:status;size:15" json:"status"`
	DibuatOleh uint `gorm:"column:dibuat_oleh;not null;index" json:"dibuat_oleh"`
	Waktu time.Time `gorm:"column:waktu;autoCreateTime" json:"waktu"`
	DibuatOlehUser *User `gorm:"foreignKey:DibuatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (BackupData) TableName() string { return "backup_data" }

func (m *BackupData) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
