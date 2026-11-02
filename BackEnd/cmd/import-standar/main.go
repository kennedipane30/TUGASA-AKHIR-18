// Mengimpor tabel standar antropometri WHO (data/standar_antropometri.csv) ke database.
//
//	go run ./cmd/import-standar
//	go run ./cmd/import-standar path/lain.csv
//
// Aman dijalankan berulang kali: baris yang sudah ada diperbarui, bukan diduplikasi.
package main

import (
	"encoding/csv"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"

	"posyandu-api/internal/database"
	"posyandu-api/internal/models"

	"github.com/joho/godotenv"
	"gorm.io/gorm/clause"
)

var kolomWajib = []string{
	"indeks", "jenis_kelamin", "acuan", "satuan_acuan", "l", "m", "s",
	"sd_min3", "sd_min2", "sd_min1", "median", "sd_plus1", "sd_plus2", "sd_plus3", "sumber",
}

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("peringatan: .env tidak terbaca, memakai environment sistem")
	}
	path := "data/standar_antropometri.csv"
	if len(os.Args) > 1 {
		path = os.Args[1]
	}

	list, err := bacaCSV(path)
	if err != nil {
		log.Fatal(err)
	}

	db, err := database.Connect()
	if err != nil {
		log.Fatal("gagal konek database: ", err)
	}

	err = db.Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "indeks"}, {Name: "jenis_kelamin"}, {Name: "acuan"}},
		DoUpdates: clause.AssignmentColumns([]string{
			"satuan_acuan", "l", "m", "s", "sd_min3", "sd_min2", "sd_min1", "median",
			"sd_plus1", "sd_plus2", "sd_plus3", "sumber", "updated_at",
		}),
	}).CreateInBatches(list, 200).Error
	if err != nil {
		log.Fatal("gagal menyimpan standar: ", err)
	}

	var total int64
	db.Model(&models.StandarAntropometri{}).Count(&total)
	log.Printf("selesai: %d baris diimpor dari %s, total di database %d baris", len(list), path, total)
}

func bacaCSV(path string) ([]models.StandarAntropometri, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("gagal membuka %s: %w", path, err)
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.TrimLeadingSpace = true
	header, err := r.Read()
	if err != nil {
		return nil, fmt.Errorf("gagal membaca header: %w", err)
	}
	pos := map[string]int{}
	for i, h := range header {
		pos[strings.TrimSpace(strings.TrimPrefix(h, string(rune(0xFEFF))))] = i
	}
	for _, k := range kolomWajib {
		if _, ok := pos[k]; !ok {
			return nil, fmt.Errorf("kolom %q tidak ada di %s", k, path)
		}
	}

	list := []models.StandarAntropometri{}
	baris := 1
	for {
		rec, err := r.Read()
		if err == io.EOF {
			break
		}
		baris++
		if err != nil {
			return nil, fmt.Errorf("baris %d: %w", baris, err)
		}
		angka := func(k string) (float64, error) {
			v, err := strconv.ParseFloat(strings.TrimSpace(rec[pos[k]]), 64)
			if err != nil {
				return 0, fmt.Errorf("baris %d kolom %s: %w", baris, k, err)
			}
			return v, nil
		}
		var nilai [11]float64
		for i, k := range []string{"acuan", "l", "m", "s", "sd_min3", "sd_min2", "sd_min1", "median", "sd_plus1", "sd_plus2", "sd_plus3"} {
			if nilai[i], err = angka(k); err != nil {
				return nil, err
			}
		}
		jk := strings.ToUpper(strings.TrimSpace(rec[pos["jenis_kelamin"]]))
		if jk != "L" && jk != "P" {
			return nil, fmt.Errorf("baris %d: jenis_kelamin harus L atau P", baris)
		}
		list = append(list, models.StandarAntropometri{
			Indeks:       strings.TrimSpace(rec[pos["indeks"]]),
			JenisKelamin: jk,
			Acuan:        nilai[0],
			SatuanAcuan:  strings.TrimSpace(rec[pos["satuan_acuan"]]),
			L:            nilai[1],
			M:            nilai[2],
			S:            nilai[3],
			SdMin3:       nilai[4],
			SdMin2:       nilai[5],
			SdMin1:       nilai[6],
			Median:       nilai[7],
			SdPlus1:      nilai[8],
			SdPlus2:      nilai[9],
			SdPlus3:      nilai[10],
			Sumber:       strings.TrimSpace(rec[pos["sumber"]]),
		})
	}
	if len(list) == 0 {
		return nil, fmt.Errorf("%s tidak berisi data", path)
	}
	return list, nil
}