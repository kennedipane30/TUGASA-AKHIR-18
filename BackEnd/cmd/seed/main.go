package main

import (
	"log"
	"os"

	"posyandu-api/internal/database"
	"posyandu-api/internal/models"
	"posyandu-api/internal/utils"

	"github.com/joho/godotenv"
	"gorm.io/gorm"
)

func seedPosyandu(db *gorm.DB) {
	daftar := []string{
		"Posyandu Melati 1",
		"Posyandu Melati 2",
		"Posyandu Mawar",
	}
	for _, n := range daftar {
		p := models.Posyandu{Nama: n}
		if err := db.Where(models.Posyandu{Nama: n}).FirstOrCreate(&p).Error; err != nil {
			log.Fatal("gagal seed posyandu: ", err)
		}
	}
	log.Println("seed posyandu selesai")
}

func seedAdmin(db *gorm.DB) {
	nama := os.Getenv("ADMIN_NAME")
	phone := os.Getenv("ADMIN_PHONE")
	password := os.Getenv("ADMIN_PASSWORD")
	if phone == "" || password == "" {
		log.Fatal("ADMIN_PHONE dan ADMIN_PASSWORD wajib diisi di .env")
	}

	var count int64
	db.Model(&models.User{}).Where("no_hp = ?", phone).Count(&count)
	if count > 0 {
		log.Println("admin sudah ada, seeder admin dilewati")
		return
	}

	hash, err := utils.HashPassword(password)
	if err != nil {
		log.Fatal(err)
	}

	admin := models.User{
		Nama:     nama,
		NoHP:     &phone,
		Password: hash,
		Role:     models.RoleAdmin,
		IsActive: true,
	}
	if err := db.Create(&admin).Error; err != nil {
		log.Fatal("gagal membuat admin: ", err)
	}
	log.Println("admin berhasil dibuat, login dengan No. HP:", phone)
}

func main() {
	if err := godotenv.Load(); err != nil {
		log.Fatal("gagal membaca .env, jalankan dari folder BackEnd: ", err)
	}

	db, err := database.Connect()
	if err != nil {
		log.Fatal("gagal konek database: ", err)
	}

	seedPosyandu(db)
	seedAdmin(db)
}