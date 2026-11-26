package service

// KPSP (Kuesioner Pra Skrining Perkembangan): skrining perkembangan balita,
// 10 pertanyaan per kelompok umur.
//
// Dua bagian dalam satu berkas:
//   - KpspService: membaca lembar pertanyaan sesuai umur balita.
//   - KpspInput & rakitKpsp: memeriksa isian bidan lalu menyusunnya menjadi
//     satu lembar hasil. Penyimpanannya ikut PelayananService.SimpanCatatan,
//     supaya satu tombol Simpan menyimpan pemeriksaan, imunisasi, suplemen,
//     dan KPSP sekaligus dalam satu transaksi.

import (
	"strings"
	"time"

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

	// UsiaBalitaBulan: umur balita sebenarnya, untuk ditampilkan di aplikasi.
	UsiaBalitaBulan int `json:"usia_balita_bulan"`

	// Berlaku: false bila balita di luar jangkauan KPSP (3-72 bulan).
	// Aplikasi menyembunyikan kartu KPSP bila bernilai false.
	Berlaku bool `json:"berlaku"`

	// Pertanyaan: 10 pertanyaan terurut nomor 1-10.
	Pertanyaan []models.PertanyaanKpsp `json:"pertanyaan"`
}

// Lembar mengambil lembar KPSP yang sesuai untuk balita berumur usiaBalitaBulan.
// Kelompok umur ditentukan di server (lihat models.KelompokUsiaKpsp) supaya
// aplikasi tidak perlu tahu aturan pemilihannya.
func (s *KpspService) Lembar(usiaBalitaBulan int) (*LembarKpsp, error) {
	hasil := &LembarKpsp{
		UsiaBalitaBulan: usiaBalitaBulan,
		Pertanyaan:      []models.PertanyaanKpsp{},
	}
	kelompok, berlaku := models.KelompokUsiaKpsp(usiaBalitaBulan)
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

// Fitur KPSP (Kuesioner Pra Skrining Perkembangan): isian 10 pertanyaan yang
// diisi bidan pada kartu KPSP, lalu disimpan bersama catatan pemeriksaan.
//
// Pembacaan daftar pertanyaannya ada di kpsp_service.go.

// KpspInput adalah satu lembar KPSP yang diisi bidan. Jawaban berisi 10 baris
// (nomor 1-10) berisi true bila dijawab "Ya". Hasil S/M/P dihitung di server
// dari jumlah jawaban "Ya", tidak dikirim aplikasi, agar tidak bisa dipalsukan.
type KpspInput struct {
	UsiaBulan int16              `json:"usia_bulan"`
	Jawaban   []KpspJawabanInput `json:"jawaban"`
	Catatan   string             `json:"catatan"`
}

type KpspJawabanInput struct {
	Nomor int16 `json:"nomor"`
	Ya    bool  `json:"ya"`
}

// rakitKpsp memeriksa isian KPSP dari aplikasi lalu menyusunnya menjadi satu
// lembar HasilKpsp siap simpan. Mengembalikan nil bila bidan tidak mengisi KPSP
// pada kunjungan ini, sehingga lembar lama (bila ada) ikut terhapus.
//
// Hasil S/M/P SELALU dihitung di server dari jumlah jawaban "Ya", tidak diambil
// dari aplikasi, supaya penilaian tidak dapat dipalsukan dari sisi klien.
func (s *PelayananService) rakitKpsp(bidanID uint, p *models.Pendaftaran, tanggal time.Time, in *KpspInput) (*models.HasilKpsp, error) {
	if in == nil {
		return nil, nil
	}
	usiaBalita := usiaBulan(p.Balita.TanggalLahir, tanggal)
	kelompok, berlaku := models.KelompokUsiaKpsp(usiaBalita)
	if !berlaku {
		return nil, validasi("KPSP hanya untuk balita usia 3-72 bulan (usia balita %s)",
			usiaTeks(p.Balita.TanggalLahir, tanggal))
	}
	// Kelompok umur ditentukan server dari tanggal lahir balita; nilai dari
	// aplikasi hanya diterima bila sama, agar lembar tidak tertukar.
	if in.UsiaBulan != 0 && in.UsiaBulan != kelompok {
		return nil, validasi("kelompok umur KPSP tidak sesuai usia balita (seharusnya %d bulan)", kelompok)
	}
	if len(in.Jawaban) != 10 {
		return nil, validasi("KPSP harus berisi 10 jawaban, diterima %d", len(in.Jawaban))
	}
	if len(strings.TrimSpace(in.Catatan)) > 500 {
		return nil, validasi("catatan KPSP maksimal 500 karakter")
	}

	ada := map[int16]bool{}
	jumlahYa := 0
	jawaban := make([]models.JawabanKpsp, 0, 10)
	for _, j := range in.Jawaban {
		if j.Nomor < 1 || j.Nomor > 10 {
			return nil, validasi("nomor pertanyaan KPSP harus 1-10, diterima %d", j.Nomor)
		}
		if ada[j.Nomor] {
			return nil, validasi("jawaban KPSP nomor %d dikirim lebih dari sekali", j.Nomor)
		}
		ada[j.Nomor] = true
		if j.Ya {
			jumlahYa++
		}
		jawaban = append(jawaban, models.JawabanKpsp{Nomor: j.Nomor, Ya: j.Ya})
	}
	for n := int16(1); n <= 10; n++ {
		if !ada[n] {
			return nil, validasi("jawaban KPSP nomor %d belum diisi", n)
		}
	}

	pid := p.ID
	return &models.HasilKpsp{
		BalitaID:      p.BalitaID,
		PendaftaranID: &pid,
		UsiaBulan:     kelompok,
		JumlahYa:      int16(jumlahYa),
		Hasil:         models.HitungHasilKpsp(jumlahYa),
		Tanggal:       tanggal,
		Catatan:       strings.TrimSpace(in.Catatan),
		DicatatOleh:   bidanID,
		Version:       1,
		Jawaban:       jawaban,
	}, nil
}