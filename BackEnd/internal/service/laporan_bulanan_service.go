package service

import (
	"sort"
	"strings"

	"posyandu-api/internal/repository"

	"github.com/google/uuid"
)

// ============================================================================
// LAPORAN BULANAN POSYANDU (sekretaris & bidan)
//
// Menggabungkan data yang sudah ada (rekap gizi, SKDN, kehadiran, suplemen)
// ditambah imunisasi per jenis imunisasi, untuk satu bulan.
// ============================================================================

type LaporanBulananService struct {
	rekapRepo *repository.RekapRepository
	repo      *repository.LaporanBulananRepository
	rekap     *RekapService
	skdn      *SkdnService
}

func NewLaporanBulananService(rekapRepo *repository.RekapRepository, repo *repository.LaporanBulananRepository,
	rekap *RekapService, skdn *SkdnService) *LaporanBulananService {
	return &LaporanBulananService{rekapRepo: rekapRepo, repo: repo, rekap: rekap, skdn: skdn}
}

type KegiatanLaporan struct {
	JumlahSesi  int      `json:"jumlah_sesi"`
	TanggalSesi []string `json:"tanggal_sesi"`
	Sasaran     int      `json:"sasaran"`
	Didaftarkan int      `json:"didaftarkan"`
	Hadir       int      `json:"hadir"`
	TidakHadir  int      `json:"tidak_hadir"`
	PersenHadir float64  `json:"persen_hadir"`
}

type SkdnLaporan struct {
	S        int     `json:"s"`
	K        int     `json:"k"`
	D        int     `json:"d"`
	N        int     `json:"n"`
	T        int     `json:"t"`
	DuaT     int     `json:"dua_t"`
	Bgm      int     `json:"bgm"`
	PersenKS float64 `json:"persen_ks"`
	PersenDS float64 `json:"persen_ds"`
	PersenND float64 `json:"persen_nd"`
}

type KategoriGiziLaporan struct {
	Label  string  `json:"label"`
	Indeks string  `json:"indeks"`
	Jumlah int     `json:"jumlah"`
	Persen float64 `json:"persen"`
}

type GiziLaporan struct {
	Diukur      int                   `json:"diukur"`
	Normal      int                   `json:"normal"`
	Stunting    int                   `json:"stunting"`
	Wasting     int                   `json:"wasting"`
	Underweight int                   `json:"underweight"`
	GiziLebih   int                   `json:"gizi_lebih"`
	Kategori    []KategoriGiziLaporan `json:"kategori"`
}

type JumlahLaporan struct {
	Nama   string `json:"nama"`
	Jumlah int    `json:"jumlah"`
}

type BalitaBerisikoLaporan struct {
	Nama         string   `json:"nama"`
	JenisKelamin string   `json:"jenis_kelamin"`
	UsiaTeks     string   `json:"usia_teks"`
	Masalah      []string `json:"masalah"`
}

type LaporanBulananResp struct {
	Bulan          string                  `json:"bulan"`
	Label          string                  `json:"label"`
	Posyandu       string                  `json:"posyandu"`
	Kegiatan       KegiatanLaporan         `json:"kegiatan"`
	Skdn           SkdnLaporan             `json:"skdn"`
	Gizi           GiziLaporan             `json:"gizi"`
	Imunisasi      []JumlahLaporan         `json:"imunisasi"`
	TotalImunisasi int                     `json:"total_imunisasi"`
	Suplemen       []JumlahLaporan         `json:"suplemen"`
	BalitaBerisiko []BalitaBerisikoLaporan `json:"balita_berisiko"`
}

func labelSuplemenLaporan(jenis string) string {
	switch {
	case isVitaminA(jenis):
		return "Vitamin A"
	case isObatCacing(jenis):
		return "Obat Cacing"
	}
	j := strings.TrimSpace(jenis)
	if strings.EqualFold(j, "pmt") || strings.Contains(strings.ToLower(j), "pmt") {
		return "PMT"
	}
	if j == "" {
		return "Lainnya"
	}
	return j
}

