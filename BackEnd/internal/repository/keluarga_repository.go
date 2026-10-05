package repository

import (
	"errors"
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type KeluargaRepository struct{ db *gorm.DB }

func NewKeluargaRepository(db *gorm.DB) *KeluargaRepository {
	return &KeluargaRepository{db}
}

type KeluargaData struct {
	Keluarga *models.Keluarga  `json:"keluarga"`
	Ibu      *models.OrangTua  `json:"ibu"`
	Ayah     *models.OrangTua  `json:"ayah"`
	Anak     []models.Anak     `json:"anak"`
}

type ProfilData struct {
	Alamat       string
	RT           string
	RW           string
	TanpaAyah    bool
	TglLahirIbu  *time.Time
	PekerjaanIbu string
	Ayah         *models.OrangTua
}

func (r *KeluargaRepository) GetByUser(uid uint) (*KeluargaData, error) {
	var ibu models.OrangTua
	err := r.db.Where("user_id = ?", uid).First(&ibu).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return &KeluargaData{Anak: []models.Anak{}}, nil
	}
	if err != nil {
		return nil, err
	}

	var k models.Keluarga
	if err := r.db.First(&k, "id = ?", ibu.KeluargaID).Error; err != nil {
		return nil, err
	}

	data := &KeluargaData{Keluarga: &k, Ibu: &ibu, Anak: []models.Anak{}}

	var ayah models.OrangTua
	err = r.db.Where("keluarga_id = ? AND peran_keluarga = ?", k.ID, "ayah").First(&ayah).Error
	if err == nil {
		data.Ayah = &ayah
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	if err := r.db.Where("keluarga_id = ?", k.ID).Order("tanggal_lahir").Find(&data.Anak).Error; err != nil {
		return nil, err
	}
	return data, nil
}

func (r *KeluargaRepository) ensure(tx *gorm.DB, uid uint) (*models.Keluarga, *models.OrangTua, error) {
	var ibu models.OrangTua
	err := tx.Where("user_id = ?", uid).First(&ibu).Error
	if err == nil {
		var k models.Keluarga
		if err := tx.First(&k, "id = ?", ibu.KeluargaID).Error; err != nil {
			return nil, nil, err
		}
		return &k, &ibu, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil, err
	}

	var u models.User
	if err := tx.First(&u, uid).Error; err != nil {
		return nil, nil, err
	}

	k := &models.Keluarga{}
	if err := tx.Create(k).Error; err != nil {
		return nil, nil, err
	}

	id := uid
	ibu = models.OrangTua{
		KeluargaID:    k.ID,
		UserID:        &id,
		PeranKeluarga: "ibu",
		Nama:          u.Nama,
		NIK:           u.NIK,
	}
	if u.NoHP != nil {
		ibu.NoHP = *u.NoHP
	}
	if err := tx.Create(&ibu).Error; err != nil {
		return nil, nil, err
	}
	return k, &ibu, nil
}

func (r *KeluargaRepository) PastikanKeluarga(uid uint) (uuid.UUID, error) {
	var kid uuid.UUID
	err := r.db.Transaction(func(tx *gorm.DB) error {
		k, _, err := r.ensure(tx, uid)
		if err != nil {
			return err
		}
		kid = k.ID
		return nil
	})
	return kid, err
}

func (r *KeluargaRepository) SimpanProfil(uid uint, p ProfilData) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		k, ibu, err := r.ensure(tx, uid)
		if err != nil {
			return err
		}

		k.Alamat = p.Alamat
		k.RT = p.RT
		k.RW = p.RW
		k.TanpaAyah = p.TanpaAyah
		if err := tx.Save(k).Error; err != nil {
			return err
		}

		ibu.TanggalLahir = p.TglLahirIbu
		ibu.Pekerjaan = p.PekerjaanIbu
		if err := tx.Save(ibu).Error; err != nil {
			return err
		}

		if p.TanpaAyah || p.Ayah == nil {
			return tx.Where("keluarga_id = ? AND peran_keluarga = ?", k.ID, "ayah").
				Delete(&models.OrangTua{}).Error
		}

		var ada models.OrangTua
		err = tx.Where("keluarga_id = ? AND peran_keluarga = ?", k.ID, "ayah").First(&ada).Error
		if err == nil {
			ada.Nama = p.Ayah.Nama
			ada.NIK = p.Ayah.NIK
			ada.TanggalLahir = p.Ayah.TanggalLahir
			ada.NoHP = p.Ayah.NoHP
			ada.Pekerjaan = p.Ayah.Pekerjaan
			return tx.Save(&ada).Error
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		p.Ayah.KeluargaID = k.ID
		p.Ayah.PeranKeluarga = "ayah"
		return tx.Create(p.Ayah).Error
	})
}

func (r *KeluargaRepository) TambahAnak(a *models.Anak) error { return r.db.Create(a).Error }

func (r *KeluargaRepository) UbahAnak(a *models.Anak) error {
	res := r.db.Model(&models.Anak{}).
		Where("id = ? AND keluarga_id = ?", a.ID, a.KeluargaID).
		Select("nama", "nik", "tanggal_lahir", "jenis_kelamin", "berat_lahir_kg", "panjang_lahir_cm").
		Updates(a)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *KeluargaRepository) HapusAnak(id, keluargaID uuid.UUID) error {
	return r.db.Where("id = ? AND keluarga_id = ?", id, keluargaID).
		Delete(&models.Anak{}).Error
}

func (r *KeluargaRepository) FindIbuByUser(uid uint) (*models.OrangTua, error) {
	var ibu models.OrangTua
	err := r.db.Where("user_id = ?", uid).First(&ibu).Error
	return &ibu, err
}

func (r *KeluargaRepository) ListAnak(keluargaID uuid.UUID) ([]models.Anak, error) {
	list := []models.Anak{}
	err := r.db.Where("keluarga_id = ?", keluargaID).Order("tanggal_lahir").Find(&list).Error
	return list, err
}