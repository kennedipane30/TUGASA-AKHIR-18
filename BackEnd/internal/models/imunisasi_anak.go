package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Sumber catatan imunisasi.
const (
	SumberImunisasiPosyandu = "posyandu"     // diberikan saat sesi posyandu (catatan bidan)
	SumberImunisasiLuar     = "luar"         // dicatat bidan: diberikan di RS/puskesmas/klinik/bidan praktik
	SumberImunisasiOrangTua = "laporan_ortu" // dilaporkan orang tua saat mendaftarkan anak
)

// Status konfirmasi catatan imunisasi.
const (
	KonfirmasiImunisasiOK       = "dikonfirmasi"
	KonfirmasiImunisasiMenunggu = "menunggu" // laporan orang tua, menunggu konfirmasi bidan
)

// Kondisi anak sebelum imunisasi di posyandu.
const (
	KondisiAnakSehat       = "sehat"
	KondisiAnakDemamRingan = "demam_ringan"
	KondisiAnakSakit       = "sakit" // imunisasi ditunda, tidak dapat disimpan
)

// ImunisasiAnak adalah riwayat vaksin yang sudah diberikan kepada seorang anak.
//
// Tabel : imunisasi_anak
// Diisi melalui tiga cara:
//  1. Sesi posyandu (form Catatan Bidan): Sumber = posyandu, PendaftaranID terisi.
//  2. Bidan mencatat vaksin dari luar posyandu: Sumber = luar.
//  3. Orang tua melaporkan vaksin saat mendaftarkan anak: Sumber = laporan_ortu,
//     StatusKonfirmasi = menunggu sampai bidan mengonfirmasi.
//
// Satu anak + satu jenis vaksin + satu dosis hanya boleh tercatat sekali.
// Usia anak saat divaksin dihitung dari TanggalPemberian dikurangi tanggal lahir.
type ImunisasiAnak struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// AnakID: anak penerima vaksin (FK ke anak).
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`

	// JenisVaksinID: vaksin yang diberikan (FK ke jenis_vaksin).
	JenisVaksinID uuid.UUID `gorm:"column:jenis_vaksin_id;type:uuid;not null;index" json:"jenis_vaksin_id"`

	// DosisKe: dosis ke berapa yang diberikan.
	DosisKe int16 `gorm:"column:dosis_ke;not null" json:"dosis_ke"`

	// TanggalPemberian: tanggal vaksin diberikan.
	TanggalPemberian time.Time `gorm:"column:tanggal_pemberian;type:date;not null" json:"tanggal_pemberian"`

	// Tempat: nama tempat / faskes, mis. "Posyandu Silimbat", "RSUD Porsea".
	Tempat string `gorm:"column:tempat;size:100" json:"tempat"`

	// Sumber: posyandu | luar | laporan_ortu.
	Sumber string `gorm:"column:sumber;size:20;not null;default:'posyandu'" json:"sumber"`

	// StatusKonfirmasi: dikonfirmasi | menunggu.
	StatusKonfirmasi string `gorm:"column:status_konfirmasi;size:20;not null;default:'dikonfirmasi'" json:"status_konfirmasi"`

	// NomorBatch: nomor batch vaksin (opsional).
	NomorBatch string `gorm:"column:nomor_batch;size:50" json:"nomor_batch"`

	// KondisiAnak: kondisi anak sebelum imunisasi (sehat | demam_ringan).
	KondisiAnak string `gorm:"column:kondisi_anak;type:text" json:"kondisi_anak"`

	// PemberiLuar: nama petugas pemberi vaksin di luar posyandu (opsional).
	PemberiLuar string `gorm:"column:pemberi_luar;size:100" json:"pemberi_luar"`

	// FotoBukti: nama file foto bukti vaksin dari luar (opsional).
	FotoBukti string `gorm:"column:foto_bukti;size:120" json:"foto_bukti"`

	// PendaftaranID: kunjungan posyandu saat vaksin diberikan; nil = vaksin dari luar.
	PendaftaranID *uuid.UUID `gorm:"column:pendaftaran_id;type:uuid;index" json:"pendaftaran_id"`

	// DiberikanOleh: user yang mencatat (bidan, atau orang tua untuk laporan).
	DiberikanOleh uint `gorm:"column:diberikan_oleh;not null;index" json:"diberikan_oleh"`

	// DikonfirmasiOleh / DikonfirmasiPada: bidan yang mengonfirmasi catatan.
	DikonfirmasiOleh *uint      `gorm:"column:dikonfirmasi_oleh" json:"dikonfirmasi_oleh,omitempty"`
	DikonfirmasiPada *time.Time `gorm:"column:dikonfirmasi_pada" json:"dikonfirmasi_pada,omitempty"`

	// Reaksi setelah imunisasi (KIPI).
	ReaksiKipi         string     `gorm:"column:reaksi_kipi;type:text" json:"reaksi_kipi"`
	KipiDilaporkanPada *time.Time `gorm:"column:kipi_dilaporkan_pada" json:"kipi_dilaporkan_pada,omitempty"`
	KipiTindakLanjut   string     `gorm:"column:kipi_tindak_lanjut;type:text" json:"kipi_tindak_lanjut"`
	KipiDitanganiOleh  *uint      `gorm:"column:kipi_ditangani_oleh" json:"kipi_ditangani_oleh,omitempty"`
	KipiDitanganiPada  *time.Time `gorm:"column:kipi_ditangani_pada" json:"kipi_ditangani_pada,omitempty"`

	// Catatan: catatan tambahan (opsional).
	Catatan string `gorm:"column:catatan;type:text" json:"catatan"`

	// Relasi
	Anak              *Anak        `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	JenisVaksin       *JenisVaksin `gorm:"foreignKey:JenisVaksinID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"jenis_vaksin,omitempty"`
	Pendaftaran       *Pendaftaran `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DiberikanOlehUser *User        `gorm:"foreignKey:DiberikanOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`

	// Sinkronisasi offline-first
	Version       int        `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ImunisasiAnak) TableName() string { return "imunisasi_anak" }

func (m *ImunisasiAnak) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	if m.Sumber == "" {
		if m.PendaftaranID != nil {
			m.Sumber = SumberImunisasiPosyandu
		} else {
			m.Sumber = SumberImunisasiLuar
		}
	}
	if m.StatusKonfirmasi == "" {
		m.StatusKonfirmasi = KonfirmasiImunisasiOK
	}
	return nil
}

// SumberEfektif: data lama tanpa kolom sumber dibaca dari ada/tidaknya PendaftaranID.
func (m *ImunisasiAnak) SumberEfektif() string {
	if m.PendaftaranID != nil {
		return SumberImunisasiPosyandu
	}
	if m.Sumber == "" || m.Sumber == SumberImunisasiPosyandu {
		return SumberImunisasiLuar
	}
	return m.Sumber
}