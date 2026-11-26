package repository

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

// BalitaIbu: balita aktif beserta nama ibunya (untuk fitur Daftarkan Balita kader).
type BalitaIbu struct {
	BalitaID     uuid.UUID
	Nama         string
	JenisKelamin string
	TanggalLahir time.Time
	NamaIbu      string
}

// CariBalitaDanIbu: balita aktif di satu posyandu yang nama balita ATAU nama ibunya
// mengandung kata kunci. Maksimal 50, urut nama balita.
func (r *JadwalRepository) CariBalitaDanIbu(posyandu, kata string) ([]BalitaIbu, error) {
	list := []BalitaIbu{}
	like := "%" + strings.ToLower(strings.TrimSpace(kata)) + "%"
	err := r.db.Table("balita a").
		Select("a.id AS balita_id, a.nama, a.jenis_kelamin, a.tanggal_lahir, COALESCE(o.nama, '') AS nama_ibu").
		Joins("JOIN keluarga k ON k.id = a.keluarga_id AND k.deleted_at IS NULL").
		Joins("LEFT JOIN orang_tua o ON o.keluarga_id = k.id AND o.peran_keluarga = 'ibu' AND o.deleted_at IS NULL").
		Where("a.deleted_at IS NULL AND a.status = ? AND k.posyandu = ?", "aktif", posyandu).
		Where("(LOWER(a.nama) LIKE ? OR LOWER(o.nama) LIKE ?)", like, like).
		Order("a.nama ASC").
		Limit(50).
		Scan(&list).Error
	return list, err
}