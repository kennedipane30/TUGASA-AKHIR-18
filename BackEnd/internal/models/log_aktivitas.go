package models

import "time"

// LogAktivitas: satu baris log aktivitas (siapa, melakukan apa, kapan).
//
// Posyandu disimpan agar sekretaris hanya dapat melihat log desanya sendiri.
// Kolom ini tidak dikirim ke aplikasi (json:"-") karena sekretaris sudah
// pasti berada di posyandu yang sama.
//
// PIN, kata sandi, dan isi data kesehatan TIDAK pernah dicatat.
type LogAktivitas struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Posyandu  string    `gorm:"size:20;not null;index" json:"-"`
	UserID    uint      `gorm:"index" json:"user_id"`
	NamaUser  string    `gorm:"size:100" json:"nama_user"`
	Role      string    `gorm:"size:20;index" json:"role"`
	Aksi      string    `gorm:"size:120;not null" json:"aksi"`
	Modul     string    `gorm:"size:40;index" json:"modul"`
	ObjekID   string    `gorm:"size:64" json:"objek_id,omitempty"`
	Metode    string    `gorm:"size:10" json:"-"`
	Jalur     string    `gorm:"size:200" json:"-"`
	IP        string    `gorm:"size:64" json:"-"`
	CreatedAt time.Time `gorm:"index" json:"waktu"`
}

func (LogAktivitas) TableName() string { return "log_aktivitas" }