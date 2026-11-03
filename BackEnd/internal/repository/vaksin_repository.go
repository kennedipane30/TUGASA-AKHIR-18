package repository

import (
	"errors"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type VaksinRepository struct{ db *gorm.DB }

func NewVaksinRepository(db *gorm.DB) *VaksinRepository { return &VaksinRepository{db} }

func (r *VaksinRepository) Tx(fn func(tx *VaksinRepository) error) error {
	return r.db.Transaction(func(tx *gorm.DB) error { return fn(&VaksinRepository{tx}) })
}

// ---------------------------------------------------------------- master

// SimpanJenis: buat atau perbarui jenis vaksin berdasarkan kode.
func (r *VaksinRepository) SimpanJenis(j *models.JenisVaksin) error {
	var lama models.JenisVaksin
	err := r.db.Where("UPPER(kode) = UPPER(?)", j.Kode).First(&lama).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return r.db.Create(j).Error
	}
	if err != nil {
		return err
	}
	j.ID = lama.ID
	return r.db.Model(&lama).Updates(map[string]any{
		"kode":           j.Kode,
		"nama":           j.Nama,
		"penyakit":       j.Penyakit,
		"cara_pemberian": j.CaraPemberian,
		"keterangan":     j.Keterangan,
		"jumlah_dosis":   j.JumlahDosis,
		"urutan":         j.Urutan,
		"khusus_daerah":  j.KhususDaerah,
		"is_active":      true,
	}).Error
}

// SimpanJadwal: buat atau perbarui jadwal berdasarkan (jenis vaksin, dosis).
func (r *VaksinRepository) SimpanJadwal(j *models.JadwalImunisasi) error {
	var lama models.JadwalImunisasi
	err := r.db.Where("jenis_vaksin_id = ? AND dosis_ke = ?", j.JenisVaksinID, j.DosisKe).First(&lama).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return r.db.Create(j).Error
	}
	if err != nil {
		return err
	}
	j.ID = lama.ID
	return r.db.Model(&lama).Updates(map[string]any{
		"kelompok":           j.Kelompok,
		"usia_min_bulan":     j.UsiaMinBulan,
		"usia_ideal_bulan":   j.UsiaIdealBulan,
		"usia_maks_bulan":    j.UsiaMaksBulan,
		"jarak_minimal_hari": j.JarakMinimalHari,
		"keterangan":         j.Keterangan,
	}).Error
}

// HapusJadwalLebih: hapus jadwal dosis di atas jumlah dosis yang berlaku.
func (r *VaksinRepository) HapusJadwalLebih(jenisID uuid.UUID, maksDosis int16) error {
	return r.db.Where("jenis_vaksin_id = ? AND dosis_ke > ?", jenisID, maksDosis).
		Delete(&models.JadwalImunisasi{}).Error
}

// NonaktifkanSelain: jenis vaksin lama di luar daftar master dinonaktifkan (tidak dihapus
// karena mungkin sudah dipakai di riwayat).
func (r *VaksinRepository) NonaktifkanSelain(kode []string) error {
	return r.db.Model(&models.JenisVaksin{}).
		Where("UPPER(kode) NOT IN ?", kode).
		Update("is_active", false).Error
}

func (r *VaksinRepository) ListJenisAktif() ([]models.JenisVaksin, error) {
	list := []models.JenisVaksin{}
	err := r.db.Where("is_active = ?", true).Order("urutan ASC, nama ASC").Find(&list).Error
	return list, err
}

func (r *VaksinRepository) ListJenisSemua() ([]models.JenisVaksin, error) {
	list := []models.JenisVaksin{}
	err := r.db.Order("urutan ASC, nama ASC").Find(&list).Error
	return list, err
}