// Laporan: laporan bulanan posyandu [pos] untuk [bulan] (YYYY-MM, kosong = bulan berjalan).
func (s *LaporanBulananService) Laporan(pos, bulan string) (*LaporanBulananResp, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	dari, sampai, err := rentangBulan(bulan)
	if err != nil {
		return nil, err
	}
	kode := dari.Format("2006-01")
	out := &LaporanBulananResp{Bulan: kode, Label: labelBulan(dari), Posyandu: pos,
		Imunisasi: []JumlahLaporan{}, Suplemen: []JumlahLaporan{}, BalitaBerisiko: []BalitaBerisikoLaporan{}}

	// ------------------------------------------------ I. kegiatan & kehadiran
	jadwal, err := s.repo.JadwalRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	out.Kegiatan.JumlahSesi = len(jadwal)
	out.Kegiatan.TanggalSesi = make([]string, 0, len(jadwal))
	for _, j := range jadwal {
		out.Kegiatan.TanggalSesi = append(out.Kegiatan.TanggalSesi, j.Tanggal.Format("2006-01-02"))
	}
	th, err := s.rekap.TidakHadir(pos, kode)
	if err != nil {
		return nil, err
	}
	out.Kegiatan.Sasaran = th.Sasaran
	daftar, err := s.rekapRepo.PendaftaranRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	for _, p := range daftar {
		if p.StatusKehadiran == "batal" || p.WaktuBatal != nil {
			continue
		}
		out.Kegiatan.Didaftarkan++
		if p.WaktuCheckin != nil {
			out.Kegiatan.Hadir++
		}
	}
	out.Kegiatan.TidakHadir = out.Kegiatan.Didaftarkan - out.Kegiatan.Hadir
	out.Kegiatan.PersenHadir = persenRekap(out.Kegiatan.Hadir, out.Kegiatan.Didaftarkan)

	// ------------------------------------------------ II. SKDN
	sk, err := s.skdn.Hitung(pos, kode)
	if err != nil {
		return nil, err
	}
	out.Skdn = SkdnLaporan{S: sk.S, K: sk.K, D: sk.D, N: sk.N, T: sk.T, DuaT: sk.DuaT, Bgm: sk.Bgm,
		PersenKS: sk.PersenKS, PersenDS: sk.PersenDS, PersenND: sk.PersenND}

	// ------------------------------------------------ III. status gizi
	gz, err := s.rekap.RekapGizi(pos, kode)
	if err != nil {
		return nil, err
	}
	out.Gizi = GiziLaporan{Diukur: gz.Diukur, Normal: gz.Normal, Stunting: gz.Stunting, Wasting: gz.Wasting,
		Underweight: gz.Underweight, GiziLebih: gz.GiziLebih, Kategori: []KategoriGiziLaporan{}}
	for _, k := range gz.Kategori {
		out.Gizi.Kategori = append(out.Gizi.Kategori,
			KategoriGiziLaporan{Label: k.Label, Indeks: k.Indeks, Jumlah: k.Jumlah, Persen: k.Persen})
	}

	// ------------------------------------------------ IV. imunisasi
	imun, err := s.repo.ImunisasiPerJenis(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	for _, x := range imun {
		out.Imunisasi = append(out.Imunisasi, JumlahLaporan{Nama: x.Nama, Jumlah: x.Jumlah})
		out.TotalImunisasi += x.Jumlah
	}

	// ------------------------------------------------ V. suplemen
	sup, err := s.rekapRepo.SuplemenRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	petaSup := map[string]map[uuid.UUID]bool{}
	urutSup := []string{}
	for _, x := range sup {
		l := labelSuplemenLaporan(x.Jenis)
		if _, ada := petaSup[l]; !ada {
			petaSup[l] = map[uuid.UUID]bool{}
			urutSup = append(urutSup, l)
		}
		petaSup[l][x.BalitaID] = true
	}
	prioritasSup := map[string]int{"Vitamin A": 0, "Obat Cacing": 1, "PMT": 2}
	sort.SliceStable(urutSup, func(i, j int) bool {
		pi, oki := prioritasSup[urutSup[i]]
		pj, okj := prioritasSup[urutSup[j]]
		if !oki {
			pi = 9
		}
		if !okj {
			pj = 9
		}
		if pi != pj {
			return pi < pj
		}
		return urutSup[i] < urutSup[j]
	})
	for _, l := range urutSup {
		out.Suplemen = append(out.Suplemen, JumlahLaporan{Nama: l, Jumlah: len(petaSup[l])})
	}

	// ------------------------------------------------ VI. balita berisiko
	indeks := map[uuid.UUID]int{}
	tambahMasalah := func(id uuid.UUID, a BalitaRekap, masalah ...string) {
		i, ada := indeks[id]
		if !ada {
			out.BalitaBerisiko = append(out.BalitaBerisiko, BalitaBerisikoLaporan{
				Nama: a.Nama, JenisKelamin: a.JenisKelamin, UsiaTeks: a.UsiaTeks, Masalah: []string{}})
			i = len(out.BalitaBerisiko) - 1
			indeks[id] = i
		}
		for _, m := range masalah {
			m = strings.TrimSpace(m)
			if m == "" {
				continue
			}
			sudah := false
			for _, x := range out.BalitaBerisiko[i].Masalah {
				if strings.EqualFold(x, m) {
					sudah = true
					break
				}
			}
			if !sudah {
				out.BalitaBerisiko[i].Masalah = append(out.BalitaBerisiko[i].Masalah, m)
			}
		}
	}
	for _, a := range gz.Prioritas {
		tambahMasalah(a.BalitaID, a.BalitaRekap, a.Masalah...)
	}
	for _, a := range sk.PerluRujuk {
		m := []string{}
		if a.DuaT {
			m = append(m, "2T (2 kali tidak naik)")
		}
		if a.Bgm {
			m = append(m, "BGM")
		}
		tambahMasalah(a.BalitaID, a.BalitaRekap, m...)
	}
	sort.SliceStable(out.BalitaBerisiko, func(i, j int) bool {
		return strings.ToLower(out.BalitaBerisiko[i].Nama) < strings.ToLower(out.BalitaBerisiko[j].Nama)
	})

	return out, nil
}