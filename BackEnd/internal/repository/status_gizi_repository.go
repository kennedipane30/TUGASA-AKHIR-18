package repository

import (
	"errors"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type StatusGiziRepository struct{ db *gorm.DB }

func NewStatusGiziRepository(db *gorm.DB) *StatusGiziRepository { return &StatusGiziRepository{db} }

// ---------------------------------------------------------------- standar

func (r *StatusGiziRepository) SemuaStandar() ([]models.StandarAntropometri, error) {
	list := []models.StandarAntropometri{}
	err := r.db.Order("indeks, jenis_kelamin, acuan").Find(&list).Error
	return list, err
}

// StandarSeri: satu kurva standar (untuk grafik), acuan dalam rentang [dari, sampai].
func (r *StatusGiziRepository) StandarSeri(indeks, jk string, dari, sampai float64) ([]models.StandarAntropometri, error) {
	list := []models.StandarAntropometri{}
	err := r.db.Where("indeks = ? AND jenis_kelamin = ? AND acuan BETWEEN ? AND ?", indeks, jk, dari, sampai).
		Order("acuan ASC").Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- status gizi

// Simpan: satu status per pengukuran (dibuat baru atau diperbarui).
func (r *StatusGiziRepository) Simpan(s *models.StatusGizi) error {
	var lama models.StatusGizi
	err := r.db.Where("pengukuran_id = ?", s.PengukuranID).First(&lama).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		if s.Version == 0 {
			s.Version = 1
		}
		return r.db.Create(s).Error
	}
	if err != nil {
		return err
	}
	s.ID = lama.ID
	s.CreatedAt = lama.CreatedAt
	s.Version = lama.Version + 1
	return r.db.Save(s).Error
}

func (r *StatusGiziRepository) GetByPengukuran(pengukuranID uuid.UUID) (*models.StatusGizi, error) {
	var s models.StatusGizi
	err := r.db.Where("pengukuran_id = ?", pengukuranID).First(&s).Error
	return &s, err
}

func (r *StatusGiziRepository) ListByPengukuran(ids []uuid.UUID) ([]models.StatusGizi, error) {
	list := []models.StatusGizi{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Where("pengukuran_id IN ?", ids).Find(&list).Error
	return list, err
}

func (r *StatusGiziRepository) ListByBalita(balitaID uuid.UUID) ([]models.StatusGizi, error) {
	list := []models.StatusGizi{}
	err := r.db.Where("balita_id = ?", balitaID).Order("tanggal_ukur ASC").Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- hitung ulang data lama

// PengukuranTanpaStatus: pengukuran yang belum memiliki status gizi.
func (r *StatusGiziRepository) PengukuranTanpaStatus(batas int) ([]models.Pengukuran, error) {
	list := []models.Pengukuran{}
	err := r.db.Where("id NOT IN (?)",
		r.db.Model(&models.StatusGizi{}).Select("pengukuran_id")).
		Order("tanggal_ukur ASC").Limit(batas).Find(&list).Error
	return list, err
}

func (r *StatusGiziRepository) BalitaByIDs(ids []uuid.UUID) ([]models.Balita, error) {
	list := []models.Balita{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Unscoped().Where("id IN ?", ids).Find(&list).Error
	return list, err
}