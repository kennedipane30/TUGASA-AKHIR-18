package repository

import (
	"strings"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
)

// ---------------------------------------------------------------- imunisasi mandiri (di luar program)

// ListImunisasiMandiri: imunisasi di luar program milik balita, urut tanggal pemberian.
func (r *ImunisasiRepository) ListImunisasiMandiri(balitaID uuid.UUID) ([]models.ImunisasiMandiriBalita, error) {
	list := []models.ImunisasiMandiriBalita{}
	err := r.db.Where("balita_id = ?", balitaID).
		Order("tanggal_pemberian ASC, nama_imunisasi ASC, dosis_ke ASC").Find(&list).Error
	return list, err
}

// ImunisasiMandiriAda: nama imunisasi (tanpa membedakan huruf besar/kecil) + dosis sudah tercatat untuk balita.
func (r *ImunisasiRepository) ImunisasiMandiriAda(balitaID uuid.UUID, nama string, dosis int16) bool {
	var n int64
	r.db.Model(&models.ImunisasiMandiriBalita{}).
		Where("balita_id = ? AND LOWER(nama_imunisasi) = ? AND dosis_ke = ?",
			balitaID, strings.ToLower(strings.TrimSpace(nama)), dosis).
		Count(&n)
	return n > 0
}

func (r *ImunisasiRepository) CreateImunisasiMandiri(m *models.ImunisasiMandiriBalita) error {
	return r.db.Create(m).Error
}

func (r *ImunisasiRepository) GetImunisasiMandiri(id uuid.UUID) (*models.ImunisasiMandiriBalita, error) {
	var m models.ImunisasiMandiriBalita
	err := r.db.First(&m, "id = ?", id).Error
	return &m, err
}

func (r *ImunisasiRepository) HapusImunisasiMandiri(id uuid.UUID) error {
	return r.db.Delete(&models.ImunisasiMandiriBalita{}, "id = ?", id).Error
}