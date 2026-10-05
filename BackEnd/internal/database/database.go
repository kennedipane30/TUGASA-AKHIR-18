package database

import (
	"fmt"
	"os"

	"posyandu-api/internal/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func Connect() (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable TimeZone=Asia/Jakarta",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"),
	)
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}
	// semua model didaftarkan di sini
	// urutan: tabel induk dulu, baru tabel yang punya foreign key
	if err := db.AutoMigrate(
		&models.User{},
		// models.Posyandu telah dihapus karena hanya menggunakan 1 posyandu
		&models.Keluarga{},
		&models.Ayah{},
		&models.Anak{},

		// BARU: jadwal, pendaftaran, pengukuran, catatan bidan
		&models.JenisVaksin{},
		&models.JadwalPosyandu{},
		&models.Pendaftaran{},
		&models.Pengukuran{},
		&models.PemeriksaanBidan{},
		&models.ImunisasiAnak{},
		&models.SuplemenAnak{},
	); err != nil {
		return nil, err
	}
	return db, nil
}