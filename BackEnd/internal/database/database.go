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

	if err := db.AutoMigrate(models.AllModels()...); err != nil {
		return nil, err
	}

	samakanKodePosyandu(db)
	isiPosyanduData(db)
	return db, nil
}

// samakanKodePosyandu: ubah kode lama menjadi kode baku (silimbat, sitoluama, aekbolon).
func samakanKodePosyandu(db *gorm.DB) {
	ganti := map[string]string{
		"aek_bolon": models.PosyanduAekBolon,
		"silaen":    models.PosyanduSilimbat,
	}
	for _, tabel := range []string{"keluarga", "jadwal_posyandu", "users"} {
		for lama, baru := range ganti {
			if err := db.Exec("UPDATE "+tabel+" SET posyandu = ? WHERE posyandu = ?", baru, lama).Error; err != nil {
				log.Printf("peringatan: samakan kode posyandu tabel %s gagal: %v", tabel, err)
			}
		}
	}
}

// isiPosyanduData: data lama yang belum punya posyandu dianggap milik posyandu bawaan.
// Ubah lewat DEFAULT_POSYANDU di .env (silimbat | sitoluama | aekbolon).
func isiPosyanduData(db *gorm.DB) {
	def, ok := models.NormalisasiPosyandu(os.Getenv("DEFAULT_POSYANDU"))
	if !ok {
		def = models.PosyanduSitoluama
	}
	for _, tabel := range []string{"keluarga", "jadwal_posyandu"} {
		if err := db.Exec("UPDATE "+tabel+" SET posyandu = ? WHERE posyandu IS NULL OR posyandu = ''", def).Error; err != nil {
			log.Printf("peringatan: isi posyandu tabel %s gagal: %v", tabel, err)
		}
	}
	if err := db.Exec(
		"UPDATE users SET posyandu = ? WHERE role <> 'admin' AND (posyandu IS NULL OR posyandu = '')", def,
	).Error; err != nil {
		log.Printf("peringatan: isi posyandu akun gagal: %v", err)
	}
}