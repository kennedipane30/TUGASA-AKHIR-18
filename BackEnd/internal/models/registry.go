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
		&Balita{},

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
		&SuplemenBalita{},

		// imunisasi
		&JenisImunisasi{},
		&JadwalImunisasi{},
		&ImunisasiBalita{},
		&ImunisasiMandiriBalita{}, // imunisasi di luar program (dicatat bidan)

		// KPSP (skrining perkembangan)
		&PertanyaanKpsp{}, // master 10 pertanyaan per kelompok umur
		&HasilKpsp{},
		&JawabanKpsp{},

		// notifikasi, perangkat & log aktivitas
		&Notifikasi{},
		&Perangkat{},
		&LogAktivitas{},
	}
}