package repository

// PelayananRepository melayani satu sesi pelayanan posyandu, dari pendataan
// kader sampai pemeriksaan bidan.
//
// Berkas ini berisi rangka repository-nya saja. Kueri tiap fitur ada di berkas
// tersendiri, bersesuaian satu-satu dengan berkas service-nya:
//
//	pengukuran_repository.go           pengukuran anak oleh kader
//	pemeriksaan_repository.go          catatan bidan, imunisasi, dan suplemen
//	kpsp_repository.go                 skrining perkembangan (KPSP)
//	riwayat_pemeriksaan_repository.go  riwayat kunjungan untuk orang tua

import (
	"gorm.io/gorm"
)

type PelayananRepository struct{ db *gorm.DB }

func NewPelayananRepository(db *gorm.DB) *PelayananRepository { return &PelayananRepository{db} }

func (r *PelayananRepository) Tx(fn func(tx *PelayananRepository) error) error {
	return r.db.Transaction(func(tx *gorm.DB) error { return fn(&PelayananRepository{tx}) })
}