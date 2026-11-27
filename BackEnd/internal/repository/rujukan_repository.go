package repository

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// RujukanRepository: surat rujukan anak (bidan & orang tua).
type RujukanRepository struct{ db *gorm.DB }

func NewRujukanRepository(db *gorm.DB) *RujukanRepository { return &RujukanRepository{db} }

// ---------------------------------------------------------------- rujukan

func kodePosyanduRujukan(pos string) string {
	k := strings.ToUpper(strings.ReplaceAll(strings.TrimSpace(pos), " ", ""))
	if len(k) > 3 {
		k = k[:3]
	}
	if k == "" {
		k = "POS"
	}
	return k
}

func nomorBentrok(err error) bool {
	if err == nil {
		return false
	}
	s := strings.ToLower(err.Error())
	return strings.Contains(s, "23505") || strings.Contains(s, "duplicate") || strings.Contains(s, "ux_rujukan_nomor")
}

// Buat: simpan rujukan baru dengan nomor otomatis RJK/<POS>/<YYYY>/<MM>/<NNN>.
func (r *RujukanRepository) Buat(m *models.Rujukan) error {
	awal := time.Date(m.Tanggal.Year(), m.Tanggal.Month(), 1, 0, 0, 0, 0, time.UTC)
	akhir := awal.AddDate(0, 1, 0)
	var err error
	for coba := 0; coba < 5; coba++ {
		var n int64
		if err = r.db.Unscoped().Model(&models.Rujukan{}).
			Where("posyandu = ? AND tanggal >= ? AND tanggal < ?", m.Posyandu,
				awal.Format("2006-01-02"), akhir.Format("2006-01-02")).
			Count(&n).Error; err != nil {
			return err
		}
		m.Nomor = fmt.Sprintf("RJK/%s/%04d/%02d/%03d", kodePosyanduRujukan(m.Posyandu),
			awal.Year(), int(awal.Month()), int(n)+1+coba)
		m.ID = uuid.Nil
		err = r.db.Create(m).Error
		if !nomorBentrok(err) {
			return err
		}
	}
	return err
}

func (r *RujukanRepository) Simpan(m *models.Rujukan) error { return r.db.Save(m).Error }

// Hapus: hapus rujukan (soft delete; nomor surat tidak dipakai ulang).
func (r *RujukanRepository) Hapus(m *models.Rujukan) error { return r.db.Delete(m).Error }

func (r *RujukanRepository) Get(id uuid.UUID) (*models.Rujukan, error) {
	var m models.Rujukan
	err := r.db.First(&m, "id = ?", id).Error
	return &m, err
}

// DaftarPosyandu: rujukan satu posyandu dengan status tertentu, terbaru di atas.
func (r *RujukanRepository) DaftarPosyandu(pos string, status []string) ([]models.Rujukan, error) {
	list := []models.Rujukan{}
	q := r.db.Where("posyandu = ?", pos)
	if len(status) > 0 {
		q = q.Where("status IN ?", status)
	}
	err := q.Order("tanggal DESC, created_at DESC").Limit(300).Find(&list).Error
	return list, err
}

func subAnakOrangTua(db *gorm.DB, userID uint) *gorm.DB {
	return db.Model(&models.Anak{}).Select("id").
		Where("keluarga_id IN (?)", db.Model(&models.OrangTua{}).Select("keluarga_id").Where("user_id = ?", userID))
}

// DaftarOrangTua: rujukan semua anak milik akun orang tua [userID].
func (r *RujukanRepository) DaftarOrangTua(userID uint) ([]models.Rujukan, error) {
	list := []models.Rujukan{}
	err := r.db.Where("anak_id IN (?)", subAnakOrangTua(r.db, userID)).
		Order("tanggal DESC, created_at DESC").Limit(300).Find(&list).Error
	return list, err
}

