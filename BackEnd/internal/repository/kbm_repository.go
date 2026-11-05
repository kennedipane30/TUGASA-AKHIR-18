package repository

import (
	"errors"
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KbmRepository: data penilaian penimbangan (N/T, 2T, BGM).
type KbmRepository struct{ db *gorm.DB }

func NewKbmRepository(db *gorm.DB) *KbmRepository { return &KbmRepository{db} }

// PengukuranSebelum: penimbangan terakhir anak sebelum [tanggal], selain [kecuali].
func (r *KbmRepository) PengukuranSebelum(anakID uuid.UUID, tanggal time.Time, kecuali uuid.UUID) (*models.Pengukuran, error) {
	var p models.Pengukuran
	err := r.db.Where("anak_id = ? AND id <> ? AND tanggal_ukur < ?", anakID, kecuali, tanggal.Format("2006-01-02")).
		Order("tanggal_ukur DESC").First(&p).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// GetByPengukuran: penilaian satu pengukuran (nil bila belum ada).
func (r *KbmRepository) GetByPengukuran(pengukuranID uuid.UUID) (*models.PenilaianTimbang, error) {
	var m models.PenilaianTimbang
	err := r.db.Where("pengukuran_id = ?", pengukuranID).First(&m).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// Simpan: buat atau perbarui penilaian berdasarkan pengukuran_id.
func (r *KbmRepository) Simpan(m *models.PenilaianTimbang) error {
	lama, err := r.GetByPengukuran(m.PengukuranID)
	if err != nil {
		return err
	}
	if lama == nil {
		return r.db.Create(m).Error
	}
	m.ID = lama.ID
	m.CreatedAt = lama.CreatedAt
	return r.db.Save(m).Error
}

// ListByPengukuran: penilaian untuk banyak pengukuran sekaligus.
func (r *KbmRepository) ListByPengukuran(ids []uuid.UUID) ([]models.PenilaianTimbang, error) {
	list := []models.PenilaianTimbang{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Where("pengukuran_id IN ?", ids).Find(&list).Error
	return list, err
}

// ZBbu: z-score BB/U dari status gizi pengukuran (nil bila belum dihitung).
func (r *KbmRepository) ZBbu(pengukuranID uuid.UUID) (*float64, error) {
	var g models.StatusGizi
	err := r.db.Select("z_bbu").Where("pengukuran_id = ?", pengukuranID).First(&g).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return g.ZBbu, nil
}

// PengukuranTanpaPenilaian: pengukuran lama yang belum dinilai, urut tanggal agar 2T terhitung benar.
func (r *KbmRepository) PengukuranTanpaPenilaian(batas int) ([]models.Pengukuran, error) {
	list := []models.Pengukuran{}
	err := r.db.Where("id NOT IN (?)", r.db.Model(&models.PenilaianTimbang{}).Select("pengukuran_id")).
		Order("tanggal_ukur ASC").Limit(batas).Find(&list).Error
	return list, err
}

func (r *KbmRepository) AnakByIDs(ids []uuid.UUID) ([]models.Anak, error) {
	list := []models.Anak{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Unscoped().Where("id IN ?", ids).Find(&list).Error
	return list, err
}
