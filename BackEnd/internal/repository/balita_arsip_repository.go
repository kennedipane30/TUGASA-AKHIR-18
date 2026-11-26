package repository

import (
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// BalitaArsipRepository: arsip data balita (pindah, meninggal, lulus balita).
//
// Setiap perubahan menaikkan version dan memperbarui updated_at agar ikut
// terkirim pada delta sync.
type BalitaArsipRepository struct{ db *gorm.DB }

func NewBalitaArsipRepository(db *gorm.DB) *BalitaArsipRepository { return &BalitaArsipRepository{db} }

func (r *BalitaArsipRepository) GetKeluarga(id uuid.UUID) (*models.Keluarga, error) {
	var k models.Keluarga
	err := r.db.First(&k, "id = ?", id).Error
	return &k, err
}

func (r *BalitaArsipRepository) GetBalita(id uuid.UUID) (*models.Balita, error) {
	var a models.Balita
	err := r.db.First(&a, "id = ?", id).Error
	return &a, err
}

// Arsipkan: ubah status balita menjadi arsip, lalu batalkan pendaftaran posyandu
// yang belum berlangsung. Gagal (gorm.ErrRecordNotFound) bila balita sudah tidak aktif.
func (r *BalitaArsipRepository) Arsipkan(balitaID uuid.UUID, tanggal time.Time, alasan string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&models.Balita{}).
			Where("id = ? AND status = ?", balitaID, models.StatusBalitaAktif).
			Updates(map[string]any{
				"status":        models.StatusBalitaArsip,
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
		return batalkanPendaftaranArsip(tx, &balitaID)
	})
}

// Aktifkan: kembalikan balita arsip menjadi aktif (mis. salah arsip / kembali ke desa).
func (r *BalitaArsipRepository) Aktifkan(balitaID uuid.UUID) error {
	res := r.db.Model(&models.Balita{}).
		Where("id = ? AND status = ?", balitaID, models.StatusBalitaArsip).
		Updates(map[string]any{
			"status":        models.StatusBalitaAktif,
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

// LulusBalita: arsipkan semua balita aktif yang lahir pada/ sebelum [lahirPalingLambat]
// (sudah berusia 60 bulan). Tanggal arsip = tanggal lahir + 60 bulan.
func (r *BalitaArsipRepository) LulusBalita(lahirPalingLambat time.Time) (int64, error) {
	var jumlah int64
	err := r.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&models.Balita{}).
			Where("status = ? AND tanggal_lahir <= ?", models.StatusBalitaAktif, lahirPalingLambat.Format("2006-01-02")).
			Updates(map[string]any{
				"status":        models.StatusBalitaArsip,
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
// atau sesudahnya milik balita arsip dibatalkan. [balitaID] nil = semua balita arsip.
func batalkanPendaftaranArsip(tx *gorm.DB, balitaID *uuid.UUID) error {
	hari := time.Now().In(time.FixedZone("WIB", 7*3600)).Format("2006-01-02")
	q := tx.Model(&models.Pendaftaran{}).
		Where("status_kehadiran = ?", "terdaftar").
		Where("jadwal_id IN (?)", tx.Model(&models.JadwalPosyandu{}).Select("id").Where("tanggal >= ?", hari))
	if balitaID != nil {
		q = q.Where("balita_id = ?", *balitaID)
	} else {
		q = q.Where("balita_id IN (?)", tx.Model(&models.Balita{}).Select("id").Where("status = ?", models.StatusBalitaArsip))
	}
	return q.Updates(map[string]any{
		"status_kehadiran": "batal",
		"waktu_batal":      time.Now(),
		"version":          gorm.Expr("version + 1"),
	}).Error
}