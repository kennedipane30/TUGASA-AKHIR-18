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