// MilikOrangTua: true bila anak pada rujukan termasuk anak akun orang tua [userID].
func (r *RujukanRepository) MilikOrangTua(anakID uuid.UUID, userID uint) bool {
	var n int64
	r.db.Model(&models.Anak{}).Where("id = ?", anakID).
		Where("id IN (?)", subAnakOrangTua(r.db, userID)).Count(&n)
	return n > 0
}

// ---------------------------------------------------------------- data anak otomatis

// CariAnak: anak aktif di posyandu berdasarkan nama atau NIK (maks. 20).
func (r *RujukanRepository) CariAnak(pos, kata string) ([]models.Anak, error) {
	list := []models.Anak{}
	kata = strings.TrimSpace(kata)
	q := r.db.Preload("Keluarga").Where("status = ?", "aktif").
		Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, pos))
	if kata != "" {
		q = q.Where("(LOWER(nama) LIKE ? OR nik = ?)", "%"+strings.ToLower(kata)+"%", kata)
	}
	err := q.Order("nama ASC").Limit(20).Find(&list).Error
	return list, err
}

// GetAnak: anak beserta keluarganya.
func (r *RujukanRepository) GetAnak(id uuid.UUID) (*models.Anak, error) {
	var a models.Anak
	err := r.db.Preload("Keluarga").First(&a, "id = ?", id).Error
	return &a, err
}

// OrangTuaKeluarga: data orang tua (ibu/ayah/wali) satu keluarga.
func (r *RujukanRepository) OrangTuaKeluarga(keluargaID uuid.UUID) ([]models.OrangTua, error) {
	list := []models.OrangTua{}
	err := r.db.Where("keluarga_id = ?", keluargaID).Order("peran_keluarga ASC").Find(&list).Error
	return list, err
}

func cukupTidakAda(err error) error {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil
	}
	return err
}

// PengukuranTerakhir: pengukuran terbaru anak (nil bila belum pernah).
func (r *RujukanRepository) PengukuranTerakhir(anakID uuid.UUID) (*models.Pengukuran, error) {
	var p models.Pengukuran
	err := r.db.Where("anak_id = ?", anakID).Order("tanggal_ukur DESC, created_at DESC").First(&p).Error
	if err != nil {
		return nil, cukupTidakAda(err)
	}
	return &p, nil
}

// StatusGiziPengukuran: status gizi dari satu pengukuran (nil bila belum dihitung).
func (r *RujukanRepository) StatusGiziPengukuran(pengukuranID uuid.UUID) (*models.StatusGizi, error) {
	var g models.StatusGizi
	err := r.db.Where("pengukuran_id = ?", pengukuranID).First(&g).Error
	if err != nil {
		return nil, cukupTidakAda(err)
	}
	return &g, nil
}

// PenilaianPengukuran: penilaian timbang (N/T, 2T, BGM) dari satu pengukuran.
func (r *RujukanRepository) PenilaianPengukuran(pengukuranID uuid.UUID) (*models.PenilaianTimbang, error) {
	var p models.PenilaianTimbang
	err := r.db.Where("pengukuran_id = ?", pengukuranID).First(&p).Error
	if err != nil {
		return nil, cukupTidakAda(err)
	}
	return &p, nil
}

// PemeriksaanTerakhir: catatan pemeriksaan bidan terbaru untuk anak.
func (r *RujukanRepository) PemeriksaanTerakhir(anakID uuid.UUID) (*models.PemeriksaanBidan, error) {
	var p models.PemeriksaanBidan
	err := r.db.Where("pendaftaran_id IN (?)",
		r.db.Model(&models.Pendaftaran{}).Select("id").Where("anak_id = ?", anakID)).
		Order("created_at DESC").First(&p).Error
	if err != nil {
		return nil, cukupTidakAda(err)
	}
	return &p, nil
}

// NamaUser: nama akun (kosong bila tidak ada).
func (r *RujukanRepository) NamaUser(id uint) string {
	var u models.User
	if err := r.db.Select("nama").First(&u, id).Error; err != nil {
		return ""
	}
	return u.Nama
}