package repository

// Kueri pengukuran anak yang dicatat kader: berat, tinggi, lingkar kepala,
// LILA, dan keluhan.

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
)

func (r *PelayananRepository) GetPengukuran(pendaftaranID uuid.UUID) (*models.Pengukuran, error) {
	var p models.Pengukuran
	err := r.db.Where("pendaftaran_id = ?", pendaftaranID).First(&p).Error
	return &p, err
}

func (r *PelayananRepository) CreatePengukuran(p *models.Pengukuran) error { return r.db.Create(p).Error }
func (r *PelayananRepository) SavePengukuran(p *models.Pengukuran) error   { return r.db.Save(p).Error }

// PengukuranSebelumnya: pengukuran terbaru anak selain kunjungan yang sedang dicatat.
func (r *PelayananRepository) PengukuranSebelumnya(anakID, kecualiPendaftaran uuid.UUID) (*models.Pengukuran, error) {
	var p models.Pengukuran
	err := r.db.Where("anak_id = ? AND pendaftaran_id <> ?", anakID, kecualiPendaftaran).
		Order("tanggal_ukur DESC").First(&p).Error
	return &p, err
}

func (r *PelayananRepository) ListPengukuran(pendaftaranIDs []uuid.UUID) ([]models.Pengukuran, error) {
	list := []models.Pengukuran{}
	if len(pendaftaranIDs) == 0 {
		return list, nil
	}
	err := r.db.Where("pendaftaran_id IN ?", pendaftaranIDs).Find(&list).Error
	return list, err
}

// PendaftaranBerpengukuran: kunjungan pada satu jadwal yang sudah diinput kader.
func (r *PelayananRepository) PendaftaranBerpengukuran(jadwalID uuid.UUID) ([]models.Pendaftaran, error) {
	list := []models.Pendaftaran{}
	err := r.db.Preload("Anak").
		Where("jadwal_id = ?", jadwalID).
		Where("id IN (?)", r.db.Model(&models.Pengukuran{}).Select("pendaftaran_id")).
		Order("nomor_antrean ASC").Find(&list).Error
	return list, err
}