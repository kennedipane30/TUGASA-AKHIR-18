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

// Fungsi ListPosyandu dihapus karena sudah tidak butuh tabel posyandu

func (r *KeluargaRepository) GetByUser(uid uint) (*models.Keluarga, error) {
	var k models.Keluarga
	// Preload Posyandu dihapus
	err := r.db.Preload("Ayah").Preload("Anak").
		Where("user_id = ?", uid).First(&k).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return &models.Keluarga{UserID: uid}, nil
	}
	return &k, err
}

func (r *KeluargaRepository) SimpanProfil(k *models.Keluarga, ayah *models.Ayah) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// Logika Insert otomatis PosyanduID dihapus karena sudah tidak ada tabelnya

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