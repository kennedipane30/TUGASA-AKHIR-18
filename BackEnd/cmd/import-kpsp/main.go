// Mengimpor daftar pertanyaan KPSP (data/kpsp.csv) ke database.
//
//	go run ./cmd/import-kpsp
//	go run ./cmd/import-kpsp path/lain.csv
//
// Kolom CSV: usia_bulan, nomor, aspek, pertanyaan
//
//	usia_bulan  kelompok umur skrining: 3, 6, 9, 12, 15, 18, 21, 24,
//	            30, 36, 42, 48, 54, 60, 66, 72
//	nomor       nomor urut pertanyaan 1-10 dalam satu kelompok umur
//	aspek       gerak_kasar | gerak_halus | bicara | sosialisasi
//	pertanyaan  bunyi pertanyaan yang dibacakan kepada orang tua
//
// Isi bawaan data/kpsp.csv adalah CONTOH bergaya KPSP Kemenkes supaya alur
// pencatatan dapat dijalankan dan diuji. Sebelum dipakai di posyandu, ganti
// bunyi pertanyaannya dengan lembar KPSP resmi pada Buku KIA / pedoman SDIDTK,
// lalu jalankan ulang perintah ini. Yang perlu diganti hanya isi CSV-nya;
// struktur tabel, penilaian 9-10/7-8/<=6, dan alur aplikasi tidak berubah.
//
// Aman dijalankan berulang kali: baris dicocokkan berdasarkan
// (usia_bulan, nomor), yang sudah ada diperbarui, bukan diduplikasi.
package main

import (
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"

	"posyandu-api/internal/database"
	"posyandu-api/internal/models"

	"github.com/joho/godotenv"
	"gorm.io/gorm"
)

var kolomWajib = []string{"usia_bulan", "nomor", "aspek", "pertanyaan"}

var aspekSah = map[string]bool{
	models.AspekGerakKasar:  true,
	models.AspekGerakHalus:  true,
	models.AspekBicara:      true,
	models.AspekSosialisasi: true,
}

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("peringatan: .env tidak terbaca, memakai environment sistem")
	}
	path := "data/kpsp.csv"
	if len(os.Args) > 1 {
		path = os.Args[1]
	}

	list, err := bacaCSV(path)
	if err != nil {
		log.Fatal("gagal membaca ", path, ": ", err)
	}
	if err := periksaKelengkapan(list); err != nil {
		log.Fatal("isi ", path, " belum benar: ", err)
	}

	db, err := database.Connect()
	if err != nil {
		log.Fatal("gagal konek database: ", err)
	}

	baru, perbarui, tetap := 0, 0, 0
	for _, q := range list {
		var m models.PertanyaanKpsp
		err := db.Where("usia_bulan = ? AND nomor = ?", q.UsiaBulan, q.Nomor).First(&m).Error
		switch {
		case errors.Is(err, gorm.ErrRecordNotFound):
			if err := db.Create(&q).Error; err != nil {
				log.Fatalf("gagal menyimpan umur %d nomor %d: %v", q.UsiaBulan, q.Nomor, err)
			}
			baru++
		case err != nil:
			log.Fatalf("gagal membaca umur %d nomor %d: %v", q.UsiaBulan, q.Nomor, err)
		case m.Aspek == q.Aspek && m.Pertanyaan == q.Pertanyaan:
			tetap++
		default:
			m.Aspek, m.Pertanyaan = q.Aspek, q.Pertanyaan
			if err := db.Save(&m).Error; err != nil {
				log.Fatalf("gagal memperbarui umur %d nomor %d: %v", q.UsiaBulan, q.Nomor, err)
			}
			perbarui++
		}
	}
	log.Printf("KPSP: %d pertanyaan baru, %d diperbarui, %d tidak berubah (total %d)",
		baru, perbarui, tetap, len(list))
}

// bacaCSV membaca berkas dan mengubah tiap baris menjadi PertanyaanKpsp.
func bacaCSV(path string) ([]models.PertanyaanKpsp, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.TrimLeadingSpace = true

	kepala, err := r.Read()
	if err != nil {
		return nil, fmt.Errorf("baris judul tidak terbaca: %w", err)
	}
	indeks := map[string]int{}
	for i, k := range kepala {
		indeks[strings.ToLower(strings.TrimSpace(k))] = i
	}
	for _, k := range kolomWajib {
		if _, ada := indeks[k]; !ada {
			return nil, fmt.Errorf("kolom %q tidak ada pada baris judul", k)
		}
	}

	list := []models.PertanyaanKpsp{}
	for baris := 2; ; baris++ {
		rec, err := r.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("baris %d: %w", baris, err)
		}
		ambil := func(k string) string {
			i := indeks[k]
			if i >= len(rec) {
				return ""
			}
			return strings.TrimSpace(rec[i])
		}
		if ambil("usia_bulan") == "" && ambil("pertanyaan") == "" {
			continue // baris kosong
		}

		usia, err := strconv.Atoi(ambil("usia_bulan"))
		if err != nil {
			return nil, fmt.Errorf("baris %d: usia_bulan %q bukan angka", baris, ambil("usia_bulan"))
		}
		nomor, err := strconv.Atoi(ambil("nomor"))
		if err != nil {
			return nil, fmt.Errorf("baris %d: nomor %q bukan angka", baris, ambil("nomor"))
		}
		if nomor < 1 || nomor > 10 {
			return nil, fmt.Errorf("baris %d: nomor harus 1-10, diterima %d", baris, nomor)
		}
		aspek := strings.ToLower(ambil("aspek"))
		if !aspekSah[aspek] {
			return nil, fmt.Errorf("baris %d: aspek %q tidak dikenal "+
				"(gerak_kasar, gerak_halus, bicara, sosialisasi)", baris, aspek)
		}
		teks := ambil("pertanyaan")
		if teks == "" {
			return nil, fmt.Errorf("baris %d: pertanyaan kosong", baris)
		}

		list = append(list, models.PertanyaanKpsp{
			UsiaBulan:  int16(usia),
			Nomor:      int16(nomor),
			Aspek:      aspek,
			Pertanyaan: teks,
		})
	}
	return list, nil
}

// periksaKelengkapan memastikan tiap kelompok umur berisi tepat 10 pertanyaan
// bernomor 1-10 tanpa ada yang terlewat atau kembar. Pemeriksaan dilakukan
// sebelum menyentuh database, supaya CSV yang salah tidak mengisi sebagian.
func periksaKelengkapan(list []models.PertanyaanKpsp) error {
	ada := map[int16]map[int16]bool{}
	for _, q := range list {
		if ada[q.UsiaBulan] == nil {
			ada[q.UsiaBulan] = map[int16]bool{}
		}
		if ada[q.UsiaBulan][q.Nomor] {
			return fmt.Errorf("umur %d bulan nomor %d ditulis lebih dari sekali", q.UsiaBulan, q.Nomor)
		}
		ada[q.UsiaBulan][q.Nomor] = true
	}
	sah := map[int16]bool{}
	for _, u := range models.UsiaKpsp {
		sah[u] = true
	}
	for usia := range ada {
		if !sah[usia] {
			return fmt.Errorf("umur %d bulan bukan kelompok skrining KPSP", usia)
		}
	}
	for _, u := range models.UsiaKpsp {
		if ada[u] == nil {
			return fmt.Errorf("umur %d bulan belum ada pertanyaannya", u)
		}
		for n := int16(1); n <= 10; n++ {
			if !ada[u][n] {
				return fmt.Errorf("umur %d bulan: pertanyaan nomor %d belum ada", u, n)
			}
		}
	}
	return nil
}