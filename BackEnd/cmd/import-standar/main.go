// Mengimpor tabel standar antropometri dari berkas CSV ke tabel standar_antropometri.
//
// Pemakaian (dari folder BackEnd):
//   go run ./cmd/import-standar data/standar_antropometri.csv
//
// Format CSV (baris pertama adalah judul kolom):
//   indikator,jenis_kelamin,acuan,sd_min3,sd_min2,sd_min1,median,sd_plus1,sd_plus2,sd_plus3,sumber
//   BB_U,L,0,2.1,2.5,2.9,3.3,3.9,4.4,5.0,Permenkes 2/2020
//
// Isi nilai dari lampiran Permenkes No. 2 Tahun 2020 (Standar Antropometri Anak).
// Impor aman diulang: baris dengan indikator, jenis kelamin, dan acuan yang sama diperbarui.
package main

import (
	"encoding/csv"
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

	"posyandu-api/internal/database"
	"posyandu-api/internal/models"

	"github.com/joho/godotenv"
	"gorm.io/gorm"
)

func angka(s string) (float64, error) {
	return strconv.ParseFloat(strings.TrimSpace(strings.ReplaceAll(s, ",", ".")), 64)
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("pemakaian: go run ./cmd/import-standar <berkas.csv>")
	}
	if err := godotenv.Load(); err != nil {
		log.Fatal("gagal membaca .env, jalankan dari folder BackEnd: ", err)
	}
	db, err := database.Connect()
	if err != nil {
		log.Fatal("gagal konek database: ", err)
	}

	f, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	baris, err := csv.NewReader(f).ReadAll()
	if err != nil {
		log.Fatal("CSV tidak valid: ", err)
	}
	if len(baris) < 2 {
		log.Fatal("CSV kosong")
	}

	dibuat, diperbarui := 0, 0
	for i, r := range baris[1:] {
		if len(r) < 11 {
			log.Fatalf("baris %d: kolom kurang (harus 11 kolom)", i+2)
		}
		var v [8]float64
		for k := 0; k < 8; k++ {
			v[k], err = angka(r[2+k])
			if err != nil {
				log.Fatalf("baris %d kolom %d: angka tidak valid: %q", i+2, 3+k, r[2+k])
			}
		}
		row := models.StandarAntropometri{
			Indikator:    strings.TrimSpace(r[0]),
			JenisKelamin: strings.TrimSpace(r[1]),
			Acuan:        v[0],
			SdMin3:       &v[1], SdMin2: &v[2], SdMin1: &v[3],
			Median:       &v[4],
			SdPlus1:      &v[5], SdPlus2: &v[6], SdPlus3: &v[7],
			Sumber:       strings.TrimSpace(r[10]),
		}

		var ada models.StandarAntropometri
		err = db.Where("indikator = ? AND jenis_kelamin = ? AND acuan = ?",
			row.Indikator, row.JenisKelamin, row.Acuan).First(&ada).Error
		switch {
		case errors.Is(err, gorm.ErrRecordNotFound):
			if err := db.Create(&row).Error; err != nil {
				log.Fatal(err)
			}
			dibuat++
		case err != nil:
			log.Fatal(err)
		default:
			row.ID = ada.ID
			if err := db.Save(&row).Error; err != nil {
				log.Fatal(err)
			}
			diperbarui++
		}
	}
	fmt.Printf("selesai: %d baris dibuat, %d diperbarui\n", dibuat, diperbarui)
}
