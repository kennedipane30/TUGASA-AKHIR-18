package service

import (
	"errors"
	"sort"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ============================================================================
// SEMUA BALITA
//
// Daftar seluruh balita (0-59 bulan) di posyandu petugas beserta ringkasan
// penimbangan terakhir, status gizi, status N/T (KBM), 2T/BGM, dan imunisasi.
// Dipakai sekretaris, kader, dan bidan (hanya posyandunya sendiri).
// ============================================================================

type BalitaService struct {
	repo   *repository.BalitaRepository
	vaksin *repository.VaksinRepository
}

func NewBalitaService(repo *repository.BalitaRepository, vaksin *repository.VaksinRepository) *BalitaService {
	return &BalitaService{repo: repo, vaksin: vaksin}
}

type TimbangRingkas struct {
	PengukuranID  uuid.UUID `json:"pengukuran_id"`
	Tanggal       string    `json:"tanggal"`
	UsiaTeks      string    `json:"usia_teks"`
	BbKg          float64   `json:"bb_kg"`
	TbCm          float64   `json:"tb_cm"`
	CaraUkur      string    `json:"cara_ukur"`
	LkCm          *float64  `json:"lingkar_kepala_cm"`
	LilaCm        *float64  `json:"lila_cm"`
	StatusTimbang string    `json:"status_timbang"` // N | T | O | B | ""
	KenaikanGram  *int      `json:"kenaikan_gram"`
	KbmGram       *int      `json:"kbm_gram"`
	DuaT          bool      `json:"dua_t"`
	Bgm           bool      `json:"bgm"`
	KategoriBbu   string    `json:"kategori_bbu"`
	KategoriTbu   string    `json:"kategori_tbu"`
	KategoriBbtb  string    `json:"kategori_bbtb"`
	ZBbu          *float64  `json:"z_bbu"`
	ZTbu          *float64  `json:"z_tbu"`
	ZBbtb         *float64  `json:"z_bbtb"`
	Masalah       []string  `json:"masalah"`
	Tingkat       string    `json:"tingkat"`
}

type BalitaItem struct {
	AnakRekap
	Status           string          `json:"status"`
	KelompokUsia     string          `json:"kelompok_usia"` // 0-11 | 12-23 | 24-59
	JumlahTimbang    int             `json:"jumlah_timbang"`
	Terakhir         *TimbangRingkas `json:"terakhir"`
	BulanTidakDatang int             `json:"bulan_tidak_datang"` // -1 = belum pernah ditimbang
	Vaksin           RingkasanVaksin `json:"vaksin"`
}

type RingkasBalita struct {
	Total       int `json:"total"`
	LakiLaki    int `json:"laki_laki"`
	Perempuan   int `json:"perempuan"`
	Usia0_11    int `json:"usia_0_11"`
	Usia12_23   int `json:"usia_12_23"`
	Usia24_59   int `json:"usia_24_59"`
	MasalahGizi int `json:"masalah_gizi"`
	Stunting    int `json:"stunting"`
	DuaTBgm     int `json:"dua_t_bgm"`
	VaksinTelat int `json:"vaksin_terlambat"`
	BelumPernah int `json:"belum_pernah"`
}

type DaftarBalitaResp struct {
	Posyandu string        `json:"posyandu"`
	Ringkas  RingkasBalita `json:"ringkas"`
	Balita   []BalitaItem  `json:"balita"`
}

type DetailBalitaResp struct {
	Anak     *models.Anak     `json:"anak"`
	Keluarga *models.Keluarga `json:"keluarga"`
	Ringkas  BalitaItem       `json:"ringkas"`
	Riwayat  []TimbangRingkas `json:"riwayat"`
}

func kelompokUsia(u int) string {
	switch {
	case u < 12:
		return "0-11"
	case u < 24:
		return "12-23"
	default:
		return "24-59"
	}
}

func timbangRingkas(lahir time.Time, u *models.Pengukuran, g *models.StatusGizi, p *models.PenilaianTimbang) TimbangRingkas {
	t := TimbangRingkas{
		PengukuranID: u.ID, Tanggal: u.TanggalUkur.Format("2006-01-02"),
		UsiaTeks: usiaTeks(lahir, u.TanggalUkur), BbKg: u.BbKg, TbCm: u.TbCm, CaraUkur: u.CaraUkur,
		LkCm: u.LingkarKepalaCm, LilaCm: u.LilaCm, Masalah: []string{},
	}
	if g != nil {
		t.KategoriBbu, t.KategoriTbu, t.KategoriBbtb = g.KategoriBbu, g.KategoriTbu, g.KategoriBbtb
		t.ZBbu, t.ZTbu, t.ZBbtb = g.ZBbu, g.ZTbu, g.ZBbtb
		t.Masalah = masalahGizi(g)
		t.Tingkat = g.Tingkat
	}
	if p != nil {
		t.StatusTimbang, t.KenaikanGram, t.KbmGram, t.DuaT, t.Bgm = p.Status, p.KenaikanGram, p.KbmGram, p.DuaT, p.Bgm
	}
	return t
}

type dataBalita struct {
	ukur   map[uuid.UUID][]models.Pengukuran
	gizi   map[uuid.UUID]models.StatusGizi
	nilai  map[uuid.UUID]models.PenilaianTimbang
	vaksin map[uuid.UUID][]models.ImunisasiAnak
	master []models.JadwalImunisasi
}

func (s *BalitaService) muatData(anak []models.Anak) (*dataBalita, error) {
	ids := make([]uuid.UUID, 0, len(anak))
	for _, a := range anak {
		ids = append(ids, a.ID)
	}
	ukur, err := s.repo.PengukuranBanyakAnak(ids)
	if err != nil {
		return nil, err
	}
	d := &dataBalita{
		ukur:   map[uuid.UUID][]models.Pengukuran{},
		gizi:   map[uuid.UUID]models.StatusGizi{},
		nilai:  map[uuid.UUID]models.PenilaianTimbang{},
		vaksin: map[uuid.UUID][]models.ImunisasiAnak{},
	}
	uids := make([]uuid.UUID, 0, len(ukur))
	for _, u := range ukur {
		d.ukur[u.AnakID] = append(d.ukur[u.AnakID], u)
		uids = append(uids, u.ID)
	}
	gl, err := s.repo.StatusGiziByPengukuran(uids)
	if err != nil {
		return nil, err
	}
	for _, g := range gl {
		d.gizi[g.PengukuranID] = g
	}
	nl, err := s.repo.PenilaianByPengukuran(uids)
	if err != nil {
		return nil, err
	}
	for _, n := range nl {
		d.nilai[n.PengukuranID] = n
	}
	if d.master, err = s.vaksin.ListJadwalMaster(); err != nil {
		return nil, err
	}
	vl, err := s.vaksin.ListRiwayatBanyakAnak(ids)
	if err != nil {
		return nil, err
	}
	for _, v := range vl {
		d.vaksin[v.AnakID] = append(d.vaksin[v.AnakID], v)
	}
	return d, nil
}

func (d *dataBalita) item(a *models.Anak, hari time.Time) BalitaItem {
	lahir := tglRekap(a.TanggalLahir)
	u := usiaBulan(lahir, hari)
	it := BalitaItem{
		AnakRekap: anakRekap(a, hari), Status: a.Status, KelompokUsia: kelompokUsia(u),
		BulanTidakDatang: -1,
	}
	list := d.ukur[a.ID]
	it.JumlahTimbang = len(list)
	if len(list) > 0 {
		x := list[0]
		var g *models.StatusGizi
		if v, ok := d.gizi[x.ID]; ok {
			g = &v
		}
		var p *models.PenilaianTimbang
		if v, ok := d.nilai[x.ID]; ok {
			p = &v
		}
		t := timbangRingkas(lahir, &x, g, p)
		it.Terakhir = &t
		it.BulanTidakDatang = indeksBulan(hari) - indeksBulan(x.TanggalUkur)
	}
	_, it.Vaksin = hitungJadwal(a, d.master, d.vaksin[a.ID], hari)
	return it
}

// Daftar: semua balita aktif berusia 0-59 bulan di posyandu [pos].
// [cari] menyaring nama; [semua] = true menyertakan anak non-aktif atau di atas 59 bulan.
func (s *BalitaService) Daftar(pos, cari string, semua bool) (*DaftarBalitaResp, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	anak, err := s.repo.AnakPosyandu(pos)
	if err != nil {
		return nil, err
	}
	hari := hariIni()
	cari = strings.ToLower(strings.TrimSpace(cari))
	pilih := make([]models.Anak, 0, len(anak))
	for _, a := range anak {
		lahir := tglRekap(a.TanggalLahir)
		if lahir.After(hari) {
			continue
		}
		if !semua && (a.Status != "aktif" || usiaBulan(lahir, hari) > batasUsiaBalita) {
			continue
		}
		if cari != "" && !strings.Contains(strings.ToLower(a.Nama), cari) {
			continue
		}
		pilih = append(pilih, a)
	}
	d, err := s.muatData(pilih)
	if err != nil {
		return nil, err
	}
	out := &DaftarBalitaResp{Posyandu: pos, Balita: make([]BalitaItem, 0, len(pilih))}
	r := &out.Ringkas
	for i := range pilih {
		it := d.item(&pilih[i], hari)
		out.Balita = append(out.Balita, it)
		r.Total++
		if it.JenisKelamin == "P" {
			r.Perempuan++
		} else {
			r.LakiLaki++
		}
		switch it.KelompokUsia {
		case "0-11":
			r.Usia0_11++
		case "12-23":
			r.Usia12_23++
		default:
			r.Usia24_59++
		}
		if it.Terakhir == nil {
			r.BelumPernah++
		} else {
			if len(it.Terakhir.Masalah) > 0 {
				r.MasalahGizi++
			}
			for _, m := range it.Terakhir.Masalah {
				if m == "Pendek" || m == "Sangat pendek" {
					r.Stunting++
					break
				}
			}
			if it.Terakhir.DuaT || it.Terakhir.Bgm {
				r.DuaTBgm++
			}
		}
		if it.Vaksin.Terlambat > 0 {
			r.VaksinTelat++
		}
	}
	sort.SliceStable(out.Balita, func(i, j int) bool {
		return strings.ToLower(out.Balita[i].Nama) < strings.ToLower(out.Balita[j].Nama)
	})
	return out, nil
}

// Detail: profil, keluarga, ringkasan, dan seluruh riwayat penimbangan satu balita.
func (s *BalitaService) Detail(pos string, anakID uuid.UUID) (*DetailBalitaResp, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	a, err := s.repo.GetAnak(anakID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAnakTidakAda
	}
	if err != nil {
		return nil, err
	}
	p, err := s.repo.PosyanduKeluarga(a.KeluargaID)
	if err != nil {
		return nil, err
	}
	if p != pos {
		return nil, terlarang("anak bukan bagian dari posyandu Anda")
	}
	d, err := s.muatData([]models.Anak{*a})
	if err != nil {
		return nil, err
	}
	out := &DetailBalitaResp{Anak: a, Ringkas: d.item(a, hariIni()), Riwayat: []TimbangRingkas{}}
	if k, err := s.repo.GetKeluarga(a.KeluargaID); err == nil {
		out.Keluarga = k
	}
	lahir := tglRekap(a.TanggalLahir)
	for _, u := range d.ukur[a.ID] {
		x := u
		var g *models.StatusGizi
		if v, ok := d.gizi[x.ID]; ok {
			g = &v
		}
		var n *models.PenilaianTimbang
		if v, ok := d.nilai[x.ID]; ok {
			n = &v
		}
		out.Riwayat = append(out.Riwayat, timbangRingkas(lahir, &x, g, n))
	}
	return out, nil
}

// ============================================================================
// DAFTAR ANAK BERISIKO (deteksi dini, untuk bidan)
//
// Berdasarkan penimbangan terakhir setiap balita aktif:
//   Risiko tinggi : gizi buruk (BB/TB < -3 SD), BGM (BB/U < -3 SD), 2T,
//                   sangat pendek (TB/U < -3 SD)
//   Risiko sedang : gizi kurang (BB/TB < -2 SD), pendek (TB/U < -2 SD),
//                   BB kurang (BB/U < -2 SD), tidak naik (T) bulan ini,
//                   gizi lebih / obesitas (BB/TB > +2 SD)
// Diurutkan dari skor risiko tertinggi.
// ============================================================================

type AnakBerisiko struct {
	BalitaItem
	Alasan  []string `json:"alasan"`
	Skor    int      `json:"skor"`
	Tingkat string   `json:"tingkat"` // tinggi | sedang
}

type RingkasBerisiko struct {
	Total     int `json:"total"`
	Tinggi    int `json:"tinggi"`
	Sedang    int `json:"sedang"`
	DuaT      int `json:"dua_t"`
	Bgm       int `json:"bgm"`
	GiziBuruk int `json:"gizi_buruk"`
	Wasting   int `json:"wasting"`
	Stunting  int `json:"stunting"`
}

type DaftarBerisikoResp struct {
	Posyandu string          `json:"posyandu"`
	Ringkas  RingkasBerisiko `json:"ringkas"`
	Anak     []AnakBerisiko  `json:"anak"`
}

// nilaiRisiko: alasan dan skor risiko dari penimbangan terakhir.
func nilaiRisiko(t *TimbangRingkas) ([]string, int, bool) {
	alasan := []string{}
	skor := 0
	tinggi := false
	tambah := func(a string, s int, t bool) {
		alasan = append(alasan, a)
		skor += s
		if t {
			tinggi = true
		}
	}
	if t.DuaT {
		tambah("2T (tidak naik 2 bulan berturut-turut)", 8, true)
	} else if t.StatusTimbang == models.StatusTimbangTidakNaik {
		tambah("Tidak naik (T) bulan ini", 2, false)
	}
	if t.Bgm {
		tambah("BGM (di bawah garis merah)", 8, true)
	}
	for _, m := range t.Masalah {
		switch m {
		case "Gizi buruk":
			tambah("Gizi buruk", 10, true)
		case "Gizi kurang":
			tambah("Gizi kurang (wasting)", 5, false)
		case "Sangat pendek":
			tambah("Sangat pendek (stunting berat)", 6, true)
		case "Pendek":
			tambah("Pendek (stunting)", 4, false)
		case "BB sangat kurang":
			if !t.Bgm {
				tambah("BB sangat kurang", 6, true)
			}
		case "BB kurang":
			tambah("BB kurang", 2, false)
		case "Obesitas", "Gizi lebih":
			tambah(m, 3, false)
		}
	}
	return alasan, skor, tinggi
}

// Berisiko: balita aktif di posyandu [pos] dengan risiko gizi/pertumbuhan.
func (s *BalitaService) Berisiko(pos string) (*DaftarBerisikoResp, error) {
	daftar, err := s.Daftar(pos, "", false)
	if err != nil {
		return nil, err
	}
	out := &DaftarBerisikoResp{Posyandu: pos, Anak: []AnakBerisiko{}}
	r := &out.Ringkas
	for _, b := range daftar.Balita {
		if b.Terakhir == nil {
			continue
		}
		alasan, skor, tinggi := nilaiRisiko(b.Terakhir)
		if skor == 0 {
			continue
		}
		it := AnakBerisiko{BalitaItem: b, Alasan: alasan, Skor: skor, Tingkat: "sedang"}
		if tinggi {
			it.Tingkat = "tinggi"
			r.Tinggi++
		} else {
			r.Sedang++
		}
		r.Total++
		if b.Terakhir.DuaT {
			r.DuaT++
		}
		if b.Terakhir.Bgm {
			r.Bgm++
		}
		for _, m := range b.Terakhir.Masalah {
			switch m {
			case "Gizi buruk":
				r.GiziBuruk++
				r.Wasting++
			case "Gizi kurang":
				r.Wasting++
			case "Pendek", "Sangat pendek":
				r.Stunting++
			}
		}
		out.Anak = append(out.Anak, it)
	}
	sort.SliceStable(out.Anak, func(i, j int) bool {
		if out.Anak[i].Skor != out.Anak[j].Skor {
			return out.Anak[i].Skor > out.Anak[j].Skor
		}
		return out.Anak[i].Nama < out.Anak[j].Nama
	})
	return out, nil
}