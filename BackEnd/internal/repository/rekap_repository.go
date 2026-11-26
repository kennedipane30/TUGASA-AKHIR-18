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

// BalitaAktif: semua balita berstatus aktif di satu posyandu.
func (r *RekapRepository) BalitaAktif(pos string) ([]models.Balita, error) {
	list := []models.Balita{}
	err := r.db.Where("status = ?", "aktif").
		Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, pos)).
		Order("nama ASC").Find(&list).Error
	return list, err
}

// StatusGiziRentang: status gizi balita posyandu dengan tanggal ukur dalam [dari, sampai), terbaru di atas.
func (r *RekapRepository) StatusGiziRentang(pos string, dari, sampai time.Time) ([]models.StatusGizi, error) {
	list := []models.StatusGizi{}
	err := r.db.Where("balita_id IN (?)", subBalitaPosyandu(r.db, pos)).
		Where("tanggal_ukur >= ? AND tanggal_ukur < ?", dari.Format(rekapTgl), sampai.Format(rekapTgl)).
		Order("tanggal_ukur DESC, created_at DESC").Find(&list).Error
	return list, err
}

type rekapTimbang struct {
	BalitaID uuid.UUID
	Terakhir time.Time
}

func (r *RekapRepository) petaTimbang(q *gorm.DB) (map[uuid.UUID]time.Time, error) {
	rows := []rekapTimbang{}
	if err := q.Select("balita_id, MAX(tanggal_ukur) AS terakhir").Group("balita_id").Scan(&rows).Error; err != nil {
		return nil, err
	}
	out := make(map[uuid.UUID]time.Time, len(rows))
	for _, x := range rows {
		out[x.BalitaID] = x.Terakhir
	}
	return out, nil
}

// DitimbangRentang: balita posyandu yang ditimbang dalam [dari, sampai) beserta tanggal timbang terakhirnya.
func (r *RekapRepository) DitimbangRentang(pos string, dari, sampai time.Time) (map[uuid.UUID]time.Time, error) {
	return r.petaTimbang(r.db.Model(&models.Pengukuran{}).
		Where("balita_id IN (?)", subBalitaPosyandu(r.db, pos)).
		Where("tanggal_ukur >= ? AND tanggal_ukur < ?", dari.Format(rekapTgl), sampai.Format(rekapTgl)))
}

// TimbangTerakhirSebelum: tanggal timbang terakhir tiap balita posyandu sebelum [sebelum].
func (r *RekapRepository) TimbangTerakhirSebelum(pos string, sebelum time.Time) (map[uuid.UUID]time.Time, error) {
	return r.petaTimbang(r.db.Model(&models.Pengukuran{}).
		Where("balita_id IN (?)", subBalitaPosyandu(r.db, pos)).
		Where("tanggal_ukur < ?", sebelum.Format(rekapTgl)))
}

// SuplemenRentang: pemberian suplemen balita posyandu dalam [dari, sampai).
func (r *RekapRepository) SuplemenRentang(pos string, dari, sampai time.Time) ([]models.SuplemenBalita, error) {
	list := []models.SuplemenBalita{}
	err := r.db.Where("balita_id IN (?)", subBalitaPosyandu(r.db, pos)).
		Where("tanggal >= ? AND tanggal < ?", dari.Format(rekapTgl), sampai.Format(rekapTgl)).
		Find(&list).Error
	return list, err
}

// PendaftaranRentang: pendaftaran balita posyandu ke jadwal (tidak dibatalkan) bertanggal dalam [dari, sampai).
func (r *RekapRepository) PendaftaranRentang(pos string, dari, sampai time.Time) ([]models.Pendaftaran, error) {
	list := []models.Pendaftaran{}
	err := r.db.Where("balita_id IN (?)", subBalitaPosyandu(r.db, pos)).
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