package repository

import (
	"strings"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
)

// ---------------------------------------------------------------- vaksin mandiri (di luar program)

// ListVaksinMandiri: vaksin di luar program milik anak, urut tanggal pemberian.
func (r *VaksinRepository) ListVaksinMandiri(anakID uuid.UUID) ([]models.VaksinMandiriAnak, error) {
	list := []models.VaksinMandiriAnak{}
	err := r.db.Where("anak_id = ?", anakID).
		Order("tanggal_pemberian ASC, nama_vaksin ASC, dosis_ke ASC").Find(&list).Error
	return list, err
}

// VaksinMandiriAda: nama vaksin (tanpa membedakan huruf besar/kecil) + dosis sudah tercatat untuk anak.
func (r *VaksinRepository) VaksinMandiriAda(anakID uuid.UUID, nama string, dosis int16) bool {
	var n int64
	r.db.Model(&models.VaksinMandiriAnak{}).
		Where("anak_id = ? AND LOWER(nama_vaksin) = ? AND dosis_ke = ?",
			anakID, strings.ToLower(strings.TrimSpace(nama)), dosis).
		Count(&n)
	return n > 0
}

func (r *VaksinRepository) CreateVaksinMandiri(m *models.VaksinMandiriAnak) error {
	return r.db.Create(m).Error
}

func (r *VaksinRepository) GetVaksinMandiri(id uuid.UUID) (*models.VaksinMandiriAnak, error) {
	var m models.VaksinMandiriAnak
	err := r.db.First(&m, "id = ?", id).Error
	return &m, err
}

func (r *VaksinRepository) HapusVaksinMandiri(id uuid.UUID) error {
	return r.db.Delete(&models.VaksinMandiriAnak{}, "id = ?", id).Error
}