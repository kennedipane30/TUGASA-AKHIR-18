package repository

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

// AnakIbu: anak aktif beserta nama ibunya (untuk fitur Daftarkan Anak kader).
type AnakIbu struct {
	AnakID       uuid.UUID
	Nama         string
	JenisKelamin string
	TanggalLahir time.Time
	NamaIbu      string
}

// CariAnakDanIbu: anak aktif di satu posyandu yang nama anak ATAU nama ibunya
// mengandung kata kunci. Maksimal 50, urut nama anak.
func (r *JadwalRepository) CariAnakDanIbu(posyandu, kata string) ([]AnakIbu, error) {
	list := []AnakIbu{}
	like := "%" + strings.ToLower(strings.TrimSpace(kata)) + "%"
	err := r.db.Table("anak a").
		Select("a.id AS anak_id, a.nama, a.jenis_kelamin, a.tanggal_lahir, COALESCE(o.nama, '') AS nama_ibu").
		Joins("JOIN keluarga k ON k.id = a.keluarga_id AND k.deleted_at IS NULL").
		Joins("LEFT JOIN orang_tua o ON o.keluarga_id = k.id AND o.peran_keluarga = 'ibu' AND o.deleted_at IS NULL").
		Where("a.deleted_at IS NULL AND a.status = ? AND k.posyandu = ?", "aktif", posyandu).
		Where("(LOWER(a.nama) LIKE ? OR LOWER(o.nama) LIKE ?)", like, like).
		Order("a.nama ASC").
		Limit(50).
		Scan(&list).Error
	return list, err
}