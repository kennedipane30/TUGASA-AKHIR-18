package service

import (
	"sort"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
)

// ============================================================================
// RINGKASAN PENIMBANGAN (SKDN)
//
//   S = Sasaran          : balita aktif usia 0-59 bulan di posyandu
//   K = Punya Buku KIA   : dianggap sama dengan S (semua balita terdaftar punya Buku KIA)
//   D = Ditimbang        : balita sasaran yang ditimbang pada bulan itu
//   N = Naik             : balita yang ditimbang dan berat badannya naik sesuai KBM
//
// Rincian D = N + T + O + B (dari tabel penilaian_timbang).
// Penimbangan yang belum dinilai dimasukkan ke O (belum bisa dinilai).
// Indikator: K/S, D/S (target >= 85%), N/D, D/K, N/S.
// Tidak ada tabel baru: dihitung dari anak, pengukuran, dan penilaian_timbang.
// Dipakai sekretaris dan bidan (hanya posyandunya sendiri).
// ============================================================================

const targetDS = 85.0
const jumlahBulanTren = 6

type SkdnService struct {
	rekap *repository.RekapRepository
	repo  *repository.SkdnRepository
}

func NewSkdnService(rekap *repository.RekapRepository, repo *repository.SkdnRepository) *SkdnService {
	return &SkdnService{rekap: rekap, repo: repo}
}

// SkdnBulan: angka SKDN satu bulan.
type SkdnBulan struct {
	Bulan string `json:"bulan"` // YYYY-MM
	Label string `json:"label"` // "November 2026"

	S int `json:"s"`
	K int `json:"k"`
	D int `json:"d"`
	N int `json:"n"`

	T           int `json:"t"`
	O           int `json:"o"`
	B           int `json:"b"`
	DuaT        int `json:"dua_t"`
	Bgm         int `json:"bgm"`
	TidakDatang int `json:"tidak_datang"`

	PersenKS float64 `json:"persen_ks"`
	PersenDS float64 `json:"persen_ds"`
	PersenND float64 `json:"persen_nd"`
	PersenDK float64 `json:"persen_dk"`
	PersenNS float64 `json:"persen_ns"`
}

// AnakSkdn: balita yang perlu perhatian pada bulan itu.
type AnakSkdn struct {
	AnakRekap
	TanggalUkur  string  `json:"tanggal_ukur"`
	BbKg         float64 `json:"bb_kg"`
	Status       string  `json:"status"` // N | T | O | B
	KenaikanGram *int    `json:"kenaikan_gram"`
	KbmGram      *int    `json:"kbm_gram"`
	DuaT         bool    `json:"dua_t"`
	Bgm          bool    `json:"bgm"`
	Keterangan   string  `json:"keterangan"`
}

type SkdnResp struct {
	SkdnBulan
	Posyandu   string      `json:"posyandu"`
	TargetDS   float64     `json:"target_ds"`
	Tren       []SkdnBulan `json:"tren"`        // 6 bulan terakhir, terlama di awal
	PerluRujuk []AnakSkdn  `json:"perlu_rujuk"` // 2T atau BGM
	TidakNaik  []AnakSkdn  `json:"tidak_naik"`  // T (bukan 2T/BGM)
}

type hasilSkdn struct {
	angka   SkdnBulan
	rujuk   []AnakSkdn
	tdkNaik []AnakSkdn
}

