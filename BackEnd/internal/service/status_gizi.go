package service

import (
	"errors"
	"fmt"
	"log"
	"math"
	"strings"
	"sync"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

const namaStandar = "WHO 2006/2007 (Permenkes 2/2020)"

var ErrStandarKosong = errors.New("tabel standar_antropometri masih kosong, jalankan: go run ./cmd/import-standar")

// StatusGiziService menghitung z-score dan kategori status gizi dengan metode LMS WHO.
type StatusGiziService struct {
	repo *repository.StatusGiziRepository

	mu    sync.RWMutex
	tabel map[string]models.StandarAntropometri
}

func NewStatusGiziService(r *repository.StatusGiziRepository) *StatusGiziService {
	return &StatusGiziService{repo: r}
}

// ---------------------------------------------------------------- tabel standar

func kunciStandar(indeks, jk string, acuan float64) string {
	return fmt.Sprintf("%s|%s|%.1f", indeks, jk, acuan)
}

// muat membaca tabel standar ke memori satu kali (sekitar 1.100 baris).
func (s *StatusGiziService) muat() error {
	s.mu.RLock()
	siap := len(s.tabel) > 0
	s.mu.RUnlock()
	if siap {
		return nil
	}
	list, err := s.repo.SemuaStandar()
	if err != nil {
		return err
	}
	if len(list) == 0 {
		return ErrStandarKosong
	}
	t := make(map[string]models.StandarAntropometri, len(list))
	for _, b := range list {
		t[kunciStandar(b.Indeks, b.JenisKelamin, b.Acuan)] = b
	}
	s.mu.Lock()
	s.tabel = t
	s.mu.Unlock()
	return nil
}

// MuatUlang dipanggil bila isi tabel standar diganti.
func (s *StatusGiziService) MuatUlang() error {
	s.mu.Lock()
	s.tabel = nil
	s.mu.Unlock()
	return s.muat()
}

func (s *StatusGiziService) cari(indeks, jk string, acuan float64) (models.StandarAntropometri, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	b, ok := s.tabel[kunciStandar(indeks, jk, acuan)]
	return b, ok
}

// ---------------------------------------------------------------- rumus WHO

// nilaiPadaZ: ukuran pada z tertentu menurut LMS.
func nilaiPadaZ(b models.StandarAntropometri, z float64) float64 {
	if b.L == 0 {
		return b.M * math.Exp(b.S*z)
	}
	return b.M * math.Pow(1+b.L*b.S*z, 1/b.L)
}

// zScore menghitung z dengan rumus LMS: Z = ((X/M)^L - 1) / (L*S).
// Untuk indeks berbasis berat dan lingkar lengan, WHO memakai penyesuaian di luar ±3 SD
// (jarak antar SD di ekor distribusi dianggap tetap).
func zScore(b models.StandarAntropometri, x float64, sesuaikan bool) float64 {
	var z float64
	if b.L == 0 {
		z = math.Log(x/b.M) / b.S
	} else {
		z = (math.Pow(x/b.M, b.L) - 1) / (b.L * b.S)
	}
	if !sesuaikan {
		return z
	}
	switch {
	case z > 3:
		sd3 := nilaiPadaZ(b, 3)
		sd23 := sd3 - nilaiPadaZ(b, 2)
		z = 3 + (x-sd3)/sd23
	case z < -3:
		sd3 := nilaiPadaZ(b, -3)
		sd23 := nilaiPadaZ(b, -2) - sd3
		z = -3 + (x-sd3)/sd23
	}
	return z
}

func bulat2(v float64) *float64 {
	r := math.Round(v*100) / 100
	return &r
}

// bulatSetengah: panjang/tinggi dibulatkan ke 0,5 cm terdekat untuk tabel BB/PB dan BB/TB.
func bulatSetengah(cm float64) float64 { return math.Round(cm*2) / 2 }

// usiaBulanPenuh: umur dalam bulan penuh pada tanggal pengukuran.
func usiaBulanPenuh(lahir, pada time.Time) int {
	b := (pada.Year()-lahir.Year())*12 + int(pada.Month()-lahir.Month())
	if pada.Day() < lahir.Day() {
		b--
	}
	if b < 0 {
		b = 0
	}
	return b
}

// ---------------------------------------------------------------- kategori (Permenkes 2/2020)

func lebihParah(a, b string) string {
	urut := map[string]int{"": 0, models.TingkatBaik: 1, models.TingkatWaspada: 2, models.TingkatRisiko: 3}
	if urut[b] > urut[a] {
		return b
	}
	return a
}

// KategoriBBU: berat badan menurut umur.
func KategoriBBU(z float64) (string, string) {
	switch {
	case z < -3:
		return "Berat badan sangat kurang", models.TingkatRisiko
	case z < -2:
		return "Berat badan kurang", models.TingkatWaspada
	case z <= 1:
		return "Berat badan normal", models.TingkatBaik
	default:
		return "Risiko berat badan lebih", models.TingkatWaspada
	}
}

// KategoriTBU: panjang/tinggi badan menurut umur (stunting).
func KategoriTBU(z float64) (string, string) {
	switch {
	case z < -3:
		return "Sangat pendek", models.TingkatRisiko
	case z < -2:
		return "Pendek", models.TingkatRisiko
	case z <= 3:
		return "Normal", models.TingkatBaik
	default:
		return "Tinggi", models.TingkatWaspada
	}
}

// KategoriBBTB: berat badan menurut panjang/tinggi badan, juga dipakai untuk IMT/U.
func KategoriBBTB(z float64) (string, string) {
	switch {
	case z < -3:
		return "Gizi buruk", models.TingkatRisiko
	case z < -2:
		return "Gizi kurang", models.TingkatWaspada
	case z <= 1:
		return "Gizi baik", models.TingkatBaik
	case z <= 2:
		return "Berisiko gizi lebih", models.TingkatWaspada
	case z <= 3:
		return "Gizi lebih", models.TingkatWaspada
	default:
		return "Obesitas", models.TingkatRisiko
	}
}

// KategoriLKU: lingkar kepala menurut umur (WHO).
func KategoriLKU(z float64) (string, string) {
	switch {
	case z < -2:
		return "Mikrosefali", models.TingkatRisiko
	case z > 2:
		return "Makrosefali", models.TingkatRisiko
	default:
		return "Normal", models.TingkatBaik
	}
}

// KategoriLILA: lingkar lengan atas menurut umur (WHO).
func KategoriLILA(z float64) (string, string) {
	switch {
	case z < -3:
		return "Sangat kurang", models.TingkatRisiko
	case z < -2:
		return "Kurang", models.TingkatWaspada
	default:
		return "Normal", models.TingkatBaik
	}
}

// ---------------------------------------------------------------- perhitungan

type hasilIndeks struct {
	z          *float64
	kategori   string
	tingkat    string
	tidakWajar bool
}

// hitungIndeks: nil bila baris standar tidak ada (di luar rentang).
// batasBawah/batasAtas: batas z tidak wajar menurut WHO (kemungkinan salah ukur/input).
func (s *StatusGiziService) hitungIndeks(indeks, jk string, acuan, x float64, sesuaikan bool,
	kat func(float64) (string, string), batasBawah, batasAtas float64) *hasilIndeks {
	b, ok := s.cari(indeks, jk, acuan)
	if !ok || x <= 0 {
		return nil
	}
	z := zScore(b, x, sesuaikan)
	k, t := kat(z)
	return &hasilIndeks{z: bulat2(z), kategori: k, tingkat: t, tidakWajar: z < batasBawah || z > batasAtas}
}

// Hitung menghasilkan status gizi satu pengukuran (belum disimpan).
func (s *StatusGiziService) Hitung(anak *models.Anak, u *models.Pengukuran) (*models.StatusGizi, error) {
	if anak == nil || u == nil {
		return nil, errors.New("data anak atau pengukuran kosong")
	}
	if err := s.muat(); err != nil {
		return nil, err
	}
	jk := strings.ToUpper(strings.TrimSpace(anak.JenisKelamin))
	if jk != "L" && jk != "P" {
		return nil, fmt.Errorf("jenis kelamin anak tidak valid: %q", anak.JenisKelamin)
	}
	tgl := u.TanggalUkur
	if tgl.IsZero() {
		tgl = time.Now()
	}
	usia := usiaBulanPenuh(anak.TanggalLahir, tgl)

	st := &models.StatusGizi{
		PengukuranID: u.ID,
		AnakID:       u.AnakID,
		TanggalUkur:  tgl,
		UsiaBulan:    int16(usia),
		JenisKelamin: jk,
		CaraUkur:     u.CaraUkur,
		Standar:      namaStandar,
		Tingkat:      models.TingkatBaik,
	}
	if st.AnakID == uuid.Nil {
		st.AnakID = anak.ID
	}
	if usia > 60 {
		st.Tingkat = ""
		st.Catatan = "Usia di atas 60 bulan, di luar rentang standar antropometri balita."
		return st, nil
	}

	// Koreksi cara ukur: < 24 bulan seharusnya berbaring, >= 24 bulan berdiri.
	tb := u.TbCm
	switch {
	case usia < 24 && u.CaraUkur == "berdiri":
		tb += 0.7
	case usia >= 24 && u.CaraUkur == "berbaring":
		tb -= 0.7
	}
	tb = math.Round(tb*10) / 10
	st.TbKoreksiCm = tb

	idxTB, idxBBTB, idxIMT := models.IndeksTBU, models.IndeksBBTB, models.IndeksIMTUTB
	if usia < 24 {
		idxTB, idxBBTB, idxIMT = models.IndeksPBU, models.IndeksBBPB, models.IndeksIMTUPB
	}
	st.IndeksTbu = idxTB
	st.IndeksBbtb = idxBBTB
	umur := float64(usia)

	var catatan []string
	pakai := func(h *hasilIndeks, z **float64, kat *string, nama string) {
		if h == nil {
			return
		}
		*z, *kat = h.z, h.kategori
		st.Tingkat = lebihParah(st.Tingkat, h.tingkat)
		if h.tidakWajar {
			st.PerluCekUlang = true
			catatan = append(catatan, nama+" di luar batas wajar, periksa ulang pengukuran")
		}
	}

	pakai(s.hitungIndeks(models.IndeksBBU, jk, umur, u.BbKg, true, KategoriBBU, -6, 5),
		&st.ZBbu, &st.KategoriBbu, "BB/U")
	pakai(s.hitungIndeks(idxTB, jk, umur, tb, false, KategoriTBU, -6, 6),
		&st.ZTbu, &st.KategoriTbu, "PB/U atau TB/U")

	hBBTB := s.hitungIndeks(idxBBTB, jk, bulatSetengah(tb), u.BbKg, true, KategoriBBTB, -5, 5)
	if hBBTB == nil {
		catatan = append(catatan, fmt.Sprintf("BB/PB atau BB/TB tidak dihitung: panjang/tinggi %.1f cm di luar tabel", tb))
	}
	pakai(hBBTB, &st.ZBbtb, &st.KategoriBbtb, "BB/PB atau BB/TB")

	if tb > 0 {
		imt := u.BbKg / math.Pow(tb/100, 2)
		st.Imt = bulat2(imt)
		pakai(s.hitungIndeks(idxIMT, jk, umur, imt, true, KategoriBBTB, -5, 5),
			&st.ZImtu, &st.KategoriImtu, "IMT/U")
	}
	if u.LingkarKepalaCm != nil {
		pakai(s.hitungIndeks(models.IndeksLKU, jk, umur, *u.LingkarKepalaCm, false, KategoriLKU, -5, 5),
			&st.ZLku, &st.KategoriLku, "LK/U")
	}
	if u.LilaCm != nil && usia >= 3 {
		pakai(s.hitungIndeks(models.IndeksLILAU, jk, umur, *u.LilaCm, true, KategoriLILA, -5, 5),
			&st.ZLila, &st.KategoriLila, "LiLA/U")
	}

	st.Stunting = st.ZTbu != nil && *st.ZTbu < -2
	st.Wasting = st.ZBbtb != nil && *st.ZBbtb < -2
	st.Underweight = st.ZBbu != nil && *st.ZBbu < -2
	st.Overweight = st.ZBbtb != nil && *st.ZBbtb > 2
	st.Catatan = strings.Join(catatan, "; ")
	return st, nil
}

// HitungDanSimpan dipanggil setiap kali kader menyimpan pengukuran.
func (s *StatusGiziService) HitungDanSimpan(anak *models.Anak, u *models.Pengukuran) (*models.StatusGizi, error) {
	st, err := s.Hitung(anak, u)
	if err != nil {
		return nil, err
	}
	if err := s.repo.Simpan(st); err != nil {
		return nil, err
	}
	if err := s.repo.GantiPeringatanOtomatis(u.ID, PeringatanDariStatus(st)); err != nil {
		log.Printf("status gizi: peringatan risiko pengukuran %s gagal disimpan: %v", u.ID, err)
	}
	return st, nil
}

func teksZ(nama string, z *float64, kategori string) string {
	return fmt.Sprintf("%s %s (z = %.2f)", nama, kategori, *z)
}

// PeringatanDariStatus: peringatan risiko otomatis untuk ditindaklanjuti bidan.
// Prioritas 1 = paling mendesak.
func PeringatanDariStatus(st *models.StatusGizi) []models.PeringatanRisiko {
	out := []models.PeringatanRisiko{}
	tambah := func(jenis, penyebab string, prioritas int16) {
		out = append(out, models.PeringatanRisiko{
			AnakID:           st.AnakID,
			PengukuranID:     st.PengukuranID,
			Jenis:            jenis,
			Penyebab:         penyebab,
			Prioritas:        prioritas,
			StatusPenanganan: "baru",
			DibuatOtomatis:   true,
			Version:          1,
		})
	}
	if st.Stunting {
		p := int16(2)
		if *st.ZTbu < -3 {
			p = 1
		}
		tambah("stunting", teksZ("PB/U atau TB/U", st.ZTbu, st.KategoriTbu), p)
	}
	if st.Wasting {
		p := int16(2)
		if *st.ZBbtb < -3 {
			p = 1
		}
		tambah("wasting", teksZ("BB/PB atau BB/TB", st.ZBbtb, st.KategoriBbtb), p)
	}
	if st.Underweight {
		p := int16(3)
		if *st.ZBbu < -3 {
			p = 2
		}
		tambah("underweight", teksZ("BB/U", st.ZBbu, st.KategoriBbu), p)
	}
	if st.Overweight {
		p := int16(3)
		if *st.ZBbtb > 3 {
			p = 2
		}
		tambah("overweight", teksZ("BB/PB atau BB/TB", st.ZBbtb, st.KategoriBbtb), p)
	}
	if st.ZLku != nil && (*st.ZLku < -2 || *st.ZLku > 2) {
		tambah("lingkar_kepala", teksZ("LK/U", st.ZLku, st.KategoriLku), 2)
	}
	return out
}

// UntukPengukuran: status gizi tersimpan (nil bila belum ada).
func (s *StatusGiziService) UntukPengukuran(pengukuranID uuid.UUID) (*models.StatusGizi, error) {
	st, err := s.repo.GetByPengukuran(pengukuranID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return st, nil
}

// PetaPengukuran: status gizi untuk beberapa pengukuran, dikunci dengan pengukuran_id.
func (s *StatusGiziService) PetaPengukuran(ids []uuid.UUID) (map[uuid.UUID]models.StatusGizi, error) {
	list, err := s.repo.ListByPengukuran(ids)
	if err != nil {
		return nil, err
	}
	out := make(map[uuid.UUID]models.StatusGizi, len(list))
	for _, x := range list {
		out[x.PengukuranID] = x
	}
	return out, nil
}

// HitungDataLama menghitung status gizi untuk pengukuran yang belum punya status.
// Aman dijalankan berulang kali (dipanggil saat server mulai).
func (s *StatusGiziService) HitungDataLama() {
	if err := s.muat(); err != nil {
		log.Printf("status gizi: %v", err)
		return
	}
	total := 0
	for {
		list, err := s.repo.PengukuranTanpaStatus(200)
		if err != nil {
			log.Printf("status gizi: gagal mengambil pengukuran lama: %v", err)
			return
		}
		if len(list) == 0 {
			break
		}
		ids := make([]uuid.UUID, 0, len(list))
		for _, u := range list {
			ids = append(ids, u.AnakID)
		}
		anakList, err := s.repo.AnakByIDs(ids)
		if err != nil {
			log.Printf("status gizi: gagal mengambil data anak: %v", err)
			return
		}
		peta := make(map[uuid.UUID]*models.Anak, len(anakList))
		for i := range anakList {
			peta[anakList[i].ID] = &anakList[i]
		}
		berhasil := 0
		for i := range list {
			u := &list[i]
			if _, err := s.HitungDanSimpan(peta[u.AnakID], u); err != nil {
				log.Printf("status gizi: pengukuran %s dilewati: %v", u.ID, err)
				continue
			}
			berhasil++
		}
		total += berhasil
		if berhasil == 0 {
			break // sisa data tidak dapat dihitung, hindari perulangan tanpa akhir
		}
	}
	if total > 0 {
		log.Printf("status gizi: %d pengukuran lama dihitung", total)
	}
}