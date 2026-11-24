package models

// AllModels mengembalikan seluruh model untuk AutoMigrate.
// Semua model didaftarkan dalam satu pemanggilan agar GORM mengurutkan
// pembuatan tabel sesuai ketergantungan kunci asingnya.
func AllModels() []any {
	return []any{
		// akun & keluarga
		&User{},
		&KodeOTP{}, // kode OTP WhatsApp (registrasi & lupa PIN)
		&Keluarga{},
		&OrangTua{},
		&Anak{},

		// jadwal & pelayanan posyandu
		&JadwalPosyandu{},
		&Pendaftaran{},
		&Pengukuran{},
		&PemeriksaanBidan{},
		&Rujukan{}, // surat rujukan balita (bidan -> faskes)

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
		&VaksinMandiriAnak{}, // vaksin di luar program (dicatat bidan)

		// notifikasi, perangkat & log aktivitas
		&Notifikasi{},
		&Perangkat{},
		&LogAktivitas{},
	}
}