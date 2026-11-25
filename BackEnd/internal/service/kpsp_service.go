package service

import (
	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"
)

// KpspService melayani pembacaan lembar KPSP (10 pertanyaan per kelompok umur).
//
// Pengisian KPSP sendiri tidak lewat service ini: KPSP diisi bidan di halaman
// Catatan Bidan dan ikut tersimpan bersama hasil pemeriksaan, imunisasi, serta
// suplemen dalam satu transaksi di PelayananService.SimpanCatatan.
type KpspService struct {
	repo *repository.KpspRepository
}

func NewKpspService(repo *repository.KpspRepository) *KpspService {
	return &KpspService{repo: repo}
}

// LembarKpsp adalah satu lembar KPSP untuk kelompok umur tertentu.
type LembarKpsp struct {
	// UsiaBulan: kelompok umur lembar ini (3, 6, 9, ... 72).
	UsiaBulan int16 `json:"usia_bulan"`

	// UsiaAnakBulan: umur anak sebenarnya, untuk ditampilkan di aplikasi.
	UsiaAnakBulan int `json:"usia_anak_bulan"`

	// Berlaku: false bila anak di luar jangkauan KPSP (3-72 bulan).
	// Aplikasi menyembunyikan kartu KPSP bila bernilai false.
	Berlaku bool `json:"berlaku"`

	// Pertanyaan: 10 pertanyaan terurut nomor 1-10.
	Pertanyaan []models.PertanyaanKpsp `json:"pertanyaan"`
}

// Lembar mengambil lembar KPSP yang sesuai untuk anak berumur usiaAnakBulan.
// Kelompok umur ditentukan di server (lihat models.KelompokUsiaKpsp) supaya
// aplikasi tidak perlu tahu aturan pemilihannya.
func (s *KpspService) Lembar(usiaAnakBulan int) (*LembarKpsp, error) {
	hasil := &LembarKpsp{
		UsiaAnakBulan: usiaAnakBulan,
		Pertanyaan:    []models.PertanyaanKpsp{},
	}
	kelompok, berlaku := models.KelompokUsiaKpsp(usiaAnakBulan)
	if !berlaku {
		return hasil, nil
	}
	hasil.UsiaBulan = kelompok
	hasil.Berlaku = true

	list, err := s.repo.ListPertanyaan(kelompok)
	if err != nil {
		return nil, err
	}
	hasil.Pertanyaan = list
	return hasil, nil
}