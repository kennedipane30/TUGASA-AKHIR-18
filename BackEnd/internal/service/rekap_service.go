package service

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
)

// ============================================================================
// REKAP POSYANDU
//
//   1. Rekap status gizi    : kategori Permenkes No. 2 Tahun 2020 per bulan.
//   2. Rekap Vitamin A      : bulan Februari dan Agustus (kapsul biru 6-11 bln,
//      dan obat cacing        kapsul merah 12-59 bln); obat cacing per semester
//                             untuk usia 12-59 bulan.
//   3. Balita tidak hadir   : sasaran (S) dikurangi yang ditimbang (D) pada bulan itu.
// ============================================================================

type RekapService struct{ repo *repository.RekapRepository }

func NewRekapService(repo *repository.RekapRepository) *RekapService { return &RekapService{repo} }

var namaBulanRekap = []string{"", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
	"Juli", "Agustus", "September", "Oktober", "November", "Desember"}

const batasUsiaBalita = 59

// rentangBulan: "2026-11" -> [1 Nov 2026, 1 Des 2026). Kosong = bulan berjalan.
func rentangBulan(s string) (time.Time, time.Time, error) {
	s = strings.TrimSpace(s)
	var awal time.Time
	if s == "" {
		n := time.Now()
		awal = time.Date(n.Year(), n.Month(), 1, 0, 0, 0, 0, time.UTC)
	} else {
		t, err := time.Parse("2006-01", s)
		if err != nil {
			return time.Time{}, time.Time{}, validasi("bulan harus berformat YYYY-MM")
		}
		awal = time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC)
	}
	return awal, awal.AddDate(0, 1, 0), nil
}

func labelBulan(t time.Time) string { return fmt.Sprintf("%s %d", namaBulanRekap[t.Month()], t.Year()) }

func persenRekap(a, b int) float64 {
	if b == 0 {
		return 0
	}
	return math.Round(float64(a)*1000/float64(b)) / 10
}

