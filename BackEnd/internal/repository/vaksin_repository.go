package repository

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type VaksinRepository struct{ db *gorm.DB }

func NewVaksinRepository(db *gorm.DB) *VaksinRepository { return &VaksinRepository{db} }

func (r *VaksinRepository) Tx(fn func(tx *VaksinRepository) error) error {
	return r.db.Transaction(func(tx *gorm.DB) error { return fn(&VaksinRepository{tx}) })
}

// ---------------------------------------------------------------- anak & keluarga

func (r *VaksinRepository) GetAnak(id uuid.UUID) (*models.Anak, error) {
	var a models.Anak
	err := r.db.First(&a, "id = ?", id).Error
	return &a, err
}

func (r *VaksinRepository) KeluargaIDByUser(uid uint) (uuid.UUID, error) {
	var o models.OrangTua
	err := r.db.Where("user_id = ?", uid).First(&o).Error
	return o.KeluargaID, err
}

// ---------------------------------------------------------------- master jadwal imunisasi

func (r *VaksinRepository) ListJadwalMaster() ([]models.JadwalImunisasi, error) {
	list := []models.JadwalImunisasi{}
	err := r.db.Preload("JenisVaksin").
		Order("usia_ideal_bulan ASC, dosis_ke ASC").Find(&list).Error
	return list, err
}

func (r *VaksinRepository) GetJadwalMaster(id uuid.UUID) (*models.JadwalImunisasi, error) {
	var j models.JadwalImunisasi
	err := r.db.Preload("JenisVaksin").First(&j, "id = ?", id).Error
	return &j, err
}

func (r *VaksinRepository) GetJadwalMasterByVaksinDosis(jenisVaksinID uuid.UUID, dosisKe int16) (*models.JadwalImunisasi, error) {
	var j models.JadwalImunisasi
	err := r.db.Preload("JenisVaksin").
		Where("jenis_vaksin_id = ? AND dosis_ke = ?", jenisVaksinID, dosisKe).First(&j).Error
	return &j, err
}

// ---------------------------------------------------------------- rencana

func (r *VaksinRepository) CreateRencana(m *models.RencanaImunisasi) error {
	return r.db.Create(m).Error
}

func (r *VaksinRepository) SaveRencana(m *models.RencanaImunisasi) error {
	return r.db.Model(m).
		Select("perkiraan_tanggal", "status", "disesuaikan_oleh", "alasan_penyesuaian", "version", "updated_at").
		Updates(m).Error
}

func (r *VaksinRepository) GetRencana(id uuid.UUID) (*models.RencanaImunisasi, error) {
	var m models.RencanaImunisasi
	err := r.db.Preload("JadwalImunisasi.JenisVaksin").First(&m, "id = ?", id).Error
	return &m, err
}

func (r *VaksinRepository) ListRencanaAnak(anakID uuid.UUID, status ...string) ([]models.RencanaImunisasi, error) {
	list := []models.RencanaImunisasi{}
	q := r.db.Preload("JadwalImunisasi.JenisVaksin").Where("anak_id = ?", anakID)
	if len(status) > 0 {
		q = q.Where("status IN ?", status)
	}
	err := q.Order("perkiraan_tanggal ASC").Find(&list).Error
	return list, err
}

func (r *VaksinRepository) RencanaAktifAda(anakID, jadwalID, kecuali uuid.UUID) bool {
	var n int64
	q := r.db.Model(&models.RencanaImunisasi{}).
		Where("anak_id = ? AND jadwal_imunisasi_id = ? AND status IN ?",
			anakID, jadwalID, []string{"direncanakan", "terlewat"})
	if kecuali != uuid.Nil {
		q = q.Where("id <> ?", kecuali)
	}
	q.Count(&n)
	return n > 0
}

func (r *VaksinRepository) RencanaAktifByVaksinDosis(anakID, jenisVaksinID uuid.UUID, dosisKe int16) ([]models.RencanaImunisasi, error) {
	list := []models.RencanaImunisasi{}
	err := r.db.
		Joins("JOIN jadwal_imunisasi ji ON ji.id = rencana_imunisasi.jadwal_imunisasi_id").
		Where("rencana_imunisasi.anak_id = ? AND ji.jenis_vaksin_id = ? AND ji.dosis_ke = ? AND rencana_imunisasi.status IN ?",
			anakID, jenisVaksinID, dosisKe, []string{"direncanakan", "terlewat"}).
		Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- riwayat

func (r *VaksinRepository) CreateRiwayat(m *models.ImunisasiAnak) error {
	return r.db.Create(m).Error
}

func (r *VaksinRepository) GetRiwayat(id uuid.UUID) (*models.ImunisasiAnak, error) {
	var m models.ImunisasiAnak
	err := r.db.Preload("JenisVaksin").Preload("DiberikanOlehUser").First(&m, "id = ?", id).Error
	return &m, err
}

func (r *VaksinRepository) ListRiwayatAnak(anakID uuid.UUID) ([]models.ImunisasiAnak, error) {
	list := []models.ImunisasiAnak{}
	err := r.db.Preload("JenisVaksin").Preload("DiberikanOlehUser").
		Where("anak_id = ?", anakID).
		Order("tanggal_pemberian DESC, dosis_ke DESC").Find(&list).Error
	return list, err
}

func (r *VaksinRepository) RiwayatAda(anakID, jenisVaksinID uuid.UUID, dosisKe int16) bool {
	var n int64
	r.db.Model(&models.ImunisasiAnak{}).
		Where("anak_id = ? AND jenis_vaksin_id = ? AND dosis_ke = ?", anakID, jenisVaksinID, dosisKe).
		Count(&n)
	return n > 0
}