package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// JenisVaksin adalah master jenis vaksin pada program imunisasi rutin
// Kementerian Kesehatan RI (Buku KIA).
//
// Tabel  : jenis_vaksin
// Isi    : HB0, BCG, OPV, DPT-HB-Hib, PCV, RV, IPV, MR, JE
// Sumber : diisi dan diperbarui otomatis saat server mulai
//
//	(service.VaksinService.SiapkanMaster), tidak diinput manual.
//
// Relasi:
//   - 1 JenisVaksin memiliki banyak JadwalImunisasi (satu baris per dosis).
//   - 1 JenisVaksin dirujuk oleh banyak ImunisasiAnak (riwayat pemberian).
//
// Jenis vaksin yang tidak lagi dipakai tidak dihapus, melainkan dinonaktifkan
// (IsActive = false) agar riwayat imunisasi lama tetap utuh.
type JenisVaksin struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// Kode: kode unik vaksin, mis. "BCG", "DPT-HB-HIB".
	Kode string `gorm:"column:kode;size:20;not null;uniqueIndex:ux_jenis_vaksin_kode" json:"kode"`

	// Nama: nama vaksin yang ditampilkan, mis. "Polio Tetes (OPV)".
	Nama string `gorm:"column:nama;size:100;not null" json:"nama"`

	// Penyakit: penyakit yang dicegah, mis. "Tuberkulosis (TBC)".
	Penyakit string `gorm:"column:penyakit;size:200" json:"penyakit"`

	// CaraPemberian: cara dan lokasi pemberian, mis. "Suntik intrakutan (lengan kanan atas)".
	CaraPemberian string `gorm:"column:cara_pemberian;size:60" json:"cara_pemberian"`

	// Keterangan: catatan umum tentang vaksin.
	Keterangan string `gorm:"column:keterangan;type:text" json:"keterangan"`

	// JumlahDosis: jumlah dosis rutin (sama dengan jumlah baris JadwalImunisasi).
	JumlahDosis int16 `gorm:"column:jumlah_dosis" json:"jumlah_dosis"`

	// Urutan: urutan tampil pada daftar vaksin.
	Urutan int16 `gorm:"column:urutan" json:"urutan"`

	// KhususDaerah: true bila vaksin hanya diberikan di daerah endemis (JE).
	// Vaksin ini tidak dihitung dalam persentase kelengkapan imunisasi.
	KhususDaerah bool `gorm:"column:khusus_daerah" json:"khusus_daerah"`

	// IsActive: false bila vaksin sudah tidak dipakai dalam program.
	IsActive bool `gorm:"column:is_active;default:true" json:"is_active"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (JenisVaksin) TableName() string { return "jenis_vaksin" }

func (m *JenisVaksin) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}