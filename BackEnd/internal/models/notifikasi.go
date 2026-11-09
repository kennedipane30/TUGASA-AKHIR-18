package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

const (
	NotifJadwalBaru       = "jadwal_baru"
	NotifJadwalDiubah     = "jadwal_diubah"
	NotifJadwalDibatalkan = "jadwal_dibatalkan"
	NotifPengingatJadwal  = "pengingat_jadwal"
	NotifCheckinDibuka    = "checkin_dibuka"

	// NotifPeringatanTimbang: anak 2T (tidak naik 2 bulan berturut-turut) atau BGM
	// (bawah garis merah); dikirim ke bidan posyandu anak dan orang tuanya.
	NotifPeringatanTimbang = "peringatan_timbang"

	// NotifHasilTimbang: hasil penimbangan (bukan 2T/BGM) ke orang tua.
	NotifHasilTimbang = "hasil_timbang"

	// Pengingat kesehatan anak (imunisasi, Vitamin A, obat cacing); tanpa tabel baru.
	// NotifRencanaPosyandu: rencana per anak saat jadwal dibuat/diubah/dipindah karena batal.
	NotifRencanaPosyandu = "rencana_posyandu"
	// NotifPengingatImunisasi: H-3 sebelum posyandu yang berisi imunisasi.
	NotifPengingatImunisasi = "pengingat_imunisasi"
	// NotifPengingatSuplemen: H-3 sebelum posyandu yang hanya berisi Vitamin A / obat cacing.
	NotifPengingatSuplemen = "pengingat_suplemen"
	// NotifImunisasiTerlambat: sekali saat terdeteksi, lalu H-1 maksimal 3 kali.
	NotifImunisasiTerlambat = "imunisasi_terlambat"
	// NotifImunisasiFaskes: harus ke puskesmas/faskes (HB0 atau mendekati batas usia).
	NotifImunisasiFaskes = "imunisasi_faskes"
	// NotifJadwalBelumAda: ke sekretaris dan bidan bila jadwal posyandu berikutnya belum dibuat.
	NotifJadwalBelumAda = "jadwal_belum_ada"
	// NotifLaporanKipi: orang tua melaporkan reaksi setelah imunisasi (hanya ke bidan).
	NotifLaporanKipi = "laporan_kipi"
)

// Notifikasi: Notifikasi dan pengingat per pengguna beserta status baca.
// Kunci: penanda unik per pengguna agar notifikasi yang sama tidak terkirim dua kali.
type Notifikasi struct {
	ID              uuid.UUID      `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	UserID          uint           `gorm:"column:user_id;not null;index;uniqueIndex:ux_notifikasi_user_kunci,where:kunci <> ''" json:"user_id"`
	Kunci           string         `gorm:"column:kunci;size:150;not null;default:'';uniqueIndex:ux_notifikasi_user_kunci,where:kunci <> ''" json:"-"`
	Jenis           string         `gorm:"column:jenis;size:40" json:"jenis"`
	Judul           string         `gorm:"column:judul;size:150;not null" json:"judul"`
	Isi             string         `gorm:"column:isi;type:text" json:"isi"`
	PengumumanID    *uuid.UUID     `gorm:"column:pengumuman_id;type:uuid;index" json:"pengumuman_id"`
	ObjekTabel      string         `gorm:"column:objek_tabel;size:40" json:"objek_tabel"`
	ObjekID         *uuid.UUID     `gorm:"column:objek_id;type:uuid" json:"objek_id"`
	DikirimOleh     *uint          `gorm:"column:dikirim_oleh;index" json:"dikirim_oleh"`
	DikirimPada     *time.Time     `gorm:"column:dikirim_pada" json:"dikirim_pada"`
	SudahDibaca     bool           `gorm:"column:sudah_dibaca" json:"sudah_dibaca"`
	DibacaPada      *time.Time     `gorm:"column:dibaca_pada" json:"dibaca_pada"`
	User            *User          `gorm:"foreignKey:UserID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`
	Pengumuman      *Pengumuman    `gorm:"foreignKey:PengumumanID;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	DikirimOlehUser *User          `gorm:"foreignKey:DikirimOleh;constraint:OnUpdate:CASCADE,OnDelete:SET NULL" json:"-"`
	Version         int            `gorm:"default:1;column:version" json:"version"`
	PerangkatAsal   *uuid.UUID     `gorm:"type:uuid;column:perangkat_asal" json:"perangkat_asal,omitempty"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}

func (Notifikasi) TableName() string { return "notifikasi" }

func (m *Notifikasi) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}