package repository

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PelayananRepository struct{ db *gorm.DB }

func NewPelayananRepository(db *gorm.DB) *PelayananRepository { return &PelayananRepository{db} }

func (r *PelayananRepository) Tx(fn func(tx *PelayananRepository) error) error {
	return r.db.Transaction(func(tx *gorm.DB) error { return fn(&PelayananRepository{tx}) })
}

// ---------------------------------------------------------------- pengukuran

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

// ---------------------------------------------------------------- catatan bidan

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

func (r *PelayananRepository) ListVaksin() ([]models.JenisVaksin, error) {
	list := []models.JenisVaksin{}
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
	err := r.db.Preload("JenisVaksin").Where("pendaftaran_id IN ?", pendaftaranIDs).Find(&list).Error
	return list, err
}

func (r *PelayananRepository) ListImunisasiAnak(anakID uuid.UUID) ([]models.ImunisasiAnak, error) {
	list := []models.ImunisasiAnak{}
	err := r.db.Preload("JenisVaksin").Where("anak_id = ?", anakID).
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

// ---------------------------------------------------------------- riwayat

// RiwayatPendaftaran: kunjungan anak yang SUDAH diberi catatan bidan (dan boleh ditampilkan).
func (r *PelayananRepository) RiwayatPendaftaran(anakIDs []uuid.UUID) ([]models.Pendaftaran, error) {
	list := []models.Pendaftaran{}
	if len(anakIDs) == 0 {
		return list, nil
	}
	err := r.db.Preload("Jadwal").
		Where("anak_id IN ?", anakIDs).
		Where("id IN (?)", r.db.Model(&models.PemeriksaanBidan{}).
			Select("pendaftaran_id").Where("tampil_ke_orang_tua = ?", true)).
		Find(&list).Error
	return list, err
}
