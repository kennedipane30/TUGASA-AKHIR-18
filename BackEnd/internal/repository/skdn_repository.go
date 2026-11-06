package repository

import (
	"time"

	"posyandu-api/internal/models"

	"gorm.io/gorm"
)

// SkdnRepository: kueri ringkasan penimbangan (SKDN) satu posyandu.
// Tidak memakai tabel baru: data diambil dari anak, pengukuran, dan penilaian_timbang.
type SkdnRepository struct{ db *gorm.DB }

func NewSkdnRepository(db *gorm.DB) *SkdnRepository { return &SkdnRepository{db} }

// PenilaianRentang: penilaian N/T/O/B anak posyandu dengan tanggal ukur dalam [dari, sampai),
// terbaru di atas.
func (r *SkdnRepository) PenilaianRentang(pos string, dari, sampai time.Time) ([]models.PenilaianTimbang, error) {
	list := []models.PenilaianTimbang{}
	err := r.db.Where("anak_id IN (?)", subAnakPosyandu(r.db, pos)).
		Where("tanggal_ukur >= ? AND tanggal_ukur < ?", dari.Format(rekapTgl), sampai.Format(rekapTgl)).
		Order("tanggal_ukur DESC, created_at DESC").Find(&list).Error
	return list, err
}