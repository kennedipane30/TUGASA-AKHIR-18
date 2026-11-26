package repository

import (
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// RekapRepository: kueri rekap posyandu untuk sekretaris dan kader
// (status gizi, Vitamin A & obat cacing, balita tidak hadir).
type RekapRepository struct{ db *gorm.DB }

func NewRekapRepository(db *gorm.DB) *RekapRepository { return &RekapRepository{db} }

const rekapTgl = "2006-01-02"

// AnakAktif: semua anak berstatus aktif di satu posyandu.
func (r *RekapRepository) AnakAktif(pos string) ([]models.Anak, error) {
	list := []models.Anak{}
	err := r.db.Where("status = ?", "aktif").
		Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, pos)).
		Order("nama ASC").Find(&list).Error
	return list, err
}

// StatusGiziRentang: status gizi anak posyandu dengan tanggal ukur dalam [dari, sampai), terbaru di atas.
func (r *RekapRepository) StatusGiziRentang(pos string, dari, sampai time.Time) ([]models.StatusGizi, error) {
	list := []models.StatusGizi{}
	err := r.db.Where("anak_id IN (?)", subAnakPosyandu(r.db, pos)).
		Where("tanggal_ukur >= ? AND tanggal_ukur < ?", dari.Format(rekapTgl), sampai.Format(rekapTgl)).
		Order("tanggal_ukur DESC, created_at DESC").Find(&list).Error
	return list, err
}

type rekapTimbang struct {
	AnakID   uuid.UUID
	Terakhir time.Time
}

func (r *RekapRepository) petaTimbang(q *gorm.DB) (map[uuid.UUID]time.Time, error) {
	rows := []rekapTimbang{}
	if err := q.Select("anak_id, MAX(tanggal_ukur) AS terakhir").Group("anak_id").Scan(&rows).Error; err != nil {
		return nil, err
	}
	out := make(map[uuid.UUID]time.Time, len(rows))
	for _, x := range rows {
		out[x.AnakID] = x.Terakhir
	}
	return out, nil
}

// DitimbangRentang: anak posyandu yang ditimbang dalam [dari, sampai) beserta tanggal timbang terakhirnya.
func (r *RekapRepository) DitimbangRentang(pos string, dari, sampai time.Time) (map[uuid.UUID]time.Time, error) {
	return r.petaTimbang(r.db.Model(&models.Pengukuran{}).
		Where("anak_id IN (?)", subAnakPosyandu(r.db, pos)).
		Where("tanggal_ukur >= ? AND tanggal_ukur < ?", dari.Format(rekapTgl), sampai.Format(rekapTgl)))
}

// TimbangTerakhirSebelum: tanggal timbang terakhir tiap anak posyandu sebelum [sebelum].
func (r *RekapRepository) TimbangTerakhirSebelum(pos string, sebelum time.Time) (map[uuid.UUID]time.Time, error) {
	return r.petaTimbang(r.db.Model(&models.Pengukuran{}).
		Where("anak_id IN (?)", subAnakPosyandu(r.db, pos)).
		Where("tanggal_ukur < ?", sebelum.Format(rekapTgl)))
}

// SuplemenRentang: pemberian suplemen anak posyandu dalam [dari, sampai).
func (r *RekapRepository) SuplemenRentang(pos string, dari, sampai time.Time) ([]models.SuplemenAnak, error) {
	list := []models.SuplemenAnak{}
	err := r.db.Where("anak_id IN (?)", subAnakPosyandu(r.db, pos)).
		Where("tanggal >= ? AND tanggal < ?", dari.Format(rekapTgl), sampai.Format(rekapTgl)).
		Find(&list).Error
	return list, err
}

// PendaftaranRentang: pendaftaran anak posyandu ke jadwal (tidak dibatalkan) bertanggal dalam [dari, sampai).
func (r *RekapRepository) PendaftaranRentang(pos string, dari, sampai time.Time) ([]models.Pendaftaran, error) {
	list := []models.Pendaftaran{}
	err := r.db.Where("anak_id IN (?)", subAnakPosyandu(r.db, pos)).
		Where("jadwal_id IN (?)", r.db.Model(&models.JadwalPosyandu{}).Select("id").
			Where("posyandu = ? AND status <> ? AND tanggal >= ? AND tanggal < ?",
				pos, "dibatalkan", dari.Format(rekapTgl), sampai.Format(rekapTgl))).
		Find(&list).Error
	return list, err
}

// JumlahJadwalRentang: jumlah jadwal posyandu (tidak dibatalkan) dalam [dari, sampai).
func (r *RekapRepository) JumlahJadwalRentang(pos string, dari, sampai time.Time) (int64, error) {
	var n int64
	err := r.db.Model(&models.JadwalPosyandu{}).
		Where("posyandu = ? AND status <> ? AND tanggal >= ? AND tanggal < ?",
			pos, "dibatalkan", dari.Format(rekapTgl), sampai.Format(rekapTgl)).
		Count(&n).Error
	return n, err
}