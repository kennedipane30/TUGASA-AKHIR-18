package main

import (
	"errors"
	"log"
	"os"

	"posyandu-api/internal/models"
	"posyandu-api/internal/utils"

	"gorm.io/gorm"
)

// Satu akun sekretaris untuk setiap desa. No. HP format +62 (E.164).
var daftarSekretaris = []struct{ Nama, NoHP, Posyandu string }{
	{"Kennedi Pane", "+6282235805348", "sitoluama"},
	{"Natasya Tambunan", "+6282235805349", "silimbat"},
	{"Sara Rajagukguk", "+6282235805310", "aekbolon"},
}

// seedSekretaris membuat (atau memperbarui) satu akun sekretaris untuk setiap desa.
// Sekretaris masuk dengan No. HP + PIN dari .env: SEKRETARIS_PIN.
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
		noHP, ok := utils.NormalisasiNoHP(s.NoHP)
		if !ok {
			log.Fatal("No. HP sekretaris tidak valid: ", s.NoHP)
		}

		// satu sekretaris per desa: dicari berdasarkan role + posyandu
		var u models.User
		err := db.Where("role = ? AND posyandu = ? AND diarsipkan_pada IS NULL",
			models.RoleSekretaris, s.Posyandu).First(&u).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			u = models.User{
				Nama:     s.Nama,
				NoHP:     &noHP,
				PinHash:  hash,
				Role:     models.RoleSekretaris,
				Posyandu: s.Posyandu,
				IsActive: true,
			}
			if err := db.Create(&u).Error; err != nil {
				log.Fatal("gagal membuat sekretaris ", s.Posyandu, ": ", err)
			}
			log.Println("sekretaris dibuat:", s.Nama, "| No. HP:", noHP)
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
		log.Println("sekretaris sudah ada, data diperbarui:", s.Nama, "| No. HP:", noHP)
	}
}