package models

import "time"

type Keluarga struct {
	ID     uint `gorm:"primaryKey" json:"id"`
	UserID uint `gorm:"not null;uniqueIndex" json:"user_id"`

	// Ibu / wali
	TanpaIbu     bool       `gorm:"default:false" json:"tanpa_ibu"`
	TglLahirIbu  *time.Time `gorm:"type:date" json:"tgl_lahir_ibu"`
	PekerjaanIbu string     `gorm:"size:100" json:"pekerjaan_ibu"`
	Alamat       string     `gorm:"type:text" json:"alamat"`
	RT           string     `gorm:"size:3" json:"rt"`
	RW           string     `gorm:"size:3" json:"rw"`
	
	// BARIS POSYANDU SUDAH DIHAPUS DARI SINI

	// Ayah
	TanpaAyah bool  `gorm:"default:false" json:"tanpa_ayah"`
	Ayah      *Ayah `gorm:"foreignKey:KeluargaID;constraint:OnDelete:CASCADE" json:"ayah,omitempty"`

	Anak []Anak `gorm:"foreignKey:KeluargaID;constraint:OnDelete:CASCADE" json:"anak"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Keluarga) TableName() string { return "keluarga" }

type StatusKeluarga struct {
	IbuLengkap     bool `json:"ibu_lengkap"`
	AyahLengkap    bool `json:"ayah_lengkap"`
	AnakLengkap    bool `json:"anak_lengkap"`
	LangkahSelesai int  `json:"langkah_selesai"`
	Lengkap        bool `json:"lengkap"`
}

func (k *Keluarga) Status() StatusKeluarga {
	s := StatusKeluarga{
		// Lengkap asalkan tanpa ibu dicentang ATAU data alamat/tgl lahir diisi
		IbuLengkap: k.TanpaIbu || (k.TglLahirIbu != nil && k.Alamat != "" && k.RW != ""),
		AyahLengkap: k.TanpaAyah || (k.Ayah != nil && k.Ayah.Nama != ""),
		AnakLengkap: len(k.Anak) > 0,
	}
	for _, b := range []bool{s.IbuLengkap, s.AyahLengkap, s.AnakLengkap} {
		if b {
			s.LangkahSelesai++
		}
	}
	s.Lengkap = s.LangkahSelesai == 3
	return s
}

type Ayah struct {
	ID         uint       `gorm:"primaryKey" json:"id"`
	KeluargaID uint       `gorm:"not null;uniqueIndex" json:"keluarga_id"`
	Nama       string     `gorm:"size:100;not null" json:"nama"`
	NIK        string     `gorm:"size:16" json:"nik"`
	TglLahir   *time.Time `gorm:"type:date" json:"tgl_lahir"`
	NoHP       string     `gorm:"size:20" json:"no_hp"`
	Pekerjaan  string     `gorm:"size:100" json:"pekerjaan"`
}

func (Ayah) TableName() string { return "ayah" }