package repository

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// BalitaRepository: data semua balita satu posyandu (untuk sekretaris, kader, bidan).
type BalitaRepository struct{ db *gorm.DB }

func NewBalitaRepository(db *gorm.DB) *BalitaRepository { return &BalitaRepository{db} }

// BalitaPosyandu: semua balita di satu posyandu (aktif dan tidak aktif), urut nama.
func (r *BalitaRepository) BalitaPosyandu(pos string) ([]models.Balita, error) {
	list := []models.Balita{}
	err := r.db.Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, pos)).
		Order("nama ASC").Find(&list).Error
	return list, err
}

func (r *BalitaRepository) GetBalita(id uuid.UUID) (*models.Balita, error) {
	var a models.Balita
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

// PengukuranBanyakBalita: semua pengukuran untuk banyak balita, terbaru di atas.
func (r *BalitaRepository) PengukuranBanyakBalita(ids []uuid.UUID) ([]models.Pengukuran, error) {
	list := []models.Pengukuran{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Where("balita_id IN ?", ids).Order("tanggal_ukur DESC").Find(&list).Error
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

// PemeriksaanByPendaftaran: catatan bidan untuk banyak kunjungan (pendaftaran).
func (r *BalitaRepository) PemeriksaanByPendaftaran(ids []uuid.UUID) ([]models.PemeriksaanBidan, error) {
	list := []models.PemeriksaanBidan{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Where("pendaftaran_id IN ?", ids).Find(&list).Error
	return list, err
}

// SuplemenByPendaftaran: suplemen (Vitamin A, obat cacing, dll.) yang diberikan pada banyak kunjungan.
func (r *BalitaRepository) SuplemenByPendaftaran(ids []uuid.UUID) ([]models.SuplemenBalita, error) {
	list := []models.SuplemenBalita{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Where("pendaftaran_id IN ?", ids).Order("created_at ASC").Find(&list).Error
	return list, err
}

// ImunisasiByPendaftaran: imunisasi yang diberikan pada banyak kunjungan, beserta nama imunisasi.
func (r *BalitaRepository) ImunisasiByPendaftaran(ids []uuid.UUID) ([]models.ImunisasiBalita, error) {
	list := []models.ImunisasiBalita{}
	if len(ids) == 0 {
		return list, nil
	}
	err := r.db.Preload("JenisImunisasi").Where("pendaftaran_id IN ?", ids).
		Order("dosis_ke ASC").Find(&list).Error
	return list, err
}