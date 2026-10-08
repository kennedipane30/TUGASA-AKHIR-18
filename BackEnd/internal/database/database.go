package database

import (
	"fmt"
	"log"
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

	// Perbaiki tipe kolom jam lama (timestamptz) menjadi time sebelum AutoMigrate.
	for _, kolom := range []string{"jam_mulai", "jam_selesai"} {
		sql := fmt.Sprintf(`
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'jadwal_posyandu'
      AND column_name = '%[1]s'
      AND data_type <> 'time without time zone'
  ) THEN
    ALTER TABLE jadwal_posyandu
      ALTER COLUMN %[1]s TYPE time
      USING (%[1]s AT TIME ZONE 'Asia/Jakarta')::time;
  END IF;
END $$;`, kolom)
		if err := db.Exec(sql).Error; err != nil {
			log.Printf("peringatan: perbaikan kolom %s gagal: %v", kolom, err)
		}
	}

	// Seluruh tabel dibuat dari daftar model di models/registry.go.
	if err := db.AutoMigrate(models.AllModels()...); err != nil {
		return nil, err
	}
	return db, nil
}