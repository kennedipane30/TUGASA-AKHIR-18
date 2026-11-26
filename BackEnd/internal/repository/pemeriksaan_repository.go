package repository

// Kueri pemeriksaan bidan: catatan pemeriksaan, imunisasi yang diberikan, dan
// suplemen. GantiImunisasi dan GantiSuplemen dipakai di dalam satu transaksi
// bersama GantiKpsp saat bidan menyimpan catatan.

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
)

func (r *PelayananRepository) GetPemeriksaan(pendaftaranID uuid.UUID) (*models.PemeriksaanBidan, error) {
	var p models.PemeriksaanBidan
	err := r.db.Where("pendaftaran_id = ?", pendaftaranID).First(&p).Error
	return &p, err
}

func (r *PelayananRepository) CreatePemeriksaan(p *models.PemeriksaanBidan) error { return r.db.Create(p).Error }
func (r *PelayananRepository) SavePemeriksaan(p *models.PemeriksaanBidan) error   { return r.db.Save(p).Error }

func (r *PelayananRepository) ListPemeriksaan(pendaftaranIDs []uuid.UUID) ([]models.PemeriksaanBidan, error) {
	list := []models.PemeriksaanBidan{}
	if len(pendaftaranIDs) == 0 {
		return list, nil
	}
	err := r.db.Where("pendaftaran_id IN ?", pendaftaranIDs).Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- imunisasi dan suplemen

func (r *PelayananRepository) ListJenisImunisasi() ([]models.JenisImunisasi, error) {
	list := []models.JenisImunisasi{}
	err := r.db.Where("is_active = ?", true).Order("nama").Find(&list).Error
	return list, err
}

func (r *PelayananRepository) ImunisasiSudahAda(anakID, jenisID uuid.UUID, dosis int16, kecualiPendaftaran uuid.UUID) bool {
	var n int64
	r.db.Model(&models.ImunisasiAnak{}).
		Where("anak_id = ? AND jenis_vaksin_id = ? AND dosis_ke = ?", anakID, jenisID, dosis).
		Where("pendaftaran_id IS NULL OR pendaftaran_id <> ?", kecualiPendaftaran).
		Count(&n)
	return n > 0
}

// GantiImunisasi menggantikan seluruh catatan imunisasi satu kunjungan.
func (r *PelayananRepository) GantiImunisasi(pendaftaranID uuid.UUID, items []models.ImunisasiAnak) error {
	if err := r.db.Unscoped().Where("pendaftaran_id = ?", pendaftaranID).
		Delete(&models.ImunisasiAnak{}).Error; err != nil {
		return err
	}
	for i := range items {
		if err := r.db.Create(&items[i]).Error; err != nil {
			return err
		}
	}
	return nil
}

func (r *PelayananRepository) GantiSuplemen(pendaftaranID uuid.UUID, items []models.SuplemenAnak) error {
	if err := r.db.Unscoped().Where("pendaftaran_id = ?", pendaftaranID).
		Delete(&models.SuplemenAnak{}).Error; err != nil {
		return err
	}
	for i := range items {
		if err := r.db.Create(&items[i]).Error; err != nil {
			return err
		}
	}
	return nil
}

func (r *PelayananRepository) ListImunisasi(pendaftaranIDs []uuid.UUID) ([]models.ImunisasiAnak, error) {
	list := []models.ImunisasiAnak{}
	if len(pendaftaranIDs) == 0 {
		return list, nil
	}
	err := r.db.Preload("JenisImunisasi").Where("pendaftaran_id IN ?", pendaftaranIDs).Find(&list).Error
	return list, err
}

func (r *PelayananRepository) ListImunisasiAnak(anakID uuid.UUID) ([]models.ImunisasiAnak, error) {
	list := []models.ImunisasiAnak{}
	err := r.db.Preload("JenisImunisasi").Where("anak_id = ?", anakID).
		Order("tanggal_pemberian DESC").Find(&list).Error
	return list, err
}

func (r *PelayananRepository) ListSuplemen(pendaftaranIDs []uuid.UUID) ([]models.SuplemenAnak, error) {
	list := []models.SuplemenAnak{}
	if len(pendaftaranIDs) == 0 {
		return list, nil
	}
	err := r.db.Where("pendaftaran_id IN ?", pendaftaranIDs).Find(&list).Error
	return list, err
}