// ListJadwalMaster: jadwal semua dosis vaksin aktif, urut usia.
func (r *VaksinRepository) ListJadwalMaster() ([]models.JadwalImunisasi, error) {
	list := []models.JadwalImunisasi{}
	err := r.db.Preload("JenisVaksin").
		Joins("JOIN jenis_vaksin jv ON jv.id = jadwal_imunisasi.jenis_vaksin_id").
		Where("jv.is_active = ?", true).
		Order("jadwal_imunisasi.usia_ideal_bulan ASC, jv.urutan ASC, jadwal_imunisasi.dosis_ke ASC").
		Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- anak & akses

func (r *VaksinRepository) GetAnak(id uuid.UUID) (*models.Anak, error) {
	var a models.Anak
	err := r.db.First(&a, "id = ?", id).Error
	return &a, err
}

// PosyanduAnak: kode posyandu tempat anak terdaftar (melalui keluarga).
func (r *VaksinRepository) PosyanduAnak(anakID uuid.UUID) (string, error) {
	var pos string
	err := r.db.Model(&models.Keluarga{}).
		Select("posyandu").
		Where("id IN (?)", r.db.Model(&models.Anak{}).Select("keluarga_id").Where("id = ?", anakID)).
		Scan(&pos).Error
	return pos, err
}

func (r *VaksinRepository) KeluargaIDByUser(uid uint) (uuid.UUID, error) {
	var o models.OrangTua
	err := r.db.Where("user_id = ?", uid).First(&o).Error
	return o.KeluargaID, err
}

// AnakAktifPosyandu: semua anak aktif di satu posyandu (untuk statistik).
func (r *VaksinRepository) AnakAktifPosyandu(pos string) ([]models.Anak, error) {
	list := []models.Anak{}
	err := r.db.Where("status = ?", "aktif").
		Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, pos)).
		Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- riwayat vaksin

func (r *VaksinRepository) CreateRiwayat(m *models.ImunisasiAnak) error { return r.db.Create(m).Error }

func (r *VaksinRepository) GetRiwayat(id uuid.UUID) (*models.ImunisasiAnak, error) {
	var m models.ImunisasiAnak
	err := r.db.Preload("JenisVaksin").Preload("DiberikanOlehUser").First(&m, "id = ?", id).Error
	return &m, err
}

func (r *VaksinRepository) DeleteRiwayat(id uuid.UUID) error {
	return r.db.Delete(&models.ImunisasiAnak{}, "id = ?", id).Error
}

func (r *VaksinRepository) ListRiwayatAnak(anakID uuid.UUID) ([]models.ImunisasiAnak, error) {
	list := []models.ImunisasiAnak{}
	err := r.db.Preload("JenisVaksin").Preload("DiberikanOlehUser").
		Where("anak_id = ?", anakID).
		Order("tanggal_pemberian ASC, dosis_ke ASC").Find(&list).Error
	return list, err
}

// ListRiwayatBanyakAnak: riwayat vaksin untuk banyak anak sekaligus (statistik).
func (r *VaksinRepository) ListRiwayatBanyakAnak(anakIDs []uuid.UUID) ([]models.ImunisasiAnak, error) {
	list := []models.ImunisasiAnak{}
	if len(anakIDs) == 0 {
		return list, nil
	}
	err := r.db.Where("anak_id IN ?", anakIDs).Find(&list).Error
	return list, err
}

func (r *VaksinRepository) RiwayatAda(anakID, jenisVaksinID uuid.UUID, dosisKe int16, kecualiPendaftaran *uuid.UUID) bool {
	var n int64
	q := r.db.Model(&models.ImunisasiAnak{}).
		Where("anak_id = ? AND jenis_vaksin_id = ? AND dosis_ke = ?", anakID, jenisVaksinID, dosisKe)
	if kecualiPendaftaran != nil {
		q = q.Where("pendaftaran_id IS NULL OR pendaftaran_id <> ?", *kecualiPendaftaran)
	}
	q.Count(&n)
	return n > 0
}

// ---------------------------------------------------------------- suplemen

func (r *VaksinRepository) ListSuplemenAnak(anakID uuid.UUID) ([]models.SuplemenAnak, error) {
	list := []models.SuplemenAnak{}
	err := r.db.Preload("DiberikanOlehUser").
		Where("anak_id = ?", anakID).
		Order("tanggal DESC, created_at DESC").Find(&list).Error
	return list, err
}