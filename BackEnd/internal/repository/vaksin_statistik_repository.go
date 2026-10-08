package repository

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type VaksinStatistikRepository struct{ db *gorm.DB }

func NewVaksinStatistikRepository(db *gorm.DB) *VaksinStatistikRepository {
	return &VaksinStatistikRepository{db}
}

// JumlahPerVaksin: hasil agregasi riwayat imunisasi per jenis vaksin.
type JumlahPerVaksin struct {
	JenisVaksinID uuid.UUID `gorm:"column:jenis_vaksin_id"`
	Jumlah        int64     `gorm:"column:jumlah"`
	Anak          int64     `gorm:"column:anak"`
}

func (r *VaksinStatistikRepository) TotalDiberikan() (int64, error) {
	var n int64
	err := r.db.Model(&models.ImunisasiAnak{}).Count(&n).Error
	return n, err
}

func (r *VaksinStatistikRepository) TotalAnakDivaksin() (int64, error) {
	var n int64
	err := r.db.Model(&models.ImunisasiAnak{}).Distinct("anak_id").Count(&n).Error
	return n, err
}

func (r *VaksinStatistikRepository) TotalRencanaAktif() (int64, error) {
	var n int64
	err := r.db.Model(&models.RencanaImunisasi{}).
		Where("status IN ?", []string{"direncanakan", "terlewat"}).
		Count(&n).Error
	return n, err
}

func (r *VaksinStatistikRepository) JumlahPerVaksin() ([]JumlahPerVaksin, error) {
	list := []JumlahPerVaksin{}
	err := r.db.Model(&models.ImunisasiAnak{}).
		Select("jenis_vaksin_id, COUNT(*) AS jumlah, COUNT(DISTINCT anak_id) AS anak").
		Group("jenis_vaksin_id").
		Scan(&list).Error
	return list, err
}

func (r *VaksinStatistikRepository) ListJenisVaksin() ([]models.JenisVaksin, error) {
	list := []models.JenisVaksin{}
	err := r.db.Find(&list).Error
	return list, err
}