func (s *SkdnService) hitungBulan(pos string, semuaAnak []models.Anak, dari time.Time, rinci bool) (*hasilSkdn, error) {
	sampai := dari.AddDate(0, 1, 0)
	acuan := sampai.AddDate(0, 0, -1)
	if hi := tglRekap(hariIni()); acuan.After(hi) {
		acuan = hi
	}

	out := &hasilSkdn{
		angka:   SkdnBulan{Bulan: dari.Format("2006-01"), Label: labelBulan(dari)},
		rujuk:   []AnakSkdn{},
		tdkNaik: []AnakSkdn{},
	}
	if acuan.Before(dari) {
		return out, nil
	}

	sasaran := sasaranBalita(semuaAnak, acuan)
	ditimbang, err := s.rekap.DitimbangRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	penilaian, err := s.repo.PenilaianRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	nilaiAnak := map[uuid.UUID]models.PenilaianTimbang{}
	for _, p := range penilaian {
		if _, ada := nilaiAnak[p.AnakID]; !ada {
			nilaiAnak[p.AnakID] = p // terbaru di bulan itu
		}
	}

	a := &out.angka
	a.S = len(sasaran)
	a.K = a.S
	for i := range sasaran {
		anak := &sasaran[i]
		tgl, ok := ditimbang[anak.ID]
		if !ok {
			continue
		}
		a.D++
		p, adaNilai := nilaiAnak[anak.ID]
		status := models.StatusTimbangO
		if adaNilai && p.Status != "" {
			status = p.Status
		}
		switch status {
		case models.StatusTimbangNaik:
			a.N++
		case models.StatusTimbangTidakNaik:
			a.T++
		case models.StatusTimbangBaru:
			a.B++
		default:
			a.O++
		}
		if adaNilai && p.DuaT {
			a.DuaT++
		}
		if adaNilai && p.Bgm {
			a.Bgm++
		}

		if !rinci || !adaNilai {
			continue
		}
		perluRujuk := p.DuaT || p.Bgm
		if !perluRujuk && status != models.StatusTimbangTidakNaik {
			continue
		}
		it := AnakSkdn{
			AnakRekap:   anakRekap(anak, tglRekap(tgl)),
			TanggalUkur: tglRekap(tgl).Format("2006-01-02"),
			BbKg:        p.BbKg, Status: status,
			KenaikanGram: p.KenaikanGram, KbmGram: p.KbmGram,
			DuaT: p.DuaT, Bgm: p.Bgm,
		}
		switch {
		case p.DuaT && p.Bgm:
			it.Keterangan = "Tidak naik 2 bulan berturut-turut dan berat badan sangat kurang (BGM)"
		case p.DuaT:
			it.Keterangan = "Tidak naik 2 bulan berturut-turut (2T)"
		case p.Bgm:
			it.Keterangan = "Berat badan sangat kurang / di bawah garis merah (BGM)"
		default:
			it.Keterangan = "Berat badan tidak naik bulan ini"
		}
		if perluRujuk {
			out.rujuk = append(out.rujuk, it)
		} else {
			out.tdkNaik = append(out.tdkNaik, it)
		}
	}

	a.TidakDatang = a.S - a.D
	a.PersenKS = persenRekap(a.K, a.S)
	a.PersenDS = persenRekap(a.D, a.S)
	a.PersenND = persenRekap(a.N, a.D)
	a.PersenDK = persenRekap(a.D, a.K)
	a.PersenNS = persenRekap(a.N, a.S)

	urut := func(l []AnakSkdn) {
		sort.SliceStable(l, func(i, j int) bool { return l[i].Nama < l[j].Nama })
	}
	urut(out.rujuk)
	urut(out.tdkNaik)
	return out, nil
}

// Hitung: SKDN posyandu [pos] untuk [bulan] (YYYY-MM, kosong = bulan berjalan)
// beserta tren 6 bulan terakhir.
func (s *SkdnService) Hitung(pos, bulan string) (*SkdnResp, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	dari, _, err := rentangBulan(bulan)
	if err != nil {
		return nil, err
	}
	anak, err := s.rekap.AnakAktif(pos)
	if err != nil {
		return nil, err
	}

	utama, err := s.hitungBulan(pos, anak, dari, true)
	if err != nil {
		return nil, err
	}
	out := &SkdnResp{
		SkdnBulan: utama.angka, Posyandu: pos, TargetDS: targetDS,
		Tren: []SkdnBulan{}, PerluRujuk: utama.rujuk, TidakNaik: utama.tdkNaik,
	}
	for i := jumlahBulanTren - 1; i >= 1; i-- {
		b := dari.AddDate(0, -i, 0)
		h, err := s.hitungBulan(pos, anak, b, false)
		if err != nil {
			return nil, err
		}
		out.Tren = append(out.Tren, h.angka)
	}
	out.Tren = append(out.Tren, utama.angka)
	return out, nil
}