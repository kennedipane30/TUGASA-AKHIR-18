package main

import (
	"errors"
	"log"
	"os"

	"posyandu-api/internal/models"
	"posyandu-api/internal/utils"

	"gorm.io/gorm"
)

var daftarSekretaris = []struct{ Nama, Username, Posyandu string }{
	{"Sekretaris Sitoluama", "sekretaris.sitoluama", "sitoluama"},
	{"Sekretaris Silimbat", "sekretaris.silimbat", "silimbat"},
	{"Sekretaris Aek Bolon", "sekretaris.aekbolon", "aekbolon"},
}

// seedSekretaris membuat satu akun sekretaris untuk setiap desa.
func seedSekretaris(db *gorm.DB) {
	password := os.Getenv("SEKRETARIS_PASSWORD")
	if len(password) < 6 {
		log.Fatal("SEKRETARIS_PASSWORD wajib diisi di .env (minimal 6 karakter)")
	}
	hash, err := utils.HashPassword(password)
	if err != nil {
		log.Fatal(err)
	}

	for _, s := range daftarSekretaris {
		var u models.User
		err := db.Where("username = ?", s.Username).First(&u).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			username := s.Username
			u = models.User{
				Nama:     s.Nama,
				Username: &username,
				Password: hash,
				Role:     models.RoleSekretaris,
				Posyandu: s.Posyandu,
				IsActive: true,
			}
			if err := db.Create(&u).Error; err != nil {
				log.Fatal("gagal membuat sekretaris ", s.Posyandu, ": ", err)
			}
			log.Println("sekretaris dibuat:", s.Username)
			continue
		}
		if err != nil {
			log.Fatal(err)
		}

		u.Role = models.RoleSekretaris
		u.Posyandu = s.Posyandu
		u.IsActive = true
		if err := db.Save(&u).Error; err != nil {
			log.Fatal("gagal memperbarui sekretaris ", s.Posyandu, ": ", err)
		}
		log.Println("sekretaris sudah ada, diperbarui:", s.Username)
	}
}