package models

// AllModels mengembalikan seluruh model untuk AutoMigrate.
// Semua model didaftarkan dalam satu pemanggilan agar GORM mengurutkan
// pembuatan tabel sesuai ketergantungan kunci asingnya.
func AllModels() []any {
	return []any{
		&Posyandu{},
		&User{},
		&PermintaanResetSandi{},
		&Keluarga{},
		&OrangTua{},
		&Anak{},
		&PengajuanKoreksi{},
		&JadwalPosyandu{},
		&PetugasJadwal{},
		&KegiatanKhusus{},
		&Pendaftaran{},
		&Pengukuran{},
		&KoreksiPengukuran{},
		&VerifikasiPengukuran{},
		&StatusGizi{},
		&PemeriksaanBidan{},
		&StandarAntropometri{},
		&JenisVaksin{},
		&JadwalImunisasi{},
		&ImunisasiAnak{},
		&RencanaImunisasi{},
		&SuplemenAnak{},
		&PeringatanRisiko{},
		&Rujukan{},
		&Intervensi{},
		&KunjunganRumah{},
		&Pengumuman{},
		&Notifikasi{},
		&KontenEdukasi{},
		&Perangkat{},
		&KonflikSinkron{},
		&LogAktivitas{},
		&PengaturanSistem{},
		&BackupData{},
		&LaporanBulanan{},
	}
}
