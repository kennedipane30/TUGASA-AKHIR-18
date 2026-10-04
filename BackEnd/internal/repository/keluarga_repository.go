package repository

import (
	"errors"

	"posyandu-api/internal/models"

	"gorm.io/gorm"
)

type KeluargaRepository struct{ db *gorm.DB }

func NewKeluargaRepository(db *gorm.DB) *KeluargaRepository {
	return &KeluargaRepository{db}
}

func (r *KeluargaRepository) ListPosyandu() ([]models.Posyandu, error) {
	var p []models.Posyandu
	return p, r.db.Order("nama").Find(&p).Error
}

func (r *KeluargaRepository) GetByUser(uid uint) (*models.Keluarga, error) {
	var k models.Keluarga
	err := r.db.Preload("Ayah").Preload("Anak").Preload("Posyandu").
		Where("user_id = ?", uid).First(&k).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return &models.Keluarga{UserID: uid}, nil // belum pernah isi
	}
	return &k, err
}

// Simpan data ibu + ayah (upsert)
func (r *KeluargaRepository) SimpanProfil(k *models.Keluarga, ayah *models.Ayah) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(k).Error; err != nil {
			return err
		}
		if k.TanpaAyah || ayah == nil {
			return tx.Where("keluarga_id = ?", k.ID).Delete(&models.Ayah{}).Error
		}
		ayah.KeluargaID = k.ID
		var ada models.Ayah
		if err := tx.Where("keluarga_id = ?", k.ID).First(&ada).Error; err == nil {
			ayah.ID = ada.ID
		}
		return tx.Save(ayah).Error
	})
}

func (r *KeluargaRepository) TambahAnak(a *models.Anak) error { return r.db.Create(a).Error }

func (r *KeluargaRepository) UbahAnak(a *models.Anak) error {
	return r.db.Model(&models.Anak{}).
		Where("id = ? AND keluarga_id = ?", a.ID, a.KeluargaID).
		Select("nama", "nik", "tgl_lahir", "jk", "berat_lahir", "panjang_lahir").
		Updates(a).Error
}

func (r *KeluargaRepository) HapusAnak(id, keluargaID uint) error {
	return r.db.Where("id = ? AND keluarga_id = ?", id, keluargaID).
		Delete(&models.Anak{}).Error
}