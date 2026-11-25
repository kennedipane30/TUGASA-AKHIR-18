package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KPSP (Kuesioner Pra Skrining Perkembangan) adalah skrining perkembangan anak
// yang diisi bidan saat sesi posyandu. Satu lembar KPSP berisi 10 pertanyaan
// untuk kelompok umur tertentu; bidan menjawab Ya/Tidak pada setiap pertanyaan.
//
// Penilaian mengikuti pedoman SDIDTK Kemenkes:
//
//	jumlah jawaban "Ya" 9-10  -> Sesuai (S)
//	jumlah jawaban "Ya" 7-8   -> Meragukan (M)
//	jumlah jawaban "Ya" <= 6  -> Kemungkinan ada Penyimpangan (P)
//
// Tiga tabel:
//
//	pertanyaan_kpsp  master 10 pertanyaan per kelompok umur (data acuan)
//	hasil_kpsp       satu lembar KPSP milik satu kunjungan posyandu
//	jawaban_kpsp     jawaban Ya/Tidak per nomor pertanyaan

// Hasil penilaian KPSP.
const (
	KpspSesuai       = "sesuai"
	KpspMeragukan    = "meragukan"
	KpspPenyimpangan = "penyimpangan"
)

// Aspek perkembangan yang dinilai KPSP.
const (
	AspekGerakKasar  = "gerak_kasar"
	AspekGerakHalus  = "gerak_halus"
	AspekBicara      = "bicara"
	AspekSosialisasi = "sosialisasi"
)

// UsiaKpsp adalah kelompok umur skrining KPSP dalam bulan:
// tiap 3 bulan sampai umur 24 bulan, lalu tiap 6 bulan sampai 72 bulan.
var UsiaKpsp = []int16{3, 6, 9, 12, 15, 18, 21, 24, 30, 36, 42, 48, 54, 60, 66, 72}

// KelompokUsiaKpsp memilih lembar KPSP yang dipakai untuk anak berumur
// usiaBulan. Sesuai pedoman, bila umur anak belum mencapai kelompok berikutnya,
// yang dipakai adalah kelompok umur terdekat yang lebih muda.
//
// Mengembalikan (0, false) bila anak belum berumur 3 bulan atau sudah lewat
// 72 bulan, yaitu di luar jangkauan KPSP.
func KelompokUsiaKpsp(usiaBulan int) (int16, bool) {
	if usiaBulan < 3 || usiaBulan > 72 {
		return 0, false
	}
	pilih := UsiaKpsp[0]
	for _, u := range UsiaKpsp {
		if int(u) <= usiaBulan {
			pilih = u
			continue
		}
		break
	}
	return pilih, true
}

// HitungHasilKpsp menerjemahkan jumlah jawaban "Ya" menjadi hasil S/M/P.
func HitungHasilKpsp(jumlahYa int) string {
	switch {
	case jumlahYa >= 9:
		return KpspSesuai
	case jumlahYa >= 7:
		return KpspMeragukan
	default:
		return KpspPenyimpangan
	}
}

// ---------------------------------------------------------------------------

// PertanyaanKpsp adalah master pertanyaan KPSP per kelompok umur.
// Diisi sekali lewat seed, tidak diubah dari aplikasi.
//
// Tabel : pertanyaan_kpsp
type PertanyaanKpsp struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// UsiaBulan: kelompok umur lembar KPSP (lihat UsiaKpsp).
	UsiaBulan int16 `gorm:"column:usia_bulan;not null;uniqueIndex:ux_pertanyaan_kpsp" json:"usia_bulan"`

	// Nomor: nomor urut pertanyaan 1-10 dalam satu lembar.
	Nomor int16 `gorm:"column:nomor;not null;uniqueIndex:ux_pertanyaan_kpsp" json:"nomor"`

	// Aspek: aspek perkembangan yang dinilai (lihat konstanta Aspek*).
	Aspek string `gorm:"column:aspek;size:20;not null" json:"aspek"`

	// Pertanyaan: bunyi pertanyaan yang dibacakan kepada orang tua.
	Pertanyaan string `gorm:"column:pertanyaan;type:text;not null" json:"pertanyaan"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (PertanyaanKpsp) TableName() string { return "pertanyaan_kpsp" }

func (m *PertanyaanKpsp) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}

// ---------------------------------------------------------------------------

// HasilKpsp adalah satu lembar KPSP yang diisi bidan pada satu kunjungan.
//
// Tabel : hasil_kpsp
type HasilKpsp struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// AnakID: anak yang diskrining (FK ke anak).
	AnakID uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`

	// PendaftaranID: kunjungan posyandu saat KPSP diisi (FK ke pendaftaran).
	PendaftaranID *uuid.UUID `gorm:"column:pendaftaran_id;type:uuid;index" json:"pendaftaran_id"`

	// UsiaBulan: kelompok umur lembar KPSP yang dipakai.
	UsiaBulan int16 `gorm:"column:usia_bulan;not null" json:"usia_bulan"`

	// JumlahYa: banyaknya jawaban "Ya", 0-10.
	JumlahYa int16 `gorm:"column:jumlah_ya;not null" json:"jumlah_ya"`

	// Hasil: sesuai | meragukan | penyimpangan, dihitung dari JumlahYa.
	Hasil string `gorm:"column:hasil;size:20;not null;index" json:"hasil"`

	// Tanggal: tanggal skrining dilakukan.
	Tanggal time.Time `gorm:"column:tanggal;type:date;not null;index" json:"tanggal"`

	// Catatan: catatan bidan atas hasil skrining (opsional).
	Catatan string `gorm:"column:catatan;type:text" json:"catatan"`

	// DicatatOleh: user bidan yang mengisi (FK ke users).
	DicatatOleh uint `gorm:"column:dicatat_oleh;not null;index" json:"dicatat_oleh"`

	// Relasi
	Anak           *Anak         `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Pendaftaran    *Pendaftaran  `gorm:"foreignKey:PendaftaranID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DicatatOlehUser *User        `gorm:"foreignKey:DicatatOleh;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Jawaban        []JawabanKpsp `gorm:"foreignKey:HasilKpspID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"jawaban,omitempty"`

	// Sinkronisasi offline-first
	Version       int        `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal *uuid.UUID `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`

	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `gorm:"index" json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (HasilKpsp) TableName() string { return "hasil_kpsp" }

func (m *HasilKpsp) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}

// ---------------------------------------------------------------------------

// JawabanKpsp adalah jawaban Ya/Tidak untuk satu nomor pertanyaan.
//
// Tabel : jawaban_kpsp
type JawabanKpsp struct {
	// ID: kunci utama (UUID).
	ID uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`

	// HasilKpspID: lembar KPSP pemilik jawaban ini (FK ke hasil_kpsp).
	HasilKpspID uuid.UUID `gorm:"column:hasil_kpsp_id;type:uuid;not null;uniqueIndex:ux_jawaban_kpsp" json:"hasil_kpsp_id"`

	// Nomor: nomor pertanyaan 1-10.
	Nomor int16 `gorm:"column:nomor;not null;uniqueIndex:ux_jawaban_kpsp" json:"nomor"`

	// Ya: true bila bidan menjawab "Ya".
	Ya bool `gorm:"column:ya;not null" json:"ya"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (JawabanKpsp) TableName() string { return "jawaban_kpsp" }

func (m *JawabanKpsp) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}