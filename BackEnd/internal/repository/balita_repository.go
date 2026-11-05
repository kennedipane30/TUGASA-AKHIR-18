package repository

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// BalitaRepository: data semua balita satu posyandu (untuk sekretaris, kader, bidan).
type BalitaRepository struct{ db *gorm.DB }

func NewBalitaRepository(db *gorm.DB) *BalitaRepository { return &BalitaRepository{db} }

// AnakPosyandu: semua anak di satu posyandu (aktif dan tidak aktif), urut nama.
func (r *BalitaRepository) AnakPosyandu(pos string) ([]models.Anak, error) {
	list := []models.Anak{}
	err := r.db.Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, pos)).
		Order("nama ASC").Find(&list).Error
	return list, err
}

func (r *BalitaRepository) GetAnak(id uuid.UUID) (*models.Anak, error) {
	var a models.Anak
	err := r.db.First(&a, "id = ?", id).Error
	return &a, err
}

func (r *BalitaRepository) GetKeluarga(id uuid.UUID) (*models.Keluarga, error) {
	var k models.Keluarga
	err := r.db.First(&k, "id = ?", id).Error
	return &k, err
}

// PosyanduKeluarga: kode posyandu sebuah keluarga.
func (r *BalitaRepository) PosyanduKeluarga(keluargaID uuid.UUID) (string, error) {
	var pos string
	err := r.db.Model(&models.Keluarga{}).Select("posyandu").Where("id = ?", keluargaID).Scan(&pos).Error
	return pos, err
}

// PengukuranBanyakAnak: semua pengukuran untuk banyak anak, terbaru di atas.
func (r *BalitaRepository) PengukuranBanyakAnak(ids []uuid.UUID) ([]models.Pengukuran, error) {
	list := []models.Pengukuran{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Where("anak_id IN ?", ids).Order("tanggal_ukur DESC").Find(&list).Error
	return list, err
}

func (r *BalitaRepository) StatusGiziByPengukuran(ids []uuid.UUID) ([]models.StatusGizi, error) {
	list := []models.StatusGizi{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Where("pengukuran_id IN ?", ids).Find(&list).Error
	return list, err
}

func (r *BalitaRepository) PenilaianByPengukuran(ids []uuid.UUID) ([]models.PenilaianTimbang, error) {
	list := []models.PenilaianTimbang{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Where("pengukuran_id IN ?", ids).Find(&list).Error
	return list, err
}
