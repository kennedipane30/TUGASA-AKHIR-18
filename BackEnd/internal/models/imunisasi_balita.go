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
	SumberImunisasiOrangTua = "laporan_ortu" // dilaporkan orang tua saat mendaftarkan balita
)

// Status konfirmasi catatan imunisasi.
const (
	KonfirmasiImunisasiOK       = "dikonfirmasi"
	KonfirmasiImunisasiMenunggu = "menunggu" // laporan orang tua, menunggu konfirmasi bidan
)

// Kondisi balita sebelum imunisasi di posyandu.
const (
	KondisiBalitaSehat       = "sehat"
	KondisiBalitaDemamRingan = "demam_ringan"
	KondisiBalitaSakit       = "sakit" // imunisasi ditunda, tidak dapat disimpan
)

// ImunisasiBalita adalah riwayat imunisasi yang sudah diberikan kepada seorang balita.
//
// Tabel : imunisasi_balita
// Diisi melalui tiga cara:
//  1. Sesi posyandu (form Catatan Bidan): Sumber = posyandu, PendaftaranID terisi.
//  2. Bidan mencatat imunisasi dari luar posyandu: Sumber = luar.
//  3. Orang tua melaporkan imunisasi saat mendaftarkan balita: Sumber = laporan_ortu,
//     StatusKonfirmasi = menunggu sampai bidan mengonfirmasi.
//
// Satu balita + satu jenis imunisasi + satu dosis hanya boleh tercatat sekali.
// Usia balita saat diimunisasi dihitung dari TanggalPemberian dikurangi tanggal lahir.
type ImunisasiBalita struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// BalitaID: balita penerima imunisasi (FK ke balita).
	BalitaID uuid.UUID `gorm:"column:balita_id;type:uuid;not null;index" json:"balita_id"`

	// JenisImunisasiID: imunisasi yang diberikan (FK ke jenis_imunisasi).
	JenisImunisasiID uuid.UUID `gorm:"column:jenis_imunisasi_id;type:uuid;not null;index" json:"jenis_imunisasi_id"`

	// DosisKe: dosis ke berapa yang diberikan.
	DosisKe int16 `gorm:"column:dosis_ke;not null" json:"dosis_ke"`

	// TanggalPemberian: tanggal imunisasi diberikan.
	TanggalPemberian time.Time `gorm:"column:tanggal_pemberian;type:date;not null" json:"tanggal_pemberian"`

	// Tempat: nama tempat / faskes, mis. "Posyandu Silimbat", "RSUD Porsea".
	Tempat string `gorm:"column:tempat;size:100" json:"tempat"`

	// Sumber: posyandu | luar | laporan_ortu.
	Sumber string `gorm:"column:sumber;size:20;not null;default:'posyandu'" json:"sumber"`

	// StatusKonfirmasi: dikonfirmasi | menunggu.
	StatusKonfirmasi string `gorm:"column:status_konfirmasi;size:20;not null;default:'dikonfirmasi'" json:"status_konfirmasi"`

	// NomorBatch: nomor batch imunisasi (opsional).
	NomorBatch string `gorm:"column:nomor_batch;size:50" json:"nomor_batch"`

	// KondisiBalita: kondisi balita sebelum imunisasi (sehat | demam_ringan).
	KondisiBalita string `gorm:"column:kondisi_balita;type:text" json:"kondisi_balita"`

	// PemberiLuar: nama petugas pemberi imunisasi di luar posyandu (opsional).
	PemberiLuar string `gorm:"column:pemberi_luar;size:100" json:"pemberi_luar"`

	// FotoBukti: nama file foto bukti imunisasi dari luar (opsional).
	FotoBukti string `gorm:"column:foto_bukti;size:120" json:"foto_bukti"`

	// PendaftaranID: kunjungan posyandu saat imunisasi diberikan; nil = imunisasi dari luar.
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
	Balita            *Balita         `gorm:"foreignKey:BalitaID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	JenisImunisasi    *JenisImunisasi `gorm:"foreignKey:JenisImunisasiID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"jenis_imunisasi,omitempty"`
	Pendaftaran       *Pendaftaran    `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DiberikanOlehUser *User           `gorm:"foreignKey:DiberikanOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`

	// Sinkronisasi offline-first
	Version       int        `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `gorm:"index" json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (ImunisasiBalita) TableName() string { return "imunisasi_balita" }

func (m *ImunisasiBalita) BeforeCreate(*gorm.DB) error {
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
func (m *ImunisasiBalita) SumberEfektif() string {
	if m.PendaftaranID != nil {
		return SumberImunisasiPosyandu
	}
	if m.Sumber == "" || m.Sumber == SumberImunisasiPosyandu {
		return SumberImunisasiLuar
	}
	return m.Sumber
}