package repository

import (
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AnakArsipRepository: arsip data anak (pindah, meninggal, lulus balita).
//
// Setiap perubahan menaikkan version dan memperbarui updated_at agar ikut
// terkirim pada delta sync.
type AnakArsipRepository struct{ db *gorm.DB }

func NewAnakArsipRepository(db *gorm.DB) *AnakArsipRepository { return &AnakArsipRepository{db} }

func (r *AnakArsipRepository) GetKeluarga(id uuid.UUID) (*models.Keluarga, error) {
	var k models.Keluarga
	err := r.db.First(&k, "id = ?", id).Error
	return &k, err
}

func (r *AnakArsipRepository) GetAnak(id uuid.UUID) (*models.Anak, error) {
	var a models.Anak
	err := r.db.First(&a, "id = ?", id).Error
	return &a, err
}

// Arsipkan: ubah status anak menjadi arsip, lalu batalkan pendaftaran posyandu
// yang belum berlangsung. Gagal (gorm.ErrRecordNotFound) bila anak sudah tidak aktif.
func (r *AnakArsipRepository) Arsipkan(anakID uuid.UUID, tanggal time.Time, alasan string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&models.Anak{}).
			Where("id = ? AND status = ?", anakID, models.StatusAnakAktif).
			Updates(map[string]any{
				"status":        models.StatusAnakArsip,
				"tanggal_arsip": tanggal.Format("2006-01-02"),
				"alasan_arsip":  alasan,
				"version":       gorm.Expr("version + 1"),
			})
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return batalkanPendaftaranArsip(tx, &anakID)
	})
}

// Aktifkan: kembalikan anak arsip menjadi aktif (mis. salah arsip / kembali ke desa).
func (r *AnakArsipRepository) Aktifkan(anakID uuid.UUID) error {
	res := r.db.Model(&models.Anak{}).
		Where("id = ? AND status = ?", anakID, models.StatusAnakArsip).
		Updates(map[string]any{
			"status":        models.StatusAnakAktif,
			"tanggal_arsip": nil,
			"alasan_arsip":  "",
			"version":       gorm.Expr("version + 1"),
		})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// LulusBalita: arsipkan semua anak aktif yang lahir pada/ sebelum [lahirPalingLambat]
// (sudah berusia 60 bulan). Tanggal arsip = tanggal lahir + 60 bulan.
func (r *AnakArsipRepository) LulusBalita(lahirPalingLambat time.Time) (int64, error) {
	var jumlah int64
	err := r.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&models.Anak{}).
			Where("status = ? AND tanggal_lahir <= ?", models.StatusAnakAktif, lahirPalingLambat.Format("2006-01-02")).
			Updates(map[string]any{
				"status":        models.StatusAnakArsip,
				"tanggal_arsip": gorm.Expr("(tanggal_lahir + INTERVAL '60 months')::date"),
				"alasan_arsip":  models.AlasanArsipLulus,
				"version":       gorm.Expr("version + 1"),
			})
		if res.Error != nil {
			return res.Error
		}
		jumlah = res.RowsAffected
		if jumlah == 0 {
			return nil
		}
		return batalkanPendaftaranArsip(tx, nil)
	})
	return jumlah, err
}

// batalkanPendaftaranArsip: pendaftaran berstatus "terdaftar" pada jadwal hari ini
// atau sesudahnya milik anak arsip dibatalkan. [anakID] nil = semua anak arsip.
func batalkanPendaftaranArsip(tx *gorm.DB, anakID *uuid.UUID) error {
	hari := time.Now().In(time.FixedZone("WIB", 7*3600)).Format("2006-01-02")
	q := tx.Model(&models.Pendaftaran{}).
		Where("status_kehadiran = ?", "terdaftar").
		Where("jadwal_id IN (?)", tx.Model(&models.JadwalPosyandu{}).Select("id").Where("tanggal >= ?", hari))
	if anakID != nil {
		q = q.Where("anak_id = ?", *anakID)
	} else {
		q = q.Where("anak_id IN (?)", tx.Model(&models.Anak{}).Select("id").Where("status = ?", models.StatusAnakArsip))
	}
	return q.Updates(map[string]any{
		"status_kehadiran": "batal",
		"waktu_batal":      time.Now(),
		"version":          gorm.Expr("version + 1"),
	}).Error
}