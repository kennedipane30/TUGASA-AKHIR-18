package repository

import (
	"strings"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// ============================================================================
// DATA KELUARGA OLEH KADER
// Dipakai fitur "Tambahkan Akun" dan "Edit Keluarga" di aplikasi kader.
// ============================================================================

// RingkasKeluarga: satu baris daftar keluarga pada halaman Data Keluarga kader.
type RingkasKeluarga struct {
	KeluargaID uuid.UUID `json:"keluarga_id"`
	NamaIbu    string    `json:"nama_ibu"`
	NIK        *string   `json:"nik"`
	NoHP       string    `json:"no_hp"`
	Alamat     string    `json:"alamat"`
	JumlahAnak int       `json:"jumlah_anak"`
	PunyaAkun  bool      `json:"punya_akun"`
}

// NIKOrangTuaAda: NIK sudah dipakai ibu/ayah/wali lain (data orang tua aktif).
func (r *KeluargaRepository) NIKOrangTuaAda(nik string) bool {
	var n int64
	r.db.Model(&models.OrangTua{}).Where("nik = ?", nik).Count(&n)
	return n > 0
}

// IbuKeluarga: baris ibu (pemegang akun) pada satu keluarga.
func (r *KeluargaRepository) IbuKeluarga(keluargaID uuid.UUID) (*models.OrangTua, error) {
	var o models.OrangTua
	err := r.db.Where("keluarga_id = ? AND peran_keluarga = ?", keluargaID, "ibu").First(&o).Error
	return &o, err
}

// CariKeluarga: keluarga di satu posyandu berdasarkan nama ibu, NIK, No. HP, atau nama anak.
// Kata kunci kosong: semua keluarga (maksimal 50, urut nama ibu).
func (r *KeluargaRepository) CariKeluarga(posyandu, kata string) ([]RingkasKeluarga, error) {
	list := []RingkasKeluarga{}
	q := r.db.Table("keluarga k").
		Select(`k.id AS keluarga_id, o.nama AS nama_ibu, o.nik, o.no_hp, k.alamat,
			(SELECT COUNT(*) FROM anak a WHERE a.keluarga_id = k.id AND a.deleted_at IS NULL AND a.status = 'aktif') AS jumlah_anak,
			(o.user_id IS NOT NULL) AS punya_akun`).
		Joins("JOIN orang_tua o ON o.keluarga_id = k.id AND o.peran_keluarga = 'ibu' AND o.deleted_at IS NULL").
		Where("k.posyandu = ? AND k.deleted_at IS NULL", posyandu)
	if kata = strings.TrimSpace(kata); kata != "" {
		like := "%" + strings.ToLower(kata) + "%"
		q = q.Where(`(LOWER(o.nama) LIKE ? OR o.nik = ? OR o.no_hp = ? OR EXISTS (
			SELECT 1 FROM anak a WHERE a.keluarga_id = k.id AND a.deleted_at IS NULL AND LOWER(a.nama) LIKE ?))`,
			like, kata, kata, like)
	}
	err := q.Order("o.nama ASC").Limit(50).Scan(&list).Error
	return list, err
}

// BuatKeluargaLengkap: akun orang tua, keluarga, ibu, ayah (opsional), dan semua anak
// dalam SATU transaksi. Bila satu langkah gagal, semuanya dibatalkan.
func (r *KeluargaRepository) BuatKeluargaLengkap(u *models.User, p ProfilData, anak []*models.Anak) (uuid.UUID, error) {
	var kid uuid.UUID
	err := r.db.Transaction(func(tx *gorm.DB) error {
		// 1. akun orang tua
		if err := tx.Create(u).Error; err != nil {
			return err
		}

		// 2. keluarga + ibu (dibuat dari data akun, sama seperti alur orang tua)
		k, ibu, err := r.ensure(tx, u.ID)
		if err != nil {
			return err
		}

		// 3. profil keluarga & data diri ibu
		k.Alamat = p.Alamat
		k.RT = p.RT
		k.RW = p.RW
		k.TanpaAyah = p.TanpaAyah
		if err := tx.Omit(clause.Associations).Save(k).Error; err != nil {
			return err
		}
		ibu.TanggalLahir = p.TglLahirIbu
		ibu.Pekerjaan = p.PekerjaanIbu
		if err := tx.Omit(clause.Associations).Save(ibu).Error; err != nil {
			return err
		}

		// 4. suami / ayah (opsional)
		if !p.TanpaAyah && p.Ayah != nil {
			ayah := *p.Ayah
			ayah.ID = uuid.New()
			ayah.KeluargaID = k.ID
			ayah.PeranKeluarga = "ayah"
			ayah.UserID = nil
			if err := tx.Omit(clause.Associations).Create(&ayah).Error; err != nil {
				return err
			}
		}

		// 5. semua anak
		for _, a := range anak {
			a.KeluargaID = k.ID
			if err := tx.Omit(clause.Associations).Create(a).Error; err != nil {
				return err
			}
		}

		kid = k.ID
		return nil
	})
	return kid, err
}