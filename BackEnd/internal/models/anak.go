package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Status riwayat imunisasi anak sebelum dilayani di posyandu.
//
//	belum_ditanya    : orang tua belum mengisi riwayat imunisasi (data lama / walk-in).
//	belum_pernah     : orang tua menyatakan anak belum pernah diimunisasi.
//	dilaporkan       : orang tua melaporkan imunisasi yang sudah diterima di luar posyandu.
//	perlu_ditanyakan : orang tua lupa / tidak tahu, bidan wajib menanyakan.
//	dikonfirmasi     : bidan sudah mengonfirmasi riwayat langsung ke orang tua.
//
// Imunisasi di posyandu hanya boleh diberikan bila status = dikonfirmasi.
const (
	RiwayatImunisasiBelumDitanya    = "belum_ditanya"
	RiwayatImunisasiBelumPernah     = "belum_pernah"
	RiwayatImunisasiDilaporkan      = "dilaporkan"
	RiwayatImunisasiPerluDitanyakan = "perlu_ditanyakan"
	RiwayatImunisasiDikonfirmasi    = "dikonfirmasi"
)

// Status data anak di posyandu.
//
//	aktif : balita yang dilayani posyandu.
//	arsip : tidak dilayani lagi; riwayat tetap tersimpan dan dapat dilihat.
//	        Diarsipkan kader (pindah, meninggal, lainnya) atau otomatis oleh
//	        sistem saat anak berusia 60 bulan (lulus balita).
const (
	StatusAnakAktif = "aktif"
	StatusAnakArsip = "arsip"
)

// Alasan arsip (disimpan di alasan_arsip, boleh diikuti ": keterangan").
const (
	AlasanArsipLulus     = "Lulus balita (usia 5 tahun)"
	AlasanArsipPindah    = "Pindah domisili"
	AlasanArsipMeninggal = "Meninggal"
	AlasanArsipLainnya   = "Lainnya"
)

// Anak: data identitas balita.
type Anak struct {
	ID             uuid.UUID  `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	KeluargaID     uuid.UUID  `gorm:"column:keluarga_id;type:uuid;not null;index" json:"keluarga_id"`
	Keluarga       *Keluarga  `gorm:"foreignKey:KeluargaID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	NIK            *string    `gorm:"column:nik;size:16;uniqueIndex:ux_anak_nik,where:deleted_at IS NULL" json:"nik,omitempty"`
	Nama           string     `gorm:"column:nama;size:100;not null" json:"nama"`
	TanggalLahir   time.Time  `gorm:"column:tanggal_lahir;type:date;not null" json:"tanggal_lahir"`
	JenisKelamin   string     `gorm:"column:jenis_kelamin;size:1;not null" json:"jenis_kelamin"` // L | P
	BeratLahirKg   *float64   `gorm:"column:berat_lahir_kg;type:numeric(4,2)" json:"berat_lahir_kg"`
	PanjangLahirCm *float64   `gorm:"column:panjang_lahir_cm;type:numeric(4,1)" json:"panjang_lahir_cm"`
	KodeQR         string     `gorm:"column:kode_qr;size:64;not null;uniqueIndex:ux_anak_kode_qr" json:"kode_qr"`
	Status         string     `gorm:"column:status;size:10;default:aktif" json:"status"` // StatusAnakAktif | StatusAnakArsip
	TanggalArsip   *time.Time `gorm:"column:tanggal_arsip;type:date" json:"tanggal_arsip,omitempty"`
	AlasanArsip    string     `gorm:"column:alasan_arsip;size:100" json:"alasan_arsip,omitempty"`

	// Riwayat imunisasi sebelum posyandu: dicatat bidan pada kunjungan pertama.
	StatusRiwayatImunisasi     string     `gorm:"column:status_riwayat_vaksin;size:20;not null;default:'belum_ditanya'" json:"status_riwayat_vaksin"`
	RiwayatDikonfirmasiOleh *uint      `gorm:"column:riwayat_dikonfirmasi_oleh" json:"riwayat_dikonfirmasi_oleh,omitempty"`
	RiwayatDikonfirmasiPada *time.Time `gorm:"column:riwayat_dikonfirmasi_pada" json:"riwayat_dikonfirmasi_pada,omitempty"`

	Version       int            `gorm:"column:version;default:1" json:"version"`
	PerangkatAsal *uuid.UUID     `gorm:"column:perangkat_asal;type:uuid" json:"perangkat_asal,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `gorm:"index" json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Anak) TableName() string { return "anak" }

func (a *Anak) BeforeCreate(*gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	if a.KodeQR == "" {
		a.KodeQR = "PSY-" + a.ID.String()
	}
	if a.StatusRiwayatImunisasi == "" {
		a.StatusRiwayatImunisasi = RiwayatImunisasiBelumDitanya
	}
	return nil
}

// RiwayatImunisasiDikonfirmasi: true bila bidan sudah mengonfirmasi riwayat imunisasi anak.
func (a *Anak) RiwayatImunisasiSudahDikonfirmasi() bool {
	return a.StatusRiwayatImunisasi == RiwayatImunisasiDikonfirmasi
}