func tglRekap(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// sasaranBalita: anak lahir sebelum [acuan] dan berusia 0-59 bulan pada [acuan].
func sasaranBalita(anak []models.Anak, acuan time.Time) []models.Anak {
	out := make([]models.Anak, 0, len(anak))
	for _, a := range anak {
		lahir := tglRekap(a.TanggalLahir)
		if lahir.After(acuan) {
			continue
		}
		if usiaBulan(lahir, acuan) > batasUsiaBalita {
			continue
		}
		out = append(out, a)
	}
	return out
}

type AnakRekap struct {
	AnakID       uuid.UUID `json:"anak_id"`
	Nama         string    `json:"nama"`
	JenisKelamin string    `json:"jenis_kelamin"`
	TanggalLahir string    `json:"tanggal_lahir"`
	UsiaBulan    int       `json:"usia_bulan"`
	UsiaTeks     string    `json:"usia_teks"`
}

func anakRekap(a *models.Anak, acuan time.Time) AnakRekap {
	lahir := tglRekap(a.TanggalLahir)
	return AnakRekap{
		AnakID: a.ID, Nama: a.Nama, JenisKelamin: a.JenisKelamin,
		TanggalLahir: lahir.Format("2006-01-02"),
		UsiaBulan:    usiaBulan(lahir, acuan), UsiaTeks: usiaTeks(lahir, acuan),
	}
}

// ---------------------------------------------------------------- 1. status gizi

type KategoriGiziRekap struct {
	Kode    string  `json:"kode"`
	Label   string  `json:"label"`
	Indeks  string  `json:"indeks"`
	Jumlah  int     `json:"jumlah"`
	Persen  float64 `json:"persen"`
	Tingkat string  `json:"tingkat"` // baik | waspada | risiko
}

type AnakGiziRekap struct {
	AnakRekap
	TanggalUkur  string   `json:"tanggal_ukur"`
	ZBbu         *float64 `json:"z_bbu"`
	ZTbu         *float64 `json:"z_tbu"`
	ZBbtb        *float64 `json:"z_bbtb"`
	KategoriBbu  string   `json:"kategori_bbu"`
	KategoriTbu  string   `json:"kategori_tbu"`
	KategoriBbtb string   `json:"kategori_bbtb"`
	Masalah      []string `json:"masalah"`
}

type TrenGiziRekap struct {
	Bulan       string `json:"bulan"`
	Label       string `json:"label"`
	Diukur      int    `json:"diukur"`
	Stunting    int    `json:"stunting"`
	Wasting     int    `json:"wasting"`
	Underweight int    `json:"underweight"`
}

type RekapGiziResp struct {
	Bulan       string              `json:"bulan"`
	Label       string              `json:"label"`
	Posyandu    string              `json:"posyandu"`
	Sasaran     int                 `json:"sasaran"`
	Diukur      int                 `json:"diukur"`
	Partisipasi float64             `json:"partisipasi"`
	Normal      int                 `json:"normal"`
	Stunting    int                 `json:"stunting"`
	Wasting     int                 `json:"wasting"`
	Underweight int                 `json:"underweight"`
	GiziLebih   int                 `json:"gizi_lebih"`
	Kategori    []KategoriGiziRekap `json:"kategori"`
	Tren        []TrenGiziRekap     `json:"tren"`
	Prioritas   []AnakGiziRekap     `json:"prioritas"`
}

type hitungGizi struct {
	sangatPendek, pendek, giziBuruk, giziKurang, bbSangatKurang, bbKurang, giziLebih, berisikoLebih, normal int
	stunting, wasting, underweight                                                                          int
}

func kurang(z *float64, batas float64) bool { return z != nil && *z < batas }
func lebih(z *float64, batas float64) bool  { return z != nil && *z > batas }

// masalahGizi: kategori bermasalah satu status gizi (Permenkes No. 2 Tahun 2020).
func masalahGizi(g *models.StatusGizi) []string {
	m := []string{}
	switch {
	case kurang(g.ZBbtb, -3):
		m = append(m, "Gizi buruk")
	case kurang(g.ZBbtb, -2):
		m = append(m, "Gizi kurang")
	case lebih(g.ZBbtb, 3):
		m = append(m, "Obesitas")
	case lebih(g.ZBbtb, 2):
		m = append(m, "Gizi lebih")
	}
	switch {
	case kurang(g.ZTbu, -3):
		m = append(m, "Sangat pendek")
	case kurang(g.ZTbu, -2):
		m = append(m, "Pendek")
	}
	switch {
	case kurang(g.ZBbu, -3):
		m = append(m, "BB sangat kurang")
	case kurang(g.ZBbu, -2):
		m = append(m, "BB kurang")
	}
	return m
}

func (h *hitungGizi) tambah(g *models.StatusGizi) {
	switch {
	case kurang(g.ZTbu, -3):
		h.sangatPendek++
		h.stunting++
	case kurang(g.ZTbu, -2):
		h.pendek++
		h.stunting++
	}
	switch {
	case kurang(g.ZBbtb, -3):
		h.giziBuruk++
		h.wasting++
	case kurang(g.ZBbtb, -2):
		h.giziKurang++
		h.wasting++
	case lebih(g.ZBbtb, 2):
		h.giziLebih++
	case lebih(g.ZBbtb, 1):
		h.berisikoLebih++
	}
	switch {
	case kurang(g.ZBbu, -3):
		h.bbSangatKurang++
		h.underweight++
	case kurang(g.ZBbu, -2):
		h.bbKurang++
		h.underweight++
	}
	if len(masalahGizi(g)) == 0 {
		h.normal++
	}
}

// terbaruPerAnak: satu status gizi terbaru per anak (list sudah urut terbaru di atas).
func terbaruPerAnak(list []models.StatusGizi, sasaran map[uuid.UUID]bool) []models.StatusGizi {
	sudah := map[uuid.UUID]bool{}
	out := []models.StatusGizi{}
	for _, g := range list {
		if sudah[g.AnakID] || (sasaran != nil && !sasaran[g.AnakID]) {
			continue
		}
		sudah[g.AnakID] = true
		out = append(out, g)
	}
	return out
}

func (s *RekapService) RekapGizi(pos, bulan string) (*RekapGiziResp, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	dari, sampai, err := rentangBulan(bulan)
	if err != nil {
		return nil, err
	}
	acuan := sampai.AddDate(0, 0, -1)
	anak, err := s.repo.AnakAktif(pos)
	if err != nil {
		return nil, err
	}
	sasaran := sasaranBalita(anak, acuan)
	petaSasaran := map[uuid.UUID]bool{}
	petaAnak := map[uuid.UUID]*models.Anak{}
	for i := range sasaran {
		petaSasaran[sasaran[i].ID] = true
		petaAnak[sasaran[i].ID] = &sasaran[i]
	}

	list, err := s.repo.StatusGiziRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	terbaru := terbaruPerAnak(list, petaSasaran)

	var h hitungGizi
	prioritas := []AnakGiziRekap{}
	for i := range terbaru {
		g := &terbaru[i]
		h.tambah(g)
		m := masalahGizi(g)
		a := petaAnak[g.AnakID]
		if len(m) == 0 || a == nil {
			continue
		}
		prioritas = append(prioritas, AnakGiziRekap{
			AnakRekap:   anakRekap(a, g.TanggalUkur),
			TanggalUkur: g.TanggalUkur.Format("2006-01-02"),
			ZBbu:        g.ZBbu, ZTbu: g.ZTbu, ZBbtb: g.ZBbtb,
			KategoriBbu: g.KategoriBbu, KategoriTbu: g.KategoriTbu, KategoriBbtb: g.KategoriBbtb,
			Masalah: m,
		})
	}
	bobot := func(x AnakGiziRekap) int {
		b := 0
		for _, m := range x.Masalah {
			switch m {
			case "Gizi buruk", "Sangat pendek", "BB sangat kurang":
				b += 3
			case "Gizi kurang", "Pendek", "BB kurang":
				b += 2
			default:
				b++
			}
		}
		return b
	}
	sort.SliceStable(prioritas, func(i, j int) bool { return bobot(prioritas[i]) > bobot(prioritas[j]) })

	n := len(terbaru)
	kat := func(kode, label, indeks, tingkat string, jml int) KategoriGiziRekap {
		return KategoriGiziRekap{Kode: kode, Label: label, Indeks: indeks, Jumlah: jml, Persen: persenRekap(jml, n), Tingkat: tingkat}
	}
	out := &RekapGiziResp{
		Bulan: dari.Format("2006-01"), Label: labelBulan(dari), Posyandu: pos,
		Sasaran: len(sasaran), Diukur: n, Partisipasi: persenRekap(n, len(sasaran)),
		Normal: h.normal, Stunting: h.stunting, Wasting: h.wasting, Underweight: h.underweight, GiziLebih: h.giziLebih,
		Kategori: []KategoriGiziRekap{
			kat("sangat_pendek", "Sangat pendek", "TB/U < -3 SD", models.TingkatRisiko, h.sangatPendek),
			kat("pendek", "Pendek", "TB/U -3 s.d. < -2 SD", models.TingkatWaspada, h.pendek),
			kat("gizi_buruk", "Gizi buruk", "BB/TB < -3 SD", models.TingkatRisiko, h.giziBuruk),
			kat("gizi_kurang", "Gizi kurang", "BB/TB -3 s.d. < -2 SD", models.TingkatWaspada, h.giziKurang),
			kat("bb_sangat_kurang", "BB sangat kurang", "BB/U < -3 SD", models.TingkatRisiko, h.bbSangatKurang),
			kat("bb_kurang", "BB kurang", "BB/U -3 s.d. < -2 SD", models.TingkatWaspada, h.bbKurang),
			kat("berisiko_lebih", "Berisiko gizi lebih", "BB/TB > +1 s.d. +2 SD", models.TingkatWaspada, h.berisikoLebih),
			kat("gizi_lebih", "Gizi lebih / obesitas", "BB/TB > +2 SD", models.TingkatRisiko, h.giziLebih),
			kat("normal", "Normal (tanpa masalah)", "Semua indeks normal", models.TingkatBaik, h.normal),
		},
		Prioritas: prioritas,
	}

	// tren 6 bulan sampai bulan terpilih
	for k := 5; k >= 0; k-- {
		a := dari.AddDate(0, -k, 0)
		b := a.AddDate(0, 1, 0)
		var lst []models.StatusGizi
		if k == 0 {
			lst = list
		} else if lst, err = s.repo.StatusGiziRentang(pos, a, b); err != nil {
			return nil, err
		}
		var t hitungGizi
		tb := terbaruPerAnak(lst, nil)
		for i := range tb {
			t.tambah(&tb[i])
		}
		out.Tren = append(out.Tren, TrenGiziRekap{
			Bulan: a.Format("2006-01"), Label: namaBulanRekap[a.Month()][:3],
			Diukur: len(tb), Stunting: t.stunting, Wasting: t.wasting, Underweight: t.underweight,
		})
	}
	return out, nil
}

// ---------------------------------------------------------------- 2. Vitamin A & obat cacing

type KelompokSuplemenRekap struct {
	Kode       string  `json:"kode"`
	Label      string  `json:"label"`
	Keterangan string  `json:"keterangan"`
	Sasaran    int     `json:"sasaran"`
	Sudah      int     `json:"sudah"`
	Belum      int     `json:"belum"`
	Persen     float64 `json:"persen"`
}

type AnakSuplemenRekap struct {
	AnakRekap
	Kelompok string   `json:"kelompok"`
	Belum    []string `json:"belum"`
}

type RekapSuplemenResp struct {
	Tahun         int                     `json:"tahun"`
	Periode       int                     `json:"periode"` // 1 = Februari, 2 = Agustus
	Label         string                  `json:"label"`
	RentangDari   string                  `json:"rentang_dari"`
	RentangSampai string                  `json:"rentang_sampai"`
	TanggalAcuan  string                  `json:"tanggal_acuan"`
	VitaminA      []KelompokSuplemenRekap `json:"vitamin_a"`
	ObatCacing    KelompokSuplemenRekap   `json:"obat_cacing"`
	BelumMenerima []AnakSuplemenRekap     `json:"belum_menerima"`
}

func isVitaminA(jenis string) bool {
	j := strings.ToLower(strings.TrimSpace(jenis))
	return j == "vitamin_a" || strings.Contains(j, "vitamin a") || strings.Contains(j, "vit a") || strings.Contains(j, "vit. a")
}

func isObatCacing(jenis string) bool {
	j := strings.ToLower(strings.TrimSpace(jenis))
	return j == "obat_cacing" || strings.Contains(j, "cacing") || strings.Contains(j, "albendazol") || strings.Contains(j, "pirantel")
}

func kelompokSuplemen(kode, label, ket string, sasaran, sudah int) KelompokSuplemenRekap {
	return KelompokSuplemenRekap{Kode: kode, Label: label, Keterangan: ket, Sasaran: sasaran, Sudah: sudah,
		Belum: sasaran - sudah, Persen: persenRekap(sudah, sasaran)}
}

func (s *RekapService) RekapSuplemen(pos string, tahun, periode int) (*RekapSuplemenResp, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	n := time.Now()
	if tahun == 0 {
		tahun = n.Year()
	}
	if periode == 0 {
		periode = 1
		if n.Month() >= time.July {
			periode = 2
		}
	}
	if periode != 1 && periode != 2 {
		return nil, validasi("periode harus 1 (Februari) atau 2 (Agustus)")
	}
	if tahun < 2000 || tahun > 2100 {
		return nil, validasi("tahun tidak valid")
	}
	bulanVit := time.February
	dari := time.Date(tahun, time.January, 1, 0, 0, 0, 0, time.UTC)
	if periode == 2 {
		bulanVit = time.August
		dari = time.Date(tahun, time.July, 1, 0, 0, 0, 0, time.UTC)
	}
	sampai := dari.AddDate(0, 6, 0)
	acuan := time.Date(tahun, bulanVit+1, 1, 0, 0, 0, 0, time.UTC).AddDate(0, 0, -1) // akhir bulan vitamin A

	anak, err := s.repo.AnakAktif(pos)
	if err != nil {
		return nil, err
	}
	sup, err := s.repo.SuplemenRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	dapatVit := map[uuid.UUID]bool{}
	dapatCacing := map[uuid.UUID]bool{}
	for _, x := range sup {
		if isVitaminA(x.Jenis) {
			dapatVit[x.AnakID] = true
		}
		if isObatCacing(x.Jenis) {
			dapatCacing[x.AnakID] = true
		}
	}

	var sasBiru, sudahBiru, sasMerah, sudahMerah, sasCacing, sudahCacing int
	belum := []AnakSuplemenRekap{}
	for i := range anak {
		a := &anak[i]
		lahir := tglRekap(a.TanggalLahir)
		if lahir.After(acuan) {
			continue
		}
		u := usiaBulan(lahir, acuan)
		if u < 6 || u > batasUsiaBalita {
			continue
		}
		item := AnakSuplemenRekap{AnakRekap: anakRekap(a, acuan), Belum: []string{}}
		if u <= 11 {
			item.Kelompok = "6-11 bulan"
			sasBiru++
			if dapatVit[a.ID] {
				sudahBiru++
			} else {
				item.Belum = append(item.Belum, "Vitamin A biru (100.000 IU)")
			}
		} else {
			item.Kelompok = "12-59 bulan"
			sasMerah++
			if dapatVit[a.ID] {
				sudahMerah++
			} else {
				item.Belum = append(item.Belum, "Vitamin A merah (200.000 IU)")
			}
			sasCacing++
			if dapatCacing[a.ID] {
				sudahCacing++
			} else {
				item.Belum = append(item.Belum, "Obat cacing")
			}
		}
		if len(item.Belum) > 0 {
			belum = append(belum, item)
		}
	}
	sort.SliceStable(belum, func(i, j int) bool { return len(belum[i].Belum) > len(belum[j].Belum) })

	return &RekapSuplemenResp{
		Tahun: tahun, Periode: periode,
		Label:         fmt.Sprintf("%s %d", namaBulanRekap[bulanVit], tahun),
		RentangDari:   dari.Format("2006-01-02"),
		RentangSampai: sampai.AddDate(0, 0, -1).Format("2006-01-02"),
		TanggalAcuan:  acuan.Format("2006-01-02"),
		VitaminA: []KelompokSuplemenRekap{
			kelompokSuplemen("biru", "Kapsul biru", "Bayi 6-11 bulan · 100.000 IU", sasBiru, sudahBiru),
			kelompokSuplemen("merah", "Kapsul merah", "Balita 12-59 bulan · 200.000 IU", sasMerah, sudahMerah),
			kelompokSuplemen("total", "Total Vitamin A", "Balita 6-59 bulan", sasBiru+sasMerah, sudahBiru+sudahMerah),
		},
		ObatCacing:    kelompokSuplemen("cacing", "Obat cacing", "Balita 12-59 bulan · 1 kali per semester", sasCacing, sudahCacing),
		BelumMenerima: belum,
	}, nil
}

// ---------------------------------------------------------------- 3. balita tidak hadir

type AnakTidakHadir struct {
	AnakRekap
	TerakhirDitimbang string `json:"terakhir_ditimbang"` // kosong = belum pernah ditimbang
	BulanTidakDatang  int    `json:"bulan_tidak_datang"` // -1 = belum pernah ditimbang
	SudahMendaftar    bool   `json:"sudah_mendaftar"`    // mendaftar jadwal bulan ini tetapi tidak check-in
	Keterangan        string `json:"keterangan"`
}

type TidakHadirResp struct {
	Bulan        string           `json:"bulan"`
	Label        string           `json:"label"`
	JumlahJadwal int              `json:"jumlah_jadwal"`
	Sasaran      int              `json:"sasaran"`
	Ditimbang    int              `json:"ditimbang"`
	TidakHadir   int              `json:"tidak_hadir"`
	PersenDS     float64          `json:"persen_ds"`
	BelumPernah  int              `json:"belum_pernah"`
	Anak         []AnakTidakHadir `json:"anak"`
}

func (s *RekapService) TidakHadir(pos, bulan string) (*TidakHadirResp, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	dari, sampai, err := rentangBulan(bulan)
	if err != nil {
		return nil, err
	}
	acuan := sampai.AddDate(0, 0, -1)
	if hi := hariIni(); acuan.After(hi) {
		acuan = tglRekap(hi)
	}
	anak, err := s.repo.AnakAktif(pos)
	if err != nil {
		return nil, err
	}
	sasaran := sasaranBalita(anak, acuan)
	ditimbang, err := s.repo.DitimbangRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	sebelumnya, err := s.repo.TimbangTerakhirSebelum(pos, dari)
	if err != nil {
		return nil, err
	}
	daftar, err := s.repo.PendaftaranRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	nJadwal, err := s.repo.JumlahJadwalRentang(pos, dari, sampai)
	if err != nil {
		return nil, err
	}
	mendaftar := map[uuid.UUID]bool{}
	for _, p := range daftar {
		if p.StatusKehadiran != "sudah_checkin" {
			mendaftar[p.AnakID] = true
		}
	}

	out := &TidakHadirResp{
		Bulan: dari.Format("2006-01"), Label: labelBulan(dari), JumlahJadwal: int(nJadwal),
		Sasaran: len(sasaran), Anak: []AnakTidakHadir{},
	}
	for i := range sasaran {
		a := &sasaran[i]
		if _, ok := ditimbang[a.ID]; ok {
			out.Ditimbang++
			continue
		}
		it := AnakTidakHadir{AnakRekap: anakRekap(a, acuan), BulanTidakDatang: -1, SudahMendaftar: mendaftar[a.ID]}
		if t, ok := sebelumnya[a.ID]; ok {
			t = tglRekap(t)
			it.TerakhirDitimbang = t.Format("2006-01-02")
			it.BulanTidakDatang = (dari.Year()-t.Year())*12 + int(dari.Month()-t.Month())
			if it.BulanTidakDatang < 1 {
				it.BulanTidakDatang = 1
			}
			if it.BulanTidakDatang == 1 {
				it.Keterangan = "Tidak datang bulan ini"
			} else {
				it.Keterangan = fmt.Sprintf("Tidak datang %d bulan berturut-turut", it.BulanTidakDatang)
			}
		} else {
			out.BelumPernah++
			it.Keterangan = "Belum pernah ditimbang di posyandu"
		}
		if it.SudahMendaftar {
			it.Keterangan += " · sudah mendaftar tetapi tidak check-in"
		}
		out.Anak = append(out.Anak, it)
	}
	out.TidakHadir = len(out.Anak)
	out.PersenDS = persenRekap(out.Ditimbang, out.Sasaran)
	sort.SliceStable(out.Anak, func(i, j int) bool {
		a, b := out.Anak[i].BulanTidakDatang, out.Anak[j].BulanTidakDatang
		if a == -1 {
			a = 1000
		}
		if b == -1 {
			b = 1000
		}
		if a != b {
			return a > b
		}
		return out.Anak[i].Nama < out.Anak[j].Nama
	})
	return out, nil
}