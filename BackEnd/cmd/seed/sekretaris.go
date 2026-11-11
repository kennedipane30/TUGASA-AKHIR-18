package main

import (
	"errors"
	"log"
	"os"

	"posyandu-api/internal/models"
	"posyandu-api/internal/utils"

	"gorm.io/gorm"
)

var daftarSekretaris = []struct{ Nama, Username, NoHP, Posyandu string }{
	{"Kennedi Pane", "sekretaris.sitoluama", "082235805348", "sitoluama"},
	{"Natasya Tambunan", "sekretaris.silimbat", "082235805349", "silimbat"},
	{"Sara Rajagukguk", "sekretaris.aekbolon", "082235805310", "aekbolon"},
}

// seedSekretaris membuat (atau memperbarui) satu akun sekretaris untuk setiap desa.
// Sekretaris masuk dengan username atau No. HP + PIN dari .env: SEKRETARIS_PIN.
func seedSekretaris(db *gorm.DB) {
	pin := os.Getenv("SEKRETARIS_PIN")
	if err := utils.ValidasiPIN(pin); err != nil {
		log.Fatal("SEKRETARIS_PIN di .env tidak valid: ", err.Error())
	}
	hash, err := utils.HashPIN(pin)
	if err != nil {
		log.Fatal(err)
	}

	for _, s := range daftarSekretaris {
		username := s.Username
		noHP := s.NoHP

		var u models.User
		err := db.Where("username = ?", s.Username).First(&u).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			u = models.User{
				Nama:     s.Nama,
				Username: &username,
				NoHP:     &noHP,
				PinHash:  hash,
				Role:     models.RoleSekretaris,
				Posyandu: s.Posyandu,
				IsActive: true,
			}
			if err := db.Create(&u).Error; err != nil {
				log.Fatal("gagal membuat sekretaris ", s.Posyandu, ": ", err)
			}
			log.Println("sekretaris dibuat:", s.Nama, "| username:", s.Username, "| No. HP:", s.NoHP)
			continue
		}
		if err != nil {
			log.Fatal(err)
		}

		u.Nama = s.Nama
		u.NoHP = &noHP
		u.Role = models.RoleSekretaris
		u.Posyandu = s.Posyandu
		u.IsActive = true
		u.PinHash = hash
		u.WajibGantiPIN = false
		u.GagalLogin = 0
		u.TerkunciSampai = nil
		if err := db.Save(&u).Error; err != nil {
			log.Fatal("gagal memperbarui sekretaris ", s.Posyandu, ": ", err)
		}
		log.Println("sekretaris sudah ada, data diperbarui:", s.Nama, "| username:", s.Username, "| No. HP:", s.NoHP)
	}
}