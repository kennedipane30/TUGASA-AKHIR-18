package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Kelompok imunisasi pada JadwalImunisasi.Kelompok.
const (
	// KelompokImunisasiDasar: imunisasi dasar bayi (usia 0-11 bulan).
	// Dipakai untuk menghitung status Imunisasi Dasar Lengkap (IDL).
	KelompokImunisasiDasar = "dasar"

	// KelompokImunisasiLanjutan: imunisasi lanjutan baduta (usia 12-24 bulan),
	// mis. PCV 3, DPT-HB-Hib 4, dan MR 2.
	KelompokImunisasiLanjutan = "lanjutan"
)

// JadwalImunisasi adalah master jadwal imunisasi: aturan usia pemberian
// setiap dosis vaksin. Berlaku sama untuk semua anak.
//
// Tabel  : jadwal_imunisasi
// Kunci  : (jenis_vaksin_id, dosis_ke) unik, satu baris per dosis.
// Sumber : diisi otomatis saat server mulai (service.VaksinService.SiapkanMaster).
//
// Jadwal vaksin per anak TIDAK disimpan di database. Jadwal dan status setiap
// dosis (sudah, saatnya diberikan, terlambat, belum waktunya, menunggu dosis
// sebelumnya, lewat batas usia) dihitung dari:
//
//	JadwalImunisasi + tanggal lahir anak + riwayat ImunisasiAnak.
//
// Contoh: DPT-HB-Hib dosis 2 -> usia minimal 3 bulan, ideal 3 bulan,
// jarak minimal 28 hari dari dosis 1, kelompok "dasar".
type JadwalImunisasi struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// JenisVaksinID: vaksin yang dijadwalkan (FK ke jenis_vaksin).
	JenisVaksinID uuid.UUID `gorm:"column:jenis_vaksin_id;type:uuid;not null;uniqueIndex:ux_jadwal_imunisasi_komposit" json:"jenis_vaksin_id"`

	// DosisKe: urutan dosis (1, 2, 3, ...).
	DosisKe int16 `gorm:"column:dosis_ke;not null;uniqueIndex:ux_jadwal_imunisasi_komposit" json:"dosis_ke"`

	// Kelompok: "dasar" atau "lanjutan" (lihat konstanta di atas).
	Kelompok string `gorm:"column:kelompok;size:10" json:"kelompok"`

	// UsiaMinBulan: usia paling awal dosis boleh diberikan (bulan).
	UsiaMinBulan int16 `gorm:"column:usia_min_bulan" json:"usia_min_bulan"`

	// UsiaIdealBulan: usia pemberian sesuai jadwal Kemenkes (bulan),
	// dasar perhitungan perkiraan tanggal pemberian.
	UsiaIdealBulan int16 `gorm:"column:usia_ideal_bulan" json:"usia_ideal_bulan"`

	// UsiaMaksBulan: batas usia pemberian (bulan); nil = tidak ada batas.
	// Lewat batas ini dosis berstatus "terlewat" dan tidak diberikan lagi.
	UsiaMaksBulan *int16 `gorm:"column:usia_maks_bulan" json:"usia_maks_bulan"`

	// JarakMinimalHari: jarak minimal dari dosis sebelumnya (hari); nil = tidak ada.
	JarakMinimalHari *int16 `gorm:"column:jarak_minimal_hari" json:"jarak_minimal_hari"`

	// Keterangan: catatan khusus dosis, mis. "Kurang dari 24 jam setelah lahir".
	Keterangan string `gorm:"column:keterangan;type:text" json:"keterangan"`

	// JenisVaksin: relasi ke master jenis vaksin.
	JenisVaksin *JenisVaksin `gorm:"foreignKey:JenisVaksinID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"jenis_vaksin,omitempty"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (JadwalImunisasi) TableName() string { return "jadwal_imunisasi" }

func (m *JadwalImunisasi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}