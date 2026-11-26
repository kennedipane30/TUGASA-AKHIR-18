package repository

import (
	"strings"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
)

// ---------------------------------------------------------------- imunisasi mandiri (di luar program)

// ListImunisasiMandiri: imunisasi di luar program milik anak, urut tanggal pemberian.
func (r *ImunisasiRepository) ListImunisasiMandiri(anakID uuid.UUID) ([]models.ImunisasiMandiriAnak, error) {
	list := []models.ImunisasiMandiriAnak{}
	err := r.db.Where("anak_id = ?", anakID).
		Order("tanggal_pemberian ASC, nama_vaksin ASC, dosis_ke ASC").Find(&list).Error
	return list, err
}

// ImunisasiMandiriAda: nama imunisasi (tanpa membedakan huruf besar/kecil) + dosis sudah tercatat untuk anak.
func (r *ImunisasiRepository) ImunisasiMandiriAda(anakID uuid.UUID, nama string, dosis int16) bool {
	var n int64
	r.db.Model(&models.ImunisasiMandiriAnak{}).
		Where("anak_id = ? AND LOWER(nama_vaksin) = ? AND dosis_ke = ?",
			anakID, strings.ToLower(strings.TrimSpace(nama)), dosis).
		Count(&n)
	return n > 0
}

func (r *ImunisasiRepository) CreateImunisasiMandiri(m *models.ImunisasiMandiriAnak) error {
	return r.db.Create(m).Error
}

func (r *ImunisasiRepository) GetImunisasiMandiri(id uuid.UUID) (*models.ImunisasiMandiriAnak, error) {
	var m models.ImunisasiMandiriAnak
	err := r.db.First(&m, "id = ?", id).Error
	return &m, err
}

func (r *ImunisasiRepository) HapusImunisasiMandiri(id uuid.UUID) error {
	return r.db.Delete(&models.ImunisasiMandiriAnak{}, "id = ?", id).Error
}