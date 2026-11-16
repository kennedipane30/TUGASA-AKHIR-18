package repository

import (
	"log"
	"time"

	"posyandu-api/internal/models"

	"gorm.io/gorm"
)

type LogAktivitasRepository struct {
	db *gorm.DB
}

// NewLogAktivitasRepository juga memastikan tabel log_aktivitas tersedia
// (hanya menambah tabel/kolom, tidak menghapus data apa pun).
func NewLogAktivitasRepository(db *gorm.DB) *LogAktivitasRepository {
	if err := db.AutoMigrate(&models.LogAktivitas{}); err != nil {
		log.Printf("log aktivitas: gagal menyiapkan tabel: %v", err)
	}
	return &LogAktivitasRepository{db: db}
}

// PemilikAkun: data singkat akun pelaku aktivitas.
type PemilikAkun struct {
	Nama     string
	Role     string
	Posyandu string
}

// Pemilik mengambil nama, role, dan posyandu akun.
func (r *LogAktivitasRepository) Pemilik(userID uint) (*PemilikAkun, error) {
	var p PemilikAkun
	err := r.db.Table("users").
		Select("nama, role, posyandu").
		Where("id = ?", userID).
		Take(&p).Error
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *LogAktivitasRepository) Simpan(a *models.LogAktivitas) error {
	return r.db.Create(a).Error
}

// FilterLogAktivitas: penyaring daftar log. Posyandu wajib diisi.
type FilterLogAktivitas struct {
	Posyandu string
	Role     string
	Dari     *time.Time
	Sampai   *time.Time
	Limit    int
	Offset   int
}

// Daftar mengembalikan log terbaru lebih dulu beserta jumlah seluruhnya.
func (r *LogAktivitasRepository) Daftar(f FilterLogAktivitas) ([]models.LogAktivitas, int64, error) {
	q := r.db.Model(&models.LogAktivitas{}).Where("posyandu = ?", f.Posyandu)
	if f.Role != "" {
		q = q.Where("role = ?", f.Role)
	}
	if f.Dari != nil {
		q = q.Where("created_at >= ?", *f.Dari)
	}
	if f.Sampai != nil {
		q = q.Where("created_at < ?", *f.Sampai)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	list := []models.LogAktivitas{}
	err := q.Order("created_at DESC, id DESC").
		Limit(f.Limit).
		Offset(f.Offset).
		Find(&list).Error
	return list, total, err
}