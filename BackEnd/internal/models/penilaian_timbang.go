package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Status penimbangan (SKDN, Buku KIA).
const (
	StatusTimbangNaik      = "N" // naik, kenaikan BB >= Kenaikan Berat Badan Minimal (KBM)
	StatusTimbangTidakNaik = "T" // tidak naik, kenaikan BB < KBM
	StatusTimbangO         = "O" // bulan lalu tidak ditimbang, N/T tidak dapat ditentukan
	StatusTimbangBaru      = "B" // baru pertama kali ditimbang
)

// PenilaianTimbang adalah hasil penilaian satu penimbangan terhadap
// Kenaikan Berat Badan Minimal (KBM) sesuai Buku KIA.
//
// Tabel  : penilaian_timbang
// Kunci  : pengukuran_id unik, satu penilaian per pengukuran.
// Diisi  : otomatis setiap kader menyimpan pengukuran (service.KbmService).
//
// Aturan:
//   - N  : ditimbang bulan lalu dan kenaikan BB >= KBM sesuai usia.
//   - T  : ditimbang bulan lalu dan kenaikan BB < KBM (termasuk BB turun/tetap).
//   - O  : bulan lalu tidak ditimbang, sehingga N/T tidak dapat dinilai.
//   - B  : penimbangan pertama di posyandu.
//   - 2T : T bulan ini dan T bulan lalu berturut-turut.
//   - BGM: Bawah Garis Merah, BB/U < -3 SD.
type PenilaianTimbang struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey;column:id" json:"id"`
	PengukuranID uuid.UUID `gorm:"column:pengukuran_id;type:uuid;not null;uniqueIndex:ux_penilaian_timbang_pengukuran" json:"pengukuran_id"`
	AnakID       uuid.UUID `gorm:"column:anak_id;type:uuid;not null;index" json:"anak_id"`
	TanggalUkur  time.Time `gorm:"column:tanggal_ukur;type:date;not null;index" json:"tanggal_ukur"`
	UsiaBulan    int16     `gorm:"column:usia_bulan" json:"usia_bulan"`
	BbKg         float64   `gorm:"column:bb_kg;type:numeric(5,2)" json:"bb_kg"`

	// Penimbangan sebelumnya (nil bila belum pernah ditimbang).
	PengukuranSebelumnyaID *uuid.UUID `gorm:"column:pengukuran_sebelumnya_id;type:uuid" json:"pengukuran_sebelumnya_id"`
	BbSebelumnya           *float64   `gorm:"column:bb_sebelumnya;type:numeric(5,2)" json:"bb_sebelumnya"`
	TanggalSebelumnya      *time.Time `gorm:"column:tanggal_sebelumnya;type:date" json:"tanggal_sebelumnya"`
	SelisihBulan           *int16     `gorm:"column:selisih_bulan" json:"selisih_bulan"`

	KenaikanGram *int     `gorm:"column:kenaikan_gram" json:"kenaikan_gram"` // negatif bila turun
	KbmGram      *int     `gorm:"column:kbm_gram" json:"kbm_gram"`
	Status       string   `gorm:"column:status;size:1;index" json:"status"` // N | T | O | B
	DuaT         bool     `gorm:"column:dua_t;index" json:"dua_t"`
	Bgm          bool     `gorm:"column:bgm;index" json:"bgm"`
	ZBbu         *float64 `gorm:"column:z_bbu;type:numeric(5,2)" json:"z_bbu"`
	PerluRujuk   bool     `gorm:"column:perlu_rujuk;index" json:"perlu_rujuk"` // 2T atau BGM
	Keterangan   string   `gorm:"column:keterangan;type:text" json:"keterangan"`

	Pengukuran *Pengukuran `gorm:"foreignKey:PengukuranID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"-"`
	Anak       *Anak       `gorm:"foreignKey:AnakID;constraint:OnUpdate:CASCADE,OnDelete:RESTRICT" json:"-"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (PenilaianTimbang) TableName() string { return "penilaian_timbang" }

func (m *PenilaianTimbang) BeforeCreate(*gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}
