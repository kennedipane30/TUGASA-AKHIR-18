package repository

// Kueri riwayat kunjungan anak untuk ditampilkan kepada orang tua.

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
)

func (r *PelayananRepository) RiwayatPendaftaran(anakIDs []uuid.UUID) ([]models.Pendaftaran, error) {
	list := []models.Pendaftaran{}
	if len(anakIDs) == 0 {
		return list, nil
	}
	err := r.db.Preload("Jadwal").
		Where("anak_id IN ?", anakIDs).
		Where(r.db.
			Where("id IN (?)", r.db.Model(&models.Pengukuran{}).Select("pendaftaran_id")).
			Or("id IN (?)", r.db.Model(&models.PemeriksaanBidan{}).
				Select("pendaftaran_id").Where("tampil_ke_orang_tua = ?", true))).
		Find(&list).Error
	return list, err
}