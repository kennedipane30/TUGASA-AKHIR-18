package repository

import (
	"errors"
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type KeluargaRepository struct{ db *gorm.DB }

func NewKeluargaRepository(db *gorm.DB) *KeluargaRepository {
	return &KeluargaRepository{db}
}

type KeluargaData struct {
	Keluarga *models.Keluarga `json:"keluarga"`
	Ibu      *models.OrangTua `json:"ibu"`
	Ayah     *models.OrangTua `json:"ayah"`
	Anak     []models.Anak    `json:"anak"`
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

// ---------------------------------------------------------------- baca

func (r *KeluargaRepository) FindIbuByUser(uid uint) (*models.OrangTua, error) {
	var ibu models.OrangTua
	err := r.db.Where("user_id = ?", uid).First(&ibu).Error
	return &ibu, err
}

func (r *KeluargaRepository) GetKeluarga(id uuid.UUID) (*models.Keluarga, error) {
	var k models.Keluarga
	err := r.db.First(&k, "id = ?", id).Error
	return &k, err
}

func (r *KeluargaRepository) ListAnak(keluargaID uuid.UUID) ([]models.Anak, error) {
	list := []models.Anak{}
	err := r.db.Where("keluarga_id = ?", keluargaID).Order("tanggal_lahir").Find(&list).Error
	return list, err
}

func (r *KeluargaRepository) GetByUser(uid uint) (*KeluargaData, error) {
	ibu, err := r.FindIbuByUser(uid)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return &KeluargaData{Anak: []models.Anak{}}, nil
	}
	if err != nil {
		return nil, err
	}

	k, err := r.GetKeluarga(ibu.KeluargaID)
	if err != nil {
		return nil, err
	}

	data := &KeluargaData{Keluarga: k, Ibu: ibu, Anak: []models.Anak{}}

	var ayah models.OrangTua
	err = r.db.Where("keluarga_id = ? AND peran_keluarga = ?", k.ID, "ayah").First(&ayah).Error
	if err == nil {
		data.Ayah = &ayah
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	anak, err := r.ListAnak(k.ID)
	if err != nil {
		return nil, err
	}
	data.Anak = anak
	return data, nil
}

// ---------------------------------------------------------------- tulis

// ensure memastikan akun orang tua punya baris keluarga dan baris ibu.
// Keluarga selalu dibuat lebih dulu, lalu ibu memakai ID keluarga yang sudah tersimpan.
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
	if u.Posyandu == "" {
		return nil, nil, errors.New("akun belum terhubung ke posyandu")
	}

	k := &models.Keluarga{ID: uuid.New(), Posyandu: u.Posyandu}
	if err := tx.Omit(clause.Associations).Create(k).Error; err != nil {
		return nil, nil, err
	}

	// pastikan baris keluarga benar-benar ada sebelum ibu dibuat
	var cek models.Keluarga
	if err := tx.First(&cek, "id = ?", k.ID).Error; err != nil {
		return nil, nil, err
	}

	id := uid
	ibu = models.OrangTua{
		ID:            uuid.New(),
		KeluargaID:    cek.ID,
		UserID:        &id,
		PeranKeluarga: "ibu",
		Nama:          u.Nama,
		NIK:           u.NIK,
	}
	if u.NoHP != nil {
		ibu.NoHP = *u.NoHP
	}
	if err := tx.Omit(clause.Associations).Create(&ibu).Error; err != nil {
		return nil, nil, err
	}
	return &cek, &ibu, nil
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
		if err := tx.Omit(clause.Associations).Save(k).Error; err != nil {
			return err
		}

		ibu.TanggalLahir = p.TglLahirIbu
		ibu.Pekerjaan = p.PekerjaanIbu
		if err := tx.Omit(clause.Associations).Save(ibu).Error; err != nil {
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
			return tx.Omit(clause.Associations).Save(&ada).Error
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		ayah := *p.Ayah
		ayah.ID = uuid.New()
		ayah.KeluargaID = k.ID
		ayah.PeranKeluarga = "ayah"
		ayah.UserID = nil
		return tx.Omit(clause.Associations).Create(&ayah).Error
	})
}

// ---------------------------------------------------------------- anak

func (r *KeluargaRepository) TambahAnak(a *models.Anak) error {
	return r.db.Omit(clause.Associations).Create(a).Error
}

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

func (r *KeluargaRepository) AnakSudahAda(keluargaID uuid.UUID, nama string, tgl time.Time, kecuali uuid.UUID) bool {
	var n int64
	q := r.db.Model(&models.Anak{}).
		Where("keluarga_id = ? AND LOWER(nama) = LOWER(?) AND tanggal_lahir = ?", keluargaID, nama, tgl.Format("2006-01-02"))
	if kecuali != uuid.Nil {
		q = q.Where("id <> ?", kecuali)
	}
	q.Count(&n)
	return n > 0
}

func (r *KeluargaRepository) NIKAnakSudahAda(nik string, kecuali uuid.UUID) bool {
	var n int64
	q := r.db.Model(&models.Anak{}).Where("nik = ?", nik)
	if kecuali != uuid.Nil {
		q = q.Where("id <> ?", kecuali)
	}
	q.Count(&n)
	return n > 0
}