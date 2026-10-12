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

// Semua fungsi menerima posyandu opsional; kosong = semua posyandu (admin).

func (r *VaksinStatistikRepository) imunisasi(posyandu []string) *gorm.DB {
	q := r.db.Model(&models.ImunisasiAnak{})
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("anak_id IN (?)", subAnakPosyandu(r.db, p))
	}
	return q
}

func (r *VaksinStatistikRepository) TotalDiberikan(posyandu ...string) (int64, error) {
	var n int64
	err := r.imunisasi(posyandu).Count(&n).Error
	return n, err
}

func (r *VaksinStatistikRepository) TotalAnakDivaksin(posyandu ...string) (int64, error) {
	var n int64
	err := r.imunisasi(posyandu).Distinct("anak_id").Count(&n).Error
	return n, err
}

func (r *VaksinStatistikRepository) TotalRencanaAktif(posyandu ...string) (int64, error) {
	var n int64
	q := r.db.Model(&models.RencanaImunisasi{}).
		Where("status IN ?", []string{"direncanakan", "terlewat"})
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("anak_id IN (?)", subAnakPosyandu(r.db, p))
	}
	err := q.Count(&n).Error
	return n, err
}

func (r *VaksinStatistikRepository) JumlahPerVaksin(posyandu ...string) ([]JumlahPerVaksin, error) {
	list := []JumlahPerVaksin{}
	err := r.imunisasi(posyandu).
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