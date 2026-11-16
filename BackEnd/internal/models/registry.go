package models

// AllModels mengembalikan seluruh model untuk AutoMigrate.
// Semua model didaftarkan dalam satu pemanggilan agar GORM mengurutkan
// pembuatan tabel sesuai ketergantungan kunci asingnya.
func AllModels() []any {
	return []any{
		// akun & keluarga
		&User{},
		&Keluarga{},
		&OrangTua{},
		&Anak{},

		// jadwal & pelayanan posyandu
		&JadwalPosyandu{},
		&Pendaftaran{},
		&Pengukuran{},
		&PemeriksaanBidan{},

		// status gizi & penilaian
		&StatusGizi{},
		&PenilaianTimbang{},
		&StandarAntropometri{},
		&PeringatanRisiko{},
		&SuplemenAnak{},

		// imunisasi
		&JenisVaksin{},
		&JadwalImunisasi{},
		&ImunisasiAnak{},

		// notifikasi, perangkat & log aktivitas
		&Notifikasi{},
		&Perangkat{},
		&LogAktivitas{},
	}
}