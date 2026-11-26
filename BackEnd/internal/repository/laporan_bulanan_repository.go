package repository

import (
	"time"

	"posyandu-api/internal/models"

	"gorm.io/gorm"
)

// LaporanBulananRepository: kueri tambahan khusus laporan bulanan posyandu
// (sekretaris & bidan). Data lain memakai RekapRepository.
type LaporanBulananRepository struct{ db *gorm.DB }

func NewLaporanBulananRepository(db *gorm.DB) *LaporanBulananRepository {
	return &LaporanBulananRepository{db}
}

// JadwalRentang: jadwal posyandu (tidak dibatalkan) dalam [dari, sampai), urut tanggal.
func (r *LaporanBulananRepository) JadwalRentang(pos string, dari, sampai time.Time) ([]models.JadwalPosyandu, error) {
	list := []models.JadwalPosyandu{}
	err := r.db.Where("posyandu = ? AND status <> ? AND tanggal >= ? AND tanggal < ?",
		pos, "dibatalkan", dari.Format(rekapTgl), sampai.Format(rekapTgl)).
		Order("tanggal ASC").Find(&list).Error
	return list, err
}

// ImunisasiPerJenis: jumlah imunisasi yang diberikan di posyandu (sudah dikonfirmasi)
// dalam [dari, sampai), dikelompokkan per jenis imunisasi.
type ImunisasiPerJenis struct {
	Nama   string
	Jumlah int
}

func (r *LaporanBulananRepository) ImunisasiPerJenis(pos string, dari, sampai time.Time) ([]ImunisasiPerJenis, error) {
	rows := []ImunisasiPerJenis{}
	err := r.db.Table("imunisasi_anak AS i").
		Select("j.nama AS nama, COUNT(i.id) AS jumlah").
		Joins("JOIN jenis_vaksin j ON j.id = i.jenis_vaksin_id").
		Where("i.deleted_at IS NULL").
		Where("i.sumber = ? AND i.status_konfirmasi = ?",
			models.SumberImunisasiPosyandu, models.KonfirmasiImunisasiOK).
		Where("i.anak_id IN (?)", subAnakPosyandu(r.db, pos)).
		Where("i.tanggal_pemberian >= ? AND i.tanggal_pemberian < ?", dari.Format(rekapTgl), sampai.Format(rekapTgl)).
		Group("j.nama, j.urutan").
		Order("j.urutan ASC, j.nama ASC").
		Scan(&rows).Error
	return rows, err
}