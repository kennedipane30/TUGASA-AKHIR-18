package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// JenisImunisasi adalah master jenis imunisasi pada program imunisasi rutin
// Kementerian Kesehatan RI (Buku KIA).
//
// Tabel  : jenis_imunisasi
// Isi    : HB0, BCG, OPV, DPT-HB-Hib, PCV, RV, IPV, MR, JE
// Sumber : diisi dan diperbarui otomatis saat server mulai
//
//	(service.ImunisasiService.SiapkanMaster), tidak diinput manual.
//
// Relasi:
//   - 1 JenisImunisasi memiliki banyak JadwalImunisasi (satu baris per dosis).
//   - 1 JenisImunisasi dirujuk oleh banyak ImunisasiBalita (riwayat pemberian).
//
// Jenis imunisasi yang tidak lagi dipakai tidak dihapus, melainkan dinonaktifkan
// (IsActive = false) agar riwayat imunisasi lama tetap utuh.
type JenisImunisasi struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// Kode: kode unik imunisasi, mis. "BCG", "DPT-HB-HIB".
	Kode string `gorm:"column:kode;size:20;not null;uniqueIndex:ux_jenis_imunisasi_kode" json:"kode"`

	// Nama: nama imunisasi yang ditampilkan, mis. "Polio Tetes (OPV)".
	Nama string `gorm:"column:nama;size:100;not null" json:"nama"`

	// Penyakit: penyakit yang dicegah, mis. "Tuberkulosis (TBC)".
	Penyakit string `gorm:"column:penyakit;size:200" json:"penyakit"`

	// CaraPemberian: cara dan lokasi pemberian, mis. "Suntik intrakutan (lengan kanan atas)".
	CaraPemberian string `gorm:"column:cara_pemberian;size:60" json:"cara_pemberian"`

	// Keterangan: catatan umum tentang imunisasi.
	Keterangan string `gorm:"column:keterangan;type:text" json:"keterangan"`

	// JumlahDosis: jumlah dosis rutin (sama dengan jumlah baris JadwalImunisasi).
	JumlahDosis int16 `gorm:"column:jumlah_dosis" json:"jumlah_dosis"`

	// Urutan: urutan tampil pada daftar imunisasi.
	Urutan int16 `gorm:"column:urutan" json:"urutan"`

	// KhususDaerah: true bila imunisasi hanya diberikan di daerah endemis (JE).
	// Imunisasi ini tidak dihitung dalam persentase kelengkapan imunisasi.
	KhususDaerah bool `gorm:"column:khusus_daerah" json:"khusus_daerah"`

	// IsActive: false bila imunisasi sudah tidak dipakai dalam program.
	IsActive bool `gorm:"column:is_active;default:true" json:"is_active"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `gorm:"index" json:"updated_at"`
}

func (JenisImunisasi) TableName() string { return "jenis_imunisasi" }

func (m *JenisImunisasi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}