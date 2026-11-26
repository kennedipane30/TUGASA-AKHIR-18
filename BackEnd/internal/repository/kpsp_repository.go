package repository

import (
	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// KpspRepository melayani master pertanyaan KPSP dan hasil skrining balita.
type KpspRepository struct {
	db *gorm.DB
}

func NewKpspRepository(db *gorm.DB) *KpspRepository {
	return &KpspRepository{db: db}
}

// ListPertanyaan mengambil 10 pertanyaan satu kelompok umur, terurut nomor.
func (r *KpspRepository) ListPertanyaan(usiaBulan int16) ([]models.PertanyaanKpsp, error) {
	list := []models.PertanyaanKpsp{}
	err := r.db.Where("usia_bulan = ?", usiaBulan).Order("nomor").Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- hasil KPSP

// GantiKpsp mengganti hasil KPSP satu kunjungan: baris lama dibuang, lalu
// hasil baru beserta jawabannya disimpan. Dipanggil di dalam transaksi
// penyimpanan catatan bidan, mengikuti pola GantiImunisasi dan GantiSuplemen.
//
// hasil bernilai nil berarti bidan tidak mengisi KPSP pada kunjungan ini,
// sehingga baris lama (bila ada) ikut terhapus.
func (r *PelayananRepository) GantiKpsp(pendaftaranID uuid.UUID, hasil *models.HasilKpsp) error {
	lama := []models.HasilKpsp{}
	if err := r.db.Unscoped().Where("pendaftaran_id = ?", pendaftaranID).Find(&lama).Error; err != nil {
		return err
	}
	for _, h := range lama {
		if err := r.db.Unscoped().Where("hasil_kpsp_id = ?", h.ID).
			Delete(&models.JawabanKpsp{}).Error; err != nil {
			return err
		}
	}
	if err := r.db.Unscoped().Where("pendaftaran_id = ?", pendaftaranID).
		Delete(&models.HasilKpsp{}).Error; err != nil {
		return err
	}
	if hasil == nil {
		return nil
	}
	jawaban := hasil.Jawaban
	hasil.Jawaban = nil
	if err := r.db.Create(hasil).Error; err != nil {
		return err
	}
	for i := range jawaban {
		jawaban[i].HasilKpspID = hasil.ID
		if err := r.db.Create(&jawaban[i]).Error; err != nil {
			return err
		}
	}
	hasil.Jawaban = jawaban
	return nil
}

// ListKpsp mengambil hasil KPSP beberapa kunjungan sekaligus, lengkap dengan
// jawabannya, untuk ditampilkan pada detail dan riwayat pemeriksaan.
func (r *PelayananRepository) ListKpsp(pendaftaranIDs []uuid.UUID) ([]models.HasilKpsp, error) {
	list := []models.HasilKpsp{}
	if len(pendaftaranIDs) == 0 {
		return list, nil
	}
	err := r.db.Preload("Jawaban", func(d *gorm.DB) *gorm.DB { return d.Order("nomor") }).
		Where("pendaftaran_id IN ?", pendaftaranIDs).Find(&list).Error
	return list, err
}