package main

import (
	"log"

	"posyandu-api/internal/models"

	"gorm.io/gorm"
)

// seedMaster mengisi data master. Aman dijalankan berulang (tidak membuat data ganda).
func seedMaster(db *gorm.DB) {
	seedPosyandu(db)
	seedVaksin(db)
	seedPengaturan(db)
}

// seedPosyandu membuat SATU baris profil posyandu. Ubah isinya sesuai posyandu sebenarnya.
func seedPosyandu(db *gorm.DB) {
	var n int64
	db.Model(&models.Posyandu{}).Count(&n)
	if n > 0 {
		log.Println("profil posyandu sudah ada, dilewati")
		return
	}
	p := models.Posyandu{
		Kode:         "PSY-001",
		Nama:         "Posyandu Melati RW 05",
		Desa:         "Kelurahan Contoh",
		Kecamatan:    "Kecamatan Contoh",
		Kabupaten:    "Kabupaten Contoh",
		Provinsi:     "Provinsi Contoh",
		RW:           "05",
		AlamatLokasi: "Balai Warga RW 05",
		IsActive:     true,
	}
	if err := db.Create(&p).Error; err != nil {
		log.Fatal("gagal membuat profil posyandu: ", err)
	}
	log.Println("profil posyandu dibuat:", p.Nama)
}

type vaksinSeed struct {
	Kode, Nama string
	Dosis      int16
}

type jadwalSeed struct {
	Kode                  string
	DosisKe               int16
	UsiaMin, UsiaIdeal    int16
	UsiaMaks              *int16
	JarakMinimalHari      *int16
}

func p16(v int16) *int16 { return &v }

// seedVaksin mengisi jenis vaksin dan jadwal imunisasi dasar.
// PENTING: nilai di bawah adalah CONTOH berdasarkan jadwal imunisasi rutin pada
// umumnya. Cocokkan dengan Buku KIA / Permenkes terbaru bersama bidan sebelum dipakai.
func seedVaksin(db *gorm.DB) {
	vaksin := []vaksinSeed{
		{"HB0", "Hepatitis B (HB-0)", 1},
		{"BCG", "BCG", 1},
		{"POLIO", "Polio tetes (OPV)", 4},
		{"IPV", "Polio suntik (IPV)", 2},
		{"DPTHBHIB", "DPT-HB-Hib", 4},
		{"MR", "Campak-Rubella (MR)", 2},
	}
	for _, v := range vaksin {
		var n int64
		db.Model(&models.JenisVaksin{}).Where("kode = ?", v.Kode).Count(&n)
		if n > 0 {
			continue
		}
		row := models.JenisVaksin{Kode: v.Kode, Nama: v.Nama, JumlahDosis: v.Dosis, IsActive: true}
		if err := db.Create(&row).Error; err != nil {
			log.Fatal("gagal membuat jenis vaksin: ", err)
		}
	}

	jadwal := []jadwalSeed{
		{"HB0", 1, 0, 0, p16(1), nil},
		{"BCG", 1, 0, 1, p16(12), nil},
		{"POLIO", 1, 0, 1, p16(12), nil},
		{"POLIO", 2, 2, 2, p16(12), p16(28)},
		{"POLIO", 3, 3, 3, p16(12), p16(28)},
		{"POLIO", 4, 4, 4, p16(12), p16(28)},
		{"DPTHBHIB", 1, 2, 2, p16(12), nil},
		{"DPTHBHIB", 2, 3, 3, p16(12), p16(28)},
		{"DPTHBHIB", 3, 4, 4, p16(12), p16(28)},
		{"DPTHBHIB", 4, 18, 18, p16(24), nil},
		{"IPV", 1, 4, 4, p16(12), nil},
		{"IPV", 2, 9, 9, p16(12), nil},
		{"MR", 1, 9, 9, p16(12), nil},
		{"MR", 2, 18, 18, p16(24), nil},
	}
	for _, j := range jadwal {
		var jv models.JenisVaksin
		if err := db.Where("kode = ?", j.Kode).First(&jv).Error; err != nil {
			log.Fatal("jenis vaksin tidak ditemukan: ", j.Kode)
		}
		var n int64
		db.Model(&models.JadwalImunisasi{}).
			Where("jenis_vaksin_id = ? AND dosis_ke = ?", jv.ID, j.DosisKe).Count(&n)
		if n > 0 {
			continue
		}
		row := models.JadwalImunisasi{
			JenisVaksinID:    jv.ID,
			DosisKe:          j.DosisKe,
			UsiaMinBulan:     j.UsiaMin,
			UsiaIdealBulan:   j.UsiaIdeal,
			UsiaMaksBulan:    j.UsiaMaks,
			JarakMinimalHari: j.JarakMinimalHari,
		}
		if err := db.Create(&row).Error; err != nil {
			log.Fatal("gagal membuat jadwal imunisasi: ", err)
		}
	}
	log.Println("data vaksin dan jadwal imunisasi siap")
}

// seedPengaturan mengisi pengaturan sistem bawaan.
func seedPengaturan(db *gorm.DB) {
	isi := [][3]string{
		{"buka_daftar_hari_default", "7", "Pendaftaran dibuka N hari sebelum jadwal"},
		{"buka_checkin_menit_default", "60", "Check-in dibuka N menit sebelum jadwal"},
		{"masa_sesi_jam", "168", "Masa berlaku sesi login (jam)"},
		{"panjang_sandi_minimal", "6", "Panjang minimal kata sandi/PIN"},
		{"batas_usia_balita_bulan", "60", "Anak diarsipkan setelah melewati usia ini"},
	}
	for _, x := range isi {
		var n int64
		db.Model(&models.PengaturanSistem{}).Where("kunci = ?", x[0]).Count(&n)
		if n > 0 {
			continue
		}
		v, d := x[1], x[2]
		row := models.PengaturanSistem{Kunci: x[0], Nilai: v, Deskripsi: d}
		if err := db.Create(&row).Error; err != nil {
			log.Fatal("gagal membuat pengaturan: ", err)
		}
	}
	log.Println("pengaturan sistem siap")
}
