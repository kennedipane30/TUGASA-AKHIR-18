package service

import (
	"errors"
	"fmt"
	"log"
	"regexp"
	"sort"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ============================================================================
// MASTER IMUNISASI RUTIN (Program Imunisasi Kemenkes RI, Buku KIA)
//
//   < 24 jam  : Hepatitis B (HB0)
//   1 bulan   : BCG, Polio tetes 1
//   2 bulan   : DPT-HB-Hib 1, Polio tetes 2, PCV 1, Rotavirus 1
//   3 bulan   : DPT-HB-Hib 2, Polio tetes 3, PCV 2, Rotavirus 2
//   4 bulan   : DPT-HB-Hib 3, Polio tetes 4, Polio suntik (IPV) 1, Rotavirus 3
//   9 bulan   : Campak-Rubela (MR) 1, Polio suntik (IPV) 2
//   10 bulan  : Japanese Encephalitis (JE), khusus daerah endemis
//   12 bulan  : PCV 3
//   18 bulan  : DPT-HB-Hib 4 (lanjutan), Campak-Rubela (MR) 2 (lanjutan)
// ============================================================================

type masterDosis struct {
	dosis    int16
	kelompok string
	min      int16
	ideal    int16
	maks     *int16
	jarak    *int16
	ket      string
}

type masterVaksin struct {
	kode, nama, penyakit, cara, ket string
	urutan                          int16
	khususDaerah                    bool
	dosis                           []masterDosis
}

func i16(v int16) *int16 { return &v }

var masterImunisasi = []masterVaksin{
	{
		kode: "HB0", nama: "Hepatitis B (HB0)", urutan: 1,
		penyakit: "Hepatitis B", cara: "Suntik intramuskular (paha)",
		ket: "Diberikan sesegera mungkin setelah lahir, idealnya kurang dari 24 jam.",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 0, ideal: 0, maks: i16(0),
				ket: "Kurang dari 24 jam setelah lahir (paling lambat usia 7 hari)."},
		},
	},
	{
		kode: "BCG", nama: "BCG", urutan: 2,
		penyakit: "Tuberkulosis (TBC)", cara: "Suntik intrakutan (lengan kanan atas)",
		ket: "Optimal diberikan pada usia 1 bulan.",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 0, ideal: 1, maks: i16(11)},
		},
	},
	{
		kode: "OPV", nama: "Polio Tetes (OPV)", urutan: 3,
		penyakit: "Poliomielitis", cara: "Tetes mulut (2 tetes)",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 0, ideal: 1},
			{dosis: 2, kelompok: models.KelompokImunisasiDasar, min: 2, ideal: 2, jarak: i16(28)},
			{dosis: 3, kelompok: models.KelompokImunisasiDasar, min: 3, ideal: 3, jarak: i16(28)},
			{dosis: 4, kelompok: models.KelompokImunisasiDasar, min: 4, ideal: 4, jarak: i16(28)},
		},
	},
	{
		kode: "DPT-HB-HIB", nama: "DPT-HB-Hib (Pentavalen)", urutan: 4,
		penyakit: "Difteri, pertusis, tetanus, hepatitis B, pneumonia dan meningitis (Hib)",
		cara:     "Suntik intramuskular (paha)",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 2, ideal: 2},
			{dosis: 2, kelompok: models.KelompokImunisasiDasar, min: 3, ideal: 3, jarak: i16(28)},
			{dosis: 3, kelompok: models.KelompokImunisasiDasar, min: 4, ideal: 4, jarak: i16(28)},
			{dosis: 4, kelompok: models.KelompokImunisasiLanjutan, min: 18, ideal: 18, jarak: i16(28),
				ket: "Imunisasi lanjutan baduta."},
		},
	},
	{
		kode: "PCV", nama: "Pneumokokus Konjugasi (PCV)", urutan: 5,
		penyakit: "Pneumonia dan meningitis akibat pneumokokus", cara: "Suntik intramuskular (paha)",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 2, ideal: 2},
			{dosis: 2, kelompok: models.KelompokImunisasiDasar, min: 3, ideal: 3, jarak: i16(28)},
			{dosis: 3, kelompok: models.KelompokImunisasiLanjutan, min: 12, ideal: 12, jarak: i16(56)},
		},
	},
	{
		kode: "RV", nama: "Rotavirus (RV)", urutan: 6,
		penyakit: "Diare berat akibat rotavirus", cara: "Tetes mulut",
		ket: "Diberikan sesuai jadwal; tidak dikejar melewati batas usia pemberian.",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 2, ideal: 2},
			{dosis: 2, kelompok: models.KelompokImunisasiDasar, min: 3, ideal: 3, jarak: i16(28)},
			{dosis: 3, kelompok: models.KelompokImunisasiDasar, min: 4, ideal: 4, maks: i16(6), jarak: i16(28)},
		},
	},
	{
		kode: "IPV", nama: "Polio Suntik (IPV)", urutan: 7,
		penyakit: "Poliomielitis", cara: "Suntik intramuskular",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 4, ideal: 4},
			{dosis: 2, kelompok: models.KelompokImunisasiDasar, min: 9, ideal: 9, jarak: i16(28)},
		},
	},
	{
		kode: "MR", nama: "Campak-Rubela (MR)", urutan: 8,
		penyakit: "Campak dan rubela", cara: "Suntik subkutan (lengan kiri atas)",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 9, ideal: 9},
			{dosis: 2, kelompok: models.KelompokImunisasiLanjutan, min: 18, ideal: 18, jarak: i16(180),
				ket: "Imunisasi lanjutan baduta."},
		},
	},
	{
		kode: "JE", nama: "Japanese Encephalitis (JE)", urutan: 9, khususDaerah: true,
		penyakit: "Radang otak Japanese Encephalitis", cara: "Suntik subkutan",
		ket: "Hanya diberikan di daerah endemis JE.",
		dosis: []masterDosis{
			{dosis: 1, kelompok: models.KelompokImunisasiDasar, min: 10, ideal: 10},
		},
	},
}

// ============================================================================
// SERVICE
// ============================================================================

const (
	StatusVaksinSudah     = "sudah"          // sudah diberikan
	StatusVaksinBelum     = "belum_waktunya" // usia belum cukup
	StatusVaksinJatuhTemp = "jatuh_tempo"    // saatnya diberikan
	StatusVaksinTerlambat = "terlambat"      // lewat dari jadwal, masih bisa dikejar
	StatusVaksinTerlewat  = "terlewat"       // lewat batas usia, tidak diberikan lagi
	StatusVaksinMenunggu  = "menunggu"       // menunggu dosis sebelumnya

	vaksinTglLayout = "2006-01-02"
)

var ErrRiwayatVaksinTidakAda = errors.New("riwayat vaksin tidak ditemukan")

// batasHariHB0: HB0 hanya diberikan sampai usia 7 hari (di faskes, bukan di posyandu).
const batasHariHB0 = 7

type VaksinService struct {
	repo  *repository.VaksinRepository
	notif *NotifikasiService
}

func NewVaksinService(repo *repository.VaksinRepository) *VaksinService {
	return &VaksinService{repo: repo}
}

// SetNotifikasi: laporan reaksi imunisasi (KIPI) dari orang tua dikirim ke bidan.
func (s *VaksinService) SetNotifikasi(n *NotifikasiService) { s.notif = n }

// SiapkanMaster: isi/perbarui master jenis vaksin dan jadwal imunisasi (dipanggil saat server mulai).
func (s *VaksinService) SiapkanMaster() {
	kode := make([]string, 0, len(masterImunisasi))
	for _, mv := range masterImunisasi {
		kode = append(kode, strings.ToUpper(mv.kode))
		j := &models.JenisVaksin{
			Kode: mv.kode, Nama: mv.nama, Penyakit: mv.penyakit, CaraPemberian: mv.cara,
			Keterangan: mv.ket, JumlahDosis: int16(len(mv.dosis)), Urutan: mv.urutan,
			KhususDaerah: mv.khususDaerah, IsActive: true,
		}
		if err := s.repo.SimpanJenis(j); err != nil {
			log.Printf("vaksin: gagal menyimpan jenis %s: %v", mv.kode, err)
			continue
		}
		for _, d := range mv.dosis {
			jd := &models.JadwalImunisasi{
				JenisVaksinID: j.ID, DosisKe: d.dosis, Kelompok: d.kelompok,
				UsiaMinBulan: d.min, UsiaIdealBulan: d.ideal, UsiaMaksBulan: d.maks,
				JarakMinimalHari: d.jarak, Keterangan: d.ket,
			}
			if err := s.repo.SimpanJadwal(jd); err != nil {
				log.Printf("vaksin: gagal menyimpan jadwal %s dosis %d: %v", mv.kode, d.dosis, err)
			}
		}
		if err := s.repo.HapusJadwalLebih(j.ID, int16(len(mv.dosis))); err != nil {
			log.Printf("vaksin: jadwal lama %s tidak dapat dihapus: %v", mv.kode, err)
		}
	}
	if err := s.repo.NonaktifkanSelain(kode); err != nil {
		log.Printf("vaksin: gagal menonaktifkan jenis vaksin lama: %v", err)
	}
}

// ---------------------------------------------------------------- respons

type JenisVaksinResp struct {
	ID            uuid.UUID `json:"id"`
	Kode          string    `json:"kode"`
	Nama          string    `json:"nama"`
	Penyakit      string    `json:"penyakit"`
	CaraPemberian string    `json:"cara_pemberian"`
	KhususDaerah  bool      `json:"khusus_daerah"`
}

type JadwalMasterResp struct {
	ID               uuid.UUID       `json:"id"`
	JenisVaksin      JenisVaksinResp `json:"jenis_vaksin"`
	DosisKe          int16           `json:"dosis_ke"`
	JumlahDosis      int16           `json:"jumlah_dosis"`
	Kelompok         string          `json:"kelompok"`
	UsiaMinBulan     int16           `json:"usia_min_bulan"`
	UsiaIdealBulan   int16           `json:"usia_ideal_bulan"`
	UsiaMaksBulan    *int16          `json:"usia_maks_bulan"`
	JarakMinimalHari *int16          `json:"jarak_minimal_hari"`
	Keterangan       string          `json:"keterangan"`
	LabelUsia        string          `json:"label_usia"`
}

type JadwalAnakItem struct {
	JadwalMasterResp
	TanggalJadwal string             `json:"tanggal_jadwal"` // tanggal ideal menurut usia
	Status        string             `json:"status"`
	LabelStatus   string             `json:"label_status"`
	Opsional      bool               `json:"opsional"`
	Riwayat       *RiwayatVaksinResp `json:"riwayat"`

	// Jadwal posyandu tempat dosis ini akan diberikan.
	TanggalPosyandu string `json:"tanggal_posyandu"` // YYYY-MM-DD, kosong bila jadwal belum dibuat
	MenungguJadwal  bool   `json:"menunggu_jadwal"`  // jadwal posyandu belum dibuat sekretaris
	PerkiraanBulan  string `json:"perkiraan_bulan"`  // mis. "Desember 2026"
	LabelPosyandu   string `json:"label_posyandu"`   // teks siap tampil
	Susulan         bool   `json:"susulan"`          // seharusnya diberikan di posyandu sebelumnya
	KeFaskes        bool   `json:"ke_faskes"`        // harus diberikan di puskesmas/faskes
}

type RiwayatVaksinResp struct {
	ID               uuid.UUID       `json:"id"`
	JenisVaksin      JenisVaksinResp `json:"jenis_vaksin"`
	DosisKe          int16           `json:"dosis_ke"`
	TanggalPemberian string          `json:"tanggal_pemberian"`
	UsiaBulan        int             `json:"usia_bulan"`
	UsiaTeks         string          `json:"usia_teks"`
	Tempat           string          `json:"tempat"`
	KondisiAnak      string          `json:"kondisi_anak"`
	Catatan          string          `json:"catatan"`
	DiberikanOleh    uint            `json:"diberikan_oleh"`
	NamaPemberi      string          `json:"nama_pemberi"`
	DariPosyandu     bool            `json:"dari_posyandu"`

	Sumber             string `json:"sumber"`            // posyandu | luar | laporan_ortu
	StatusKonfirmasi   string `json:"status_konfirmasi"` // dikonfirmasi | menunggu
	NomorBatch         string `json:"nomor_batch"`
	PemberiLuar        string `json:"pemberi_luar"`
	FotoBukti          string `json:"foto_bukti"`
	ReaksiKipi         string `json:"reaksi_kipi"`
	KipiDilaporkanPada string `json:"kipi_dilaporkan_pada"`
	KipiTindakLanjut   string `json:"kipi_tindak_lanjut"`
}

type SuplemenResp struct {
	ID          uuid.UUID `json:"id"`
	Nama        string    `json:"nama"`
	Dosis       string    `json:"dosis"`
	Jumlah      int16     `json:"jumlah"`
	Satuan      string    `json:"satuan"`
	Keterangan  string    `json:"keterangan"`
	Tanggal     string    `json:"tanggal"`
	UsiaTeks    string    `json:"usia_teks"`
	Catatan     string    `json:"catatan"`
	NamaPemberi string    `json:"nama_pemberi"`
}

type RingkasanVaksin struct {
	TotalDosis      int  `json:"total_dosis"`
	Sudah           int  `json:"sudah"`
	JatuhTempo      int  `json:"jatuh_tempo"`
	Terlambat       int  `json:"terlambat"`
	Terlewat        int  `json:"terlewat"`
	Persen          int  `json:"persen"`
	DasarLengkap    bool `json:"dasar_lengkap"`
	LanjutanLengkap bool `json:"lanjutan_lengkap"`
}

type AnakVaksinInfo struct {
	ID                  uuid.UUID `json:"id"`
	Nama                string    `json:"nama"`
	JenisKelamin        string    `json:"jenis_kelamin"`
	TanggalLahir        string    `json:"tanggal_lahir"`
	UsiaBulan           int       `json:"usia_bulan"`
	UsiaTeks            string    `json:"usia_teks"`
	StatusRiwayatVaksin string    `json:"status_riwayat_vaksin"`
	MenungguKonfirmasi  int64     `json:"menunggu_konfirmasi"`
}

type KartuVaksinResp struct {
	Anak      AnakVaksinInfo      `json:"anak"`
	Ringkasan RingkasanVaksin     `json:"ringkasan"`
	Jadwal    []JadwalAnakItem    `json:"jadwal"`
	Riwayat   []RiwayatVaksinResp `json:"riwayat"`
	Suplemen  []SuplemenResp      `json:"suplemen"`
}

// ---------------------------------------------------------------- helper

// usiaTeks: "3 hari", "5 bln", "1 th 3 bln".
func tambahBulanUsia(t time.Time, n int) time.Time {
	total := int(t.Month()) - 1 + n
	y := t.Year() + total/12
	m := time.Month(total%12 + 1)
	akhir := time.Date(y, m+1, 0, 0, 0, 0, 0, time.UTC).Day()
	d := t.Day()
	if d > akhir {
		d = akhir
	}
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

// usiaTeks: usia detail, mis. "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan", "2 tahun".
func usiaTeks(lahir, pada time.Time) string {
	a := time.Date(lahir.Year(), lahir.Month(), lahir.Day(), 0, 0, 0, 0, time.UTC)
	z := time.Date(pada.Year(), pada.Month(), pada.Day(), 0, 0, 0, 0, time.UTC)
	if z.Before(a) {
		return "0 hari"
	}
	bulan := (z.Year()-a.Year())*12 + int(z.Month()) - int(a.Month())
	if tambahBulanUsia(a, bulan).After(z) {
		bulan--
	}
	hari := int(z.Sub(tambahBulanUsia(a, bulan)).Hours() / 24)
	tahun, sisa := bulan/12, bulan%12
	switch {
	case bulan == 0:
		return fmt.Sprintf("%d hari", hari)
	case tahun == 0 && hari == 0:
		return fmt.Sprintf("%d bulan", bulan)
	case tahun == 0:
		return fmt.Sprintf("%d bulan %d hari", bulan, hari)
	case sisa == 0:
		return fmt.Sprintf("%d tahun", tahun)
	default:
		return fmt.Sprintf("%d tahun %d bulan", tahun, sisa)
	}
}

func labelUsiaJadwal(d int16) string {
	switch {
	case d == 0:
		return "< 24 jam"
	case d < 12:
		return fmt.Sprintf("%d bulan", d)
	case d%12 == 0:
		return fmt.Sprintf("%d bulan (%d tahun)", d, d/12)
	default:
		return fmt.Sprintf("%d bulan", d)
	}
}

func tglSaja(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func jenisResp(j *models.JenisVaksin) JenisVaksinResp {
	if j == nil {
		return JenisVaksinResp{}
	}
	return JenisVaksinResp{
		ID: j.ID, Kode: j.Kode, Nama: j.Nama, Penyakit: j.Penyakit,
		CaraPemberian: j.CaraPemberian, KhususDaerah: j.KhususDaerah,
	}
}

func masterResp(j *models.JadwalImunisasi) JadwalMasterResp {
	r := JadwalMasterResp{
		ID: j.ID, DosisKe: j.DosisKe, Kelompok: j.Kelompok,
		UsiaMinBulan: j.UsiaMinBulan, UsiaIdealBulan: j.UsiaIdealBulan,
		UsiaMaksBulan: j.UsiaMaksBulan, JarakMinimalHari: j.JarakMinimalHari,
		Keterangan: j.Keterangan, LabelUsia: labelUsiaJadwal(j.UsiaIdealBulan),
	}
	if j.JenisVaksin != nil {
		r.JenisVaksin = jenisResp(j.JenisVaksin)
		r.JumlahDosis = j.JenisVaksin.JumlahDosis
	}
	return r
}

func riwayatResp(m *models.ImunisasiAnak, lahir time.Time) RiwayatVaksinResp {
	r := RiwayatVaksinResp{
		ID: m.ID, JenisVaksin: jenisResp(m.JenisVaksin), DosisKe: m.DosisKe,
		TanggalPemberian: m.TanggalPemberian.Format(vaksinTglLayout),
		UsiaBulan:        usiaBulan(lahir, m.TanggalPemberian),
		UsiaTeks:         usiaTeks(lahir, m.TanggalPemberian),
		Tempat:           m.Tempat, KondisiAnak: m.KondisiAnak, Catatan: m.Catatan,
		DiberikanOleh: m.DiberikanOleh, DariPosyandu: m.PendaftaranID != nil,
		Sumber: m.SumberEfektif(), StatusKonfirmasi: m.StatusKonfirmasi,
		NomorBatch: m.NomorBatch, PemberiLuar: m.PemberiLuar, FotoBukti: m.FotoBukti,
		ReaksiKipi: m.ReaksiKipi, KipiTindakLanjut: m.KipiTindakLanjut,
	}
	if r.StatusKonfirmasi == "" {
		r.StatusKonfirmasi = models.KonfirmasiImunisasiOK
	}
	if m.KipiDilaporkanPada != nil {
		r.KipiDilaporkanPada = m.KipiDilaporkanPada.Format(time.RFC3339)
	}
	if r.Tempat == "" && r.DariPosyandu {
		r.Tempat = "Posyandu"
	}
	// Pemberi: bidan untuk posyandu; petugas luar (bila diisi) untuk vaksin dari luar.
	switch {
	case r.Sumber == models.SumberImunisasiPosyandu && m.DiberikanOlehUser != nil:
		r.NamaPemberi = m.DiberikanOlehUser.Nama
	case r.Sumber != models.SumberImunisasiPosyandu:
		r.NamaPemberi = m.PemberiLuar
	}
	return r
}

func suplemenResp(m *models.SuplemenAnak, lahir time.Time) SuplemenResp {
	r := SuplemenResp{
		ID: m.ID, Nama: m.Jenis, Dosis: m.Dosis, Jumlah: m.Jumlah, Satuan: m.Satuan,
		Keterangan: m.KeteranganDosis, Tanggal: m.Tanggal.Format(vaksinTglLayout),
		UsiaTeks: usiaTeks(lahir, m.Tanggal), Catatan: m.Catatan,
	}
	if m.DiberikanOlehUser != nil {
		r.NamaPemberi = m.DiberikanOlehUser.Nama
	}
	return r
}

// KeteranganSuplemen: ringkasan dosis dan jumlah, mis. "200.000 IU · 1 kapsul".
func KeteranganSuplemen(dosis string, jumlah int16, satuan string) string {
	bagian := []string{}
	if d := strings.TrimSpace(dosis); d != "" {
		bagian = append(bagian, d)
	}
	if jumlah > 0 {
		bagian = append(bagian, strings.TrimSpace(fmt.Sprintf("%d %s", jumlah, strings.TrimSpace(satuan))))
	}
	return strings.Join(bagian, " · ")
}

type kunciDosis struct {
	jenis uuid.UUID
	dosis int16
}

// hitungJadwal: status setiap dosis untuk satu anak pada tanggal [hari].
func hitungJadwal(anak *models.Anak, master []models.JadwalImunisasi,
	riwayat []models.ImunisasiAnak, hari time.Time) ([]JadwalAnakItem, RingkasanVaksin) {

	lahir := tglSaja(anak.TanggalLahir)
	hari = tglSaja(hari)
	usia := usiaBulan(lahir, hari)

	diberi := map[kunciDosis]*models.ImunisasiAnak{}
	for i := range riwayat {
		r := &riwayat[i]
		diberi[kunciDosis{r.JenisVaksinID, r.DosisKe}] = r
	}

	items := make([]JadwalAnakItem, 0, len(master))
	var rk RingkasanVaksin
	dasarLengkap, lanjutanLengkap := true, true

	for i := range master {
		j := &master[i]
		it := JadwalAnakItem{JadwalMasterResp: masterResp(j)}
		it.Opsional = j.JenisVaksin != nil && j.JenisVaksin.KhususDaerah

		jadwal := lahir.AddDate(0, int(j.UsiaIdealBulan), 0)
		mulai := lahir.AddDate(0, int(j.UsiaMinBulan), 0)

		var prev *models.ImunisasiAnak
		adaPrev := true
		if j.DosisKe > 1 {
			prev = diberi[kunciDosis{j.JenisVaksinID, j.DosisKe - 1}]
			adaPrev = prev != nil
			if prev != nil && j.JarakMinimalHari != nil {
				boleh := tglSaja(prev.TanggalPemberian).AddDate(0, 0, int(*j.JarakMinimalHari))
				if boleh.After(mulai) {
					mulai = boleh
				}
				if boleh.After(jadwal) {
					jadwal = boleh
				}
			}
		}
		it.TanggalJadwal = jadwal.Format(vaksinTglLayout)

		hb0 := j.JenisVaksin != nil && strings.EqualFold(j.JenisVaksin.Kode, kodeHB0)
		if r, ok := diberi[kunciDosis{j.JenisVaksinID, j.DosisKe}]; ok {
			rr := riwayatResp(r, lahir)
			it.Riwayat = &rr
			it.Status = StatusVaksinSudah
			it.LabelStatus = "Sudah diberikan"
			if r.StatusKonfirmasi == models.KonfirmasiImunisasiMenunggu {
				it.LabelStatus = "Dilaporkan orang tua, menunggu konfirmasi bidan"
			}
		} else if hb0 {
			// HB0: diberikan di faskes paling lambat usia 7 hari, tidak dikejar setelahnya.
			if hari.After(lahir.AddDate(0, 0, batasHariHB0)) {
				it.Status = StatusVaksinTerlewat
				it.LabelStatus = "Lewat usia 7 hari, perlindungan Hepatitis B didapat dari DPT-HB-Hib"
			} else {
				it.Status = StatusVaksinJatuhTemp
				it.LabelStatus = "Diberikan di faskes, paling lambat usia 7 hari"
				it.KeFaskes = true
			}
		} else {
			switch {
			case j.UsiaMaksBulan != nil && usia > int(*j.UsiaMaksBulan):
				it.Status, it.LabelStatus = StatusVaksinTerlewat, "Lewat batas usia"
			case hari.Before(mulai):
				it.Status, it.LabelStatus = StatusVaksinBelum, "Belum waktunya"
			case !adaPrev:
				it.Status = StatusVaksinMenunggu
				it.LabelStatus = fmt.Sprintf("Menunggu dosis ke-%d", j.DosisKe-1)
			case !hari.After(jadwal.AddDate(0, 1, 0)):
				it.Status, it.LabelStatus = StatusVaksinJatuhTemp, "Saatnya diberikan"
			default:
				it.Status = StatusVaksinTerlambat
				it.Susulan = true
				it.LabelStatus = "Susulan, seharusnya " + notifTglIndo(jadwal)
			}
		}

		if !it.Opsional {
			rk.TotalDosis++
			switch it.Status {
			case StatusVaksinSudah:
				rk.Sudah++
			case StatusVaksinJatuhTemp:
				rk.JatuhTempo++
			case StatusVaksinTerlambat:
				rk.Terlambat++
			case StatusVaksinTerlewat:
				rk.Terlewat++
			}
			if it.Status != StatusVaksinSudah {
				if j.Kelompok == models.KelompokImunisasiLanjutan {
					lanjutanLengkap = false
				} else {
					dasarLengkap = false
				}
			}
		}
		items = append(items, it)
	}
	if rk.TotalDosis > 0 {
		rk.Persen = rk.Sudah * 100 / rk.TotalDosis
	}
	rk.DasarLengkap = dasarLengkap
	rk.LanjutanLengkap = lanjutanLengkap
	return items, rk
}

// ---------------------------------------------------------------- akses

// CekAkses: staf (bidan, kader, sekretaris) hanya posyandu sendiri; orang tua hanya anaknya.
func (s *VaksinService) CekAkses(anakID uuid.UUID, uid uint, role, pos string) (*models.Anak, error) {
	a, err := s.repo.GetAnak(anakID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAnakTidakAda
	}
	if err != nil {
		return nil, err
	}
	switch role {
	case "bidan", "kader", "sekretaris":
		p, err := s.repo.PosyanduAnak(a.ID)
		if err != nil {
			return nil, err
		}
		if pos == "" || p != pos {
			return nil, terlarang("anak bukan bagian dari posyandu Anda")
		}
		return a, nil
	case "orang_tua":
		kid, err := s.repo.KeluargaIDByUser(uid)
		if err != nil || kid != a.KeluargaID {
			return nil, terlarang("anak bukan bagian dari keluarga Anda")
		}
		return a, nil
	}
	return nil, terlarang("akses ditolak")
}

// ---------------------------------------------------------------- master

func (s *VaksinService) ListJenis() ([]JenisVaksinResp, error) {
	list, err := s.repo.ListJenisAktif()
	if err != nil {
		return nil, err
	}
	out := make([]JenisVaksinResp, 0, len(list))
	for i := range list {
		out = append(out, jenisResp(&list[i]))
	}
	return out, nil
}

func (s *VaksinService) ListJadwalMaster() ([]JadwalMasterResp, error) {
	list, err := s.repo.ListJadwalMaster()
	if err != nil {
		return nil, err
	}
	out := make([]JadwalMasterResp, 0, len(list))
	for i := range list {
		out = append(out, masterResp(&list[i]))
	}
	return out, nil
}

// ---------------------------------------------------------------- kartu vaksin anak

// KartuAnak: jadwal (dengan status), riwayat vaksin, dan riwayat suplemen satu anak.
func (s *VaksinService) KartuAnak(anakID uuid.UUID, uid uint, role, pos string) (*KartuVaksinResp, error) {
	anak, err := s.CekAkses(anakID, uid, role, pos)
	if err != nil {
		return nil, err
	}
	master, err := s.repo.ListJadwalMaster()
	if err != nil {
		return nil, err
	}
	riwayat, err := s.repo.ListRiwayatAnak(anak.ID)
	if err != nil {
		return nil, err
	}
	sup, err := s.repo.ListSuplemenAnak(anak.ID)
	if err != nil {
		return nil, err
	}

	hari := hariIni()
	lahir := tglSaja(anak.TanggalLahir)
	jadwal, rk := hitungJadwal(anak, master, riwayat, hari)
	s.aturJadwalPosyandu(anak, master, jadwal, hari)

	status := anak.StatusRiwayatVaksin
	if status == "" {
		status = models.RiwayatVaksinBelumDitanya
	}
	out := &KartuVaksinResp{
		Anak: AnakVaksinInfo{
			ID: anak.ID, Nama: anak.Nama, JenisKelamin: anak.JenisKelamin,
			TanggalLahir: lahir.Format(vaksinTglLayout),
			UsiaBulan:    usiaBulan(lahir, hari), UsiaTeks: usiaTeks(lahir, hari),
			StatusRiwayatVaksin: status,
			MenungguKonfirmasi:  s.repo.JumlahMenungguKonfirmasi(anak.ID),
		},
		Ringkasan: rk,
		Jadwal:    jadwal,
		Riwayat:   make([]RiwayatVaksinResp, 0, len(riwayat)),
		Suplemen:  make([]SuplemenResp, 0, len(sup)),
	}
	for i := len(riwayat) - 1; i >= 0; i-- { // terbaru di atas
		out.Riwayat = append(out.Riwayat, riwayatResp(&riwayat[i], lahir))
	}
	for i := range sup {
		out.Suplemen = append(out.Suplemen, suplemenResp(&sup[i], lahir))
	}
	return out, nil
}

// ---------------------------------------------------------------- jadwal posyandu per dosis

// aturJadwalPosyandu: setiap dosis yang belum diberikan dipasangkan ke jadwal posyandu
// pertama yang tanggalnya sudah memenuhi usia ideal, usia minimal, dan jarak minimal
// dari dosis sebelumnya. Bila jadwal belum dibuat, ditampilkan perkiraan bulannya.
func (s *VaksinService) aturJadwalPosyandu(anak *models.Anak, master []models.JadwalImunisasi,
	items []JadwalAnakItem, hari time.Time) {
	hari = tglSaja(hari)
	lahir := tglSaja(anak.TanggalLahir)

	var jadwal []time.Time
	if pos, err := s.repo.PosyanduAnak(anak.ID); err == nil && pos != "" {
		if list, err := s.repo.JadwalMendatang(pos, hari); err == nil {
			for _, j := range list {
				jadwal = append(jadwal, tglSaja(j.Tanggal))
			}
		}
	}

	rencana := map[kunciDosis]time.Time{}
	for i := range items {
		if i >= len(master) {
			break
		}
		it := &items[i]
		j := &master[i]
		k := kunciDosis{j.JenisVaksinID, j.DosisKe}

		if it.Status == StatusVaksinSudah {
			if it.Riwayat != nil {
				if t, err := time.Parse(vaksinTglLayout, it.Riwayat.TanggalPemberian); err == nil {
					rencana[k] = t
				}
			}
			continue
		}
		if it.Opsional || it.Status == StatusVaksinTerlewat || it.KeFaskes {
			continue
		}

		awal, err := time.Parse(vaksinTglLayout, it.TanggalJadwal)
		if err != nil {
			continue
		}
		if mulai := lahir.AddDate(0, int(j.UsiaMinBulan), 0); mulai.After(awal) {
			awal = mulai
		}
		if j.DosisKe > 1 {
			prev, ok := rencana[kunciDosis{j.JenisVaksinID, j.DosisKe - 1}]
			if !ok {
				continue
			}
			jarak := 28
			if j.JarakMinimalHari != nil {
				jarak = int(*j.JarakMinimalHari)
			}
			if boleh := prev.AddDate(0, 0, jarak); boleh.After(awal) {
				awal = boleh
			}
		}
		if awal.Before(hari) {
			awal = hari
		}

		var batas time.Time // hari pertama melewati batas usia
		if j.UsiaMaksBulan != nil {
			batas = lahir.AddDate(0, int(*j.UsiaMaksBulan)+1, 0)
		}

		var pilih *time.Time
		for x := range jadwal {
			if !jadwal[x].Before(awal) {
				t := jadwal[x]
				pilih = &t
				break
			}
		}

		switch {
		case pilih != nil && (batas.IsZero() || pilih.Before(batas)):
			it.TanggalPosyandu = pilih.Format(vaksinTglLayout)
			if pilih.Equal(hari) {
				it.LabelPosyandu = "Diberikan di posyandu hari ini"
			} else {
				it.LabelPosyandu = "Diberikan di posyandu " + notifTglIndo(*pilih)
			}
			rencana[k] = *pilih
		case !batas.IsZero() && !awal.Before(batas):
			it.KeFaskes = true
			it.LabelPosyandu = "Batas usia habis, konsultasikan ke puskesmas"
		case !batas.IsZero() && (pilih == nil || !pilih.Before(batas)) && batas.Sub(hari) <= 31*24*time.Hour:
			it.KeFaskes = true
			it.LabelPosyandu = "Berikan di puskesmas sebelum " + notifTglIndo(batas.AddDate(0, 0, -1)) +
				" (batas usia)"
			rencana[k] = awal
		default:
			it.MenungguJadwal = true
			it.PerkiraanBulan = fmt.Sprintf("%s %d", notifNamaBulan[awal.Month()-1], awal.Year())
			it.LabelPosyandu = "Menunggu jadwal posyandu (sekitar " + it.PerkiraanBulan + ")"
			rencana[k] = awal
		}
	}
}

// ---------------------------------------------------------------- validasi pemberian

type ItemVaksin struct {
	JenisVaksinID uuid.UUID
	DosisKe       int16
}

// itemRiwayat: satu dosis beserta tanggal pemberiannya (untuk validasi berurutan).
type itemRiwayat struct {
	JenisVaksinID uuid.UUID
	DosisKe       int16
	Tanggal       time.Time
}

// ValidasiPemberian: cek setiap vaksin yang akan dicatat untuk anak pada [tanggal].
// kecualiPendaftaran: riwayat dari sesi ini diabaikan (karena akan diganti).
func (s *VaksinService) ValidasiPemberian(anak *models.Anak, tanggal time.Time,
	items []ItemVaksin, kecualiPendaftaran *uuid.UUID) error {
	list := make([]itemRiwayat, 0, len(items))
	for _, it := range items {
		list = append(list, itemRiwayat{JenisVaksinID: it.JenisVaksinID, DosisKe: it.DosisKe, Tanggal: tanggal})
	}
	return validasiRiwayat(s.repo, anak, list, kecualiPendaftaran, nil)
}

// validasiRiwayat: aturan pencatatan imunisasi (dipakai untuk posyandu, vaksin dari luar,
// laporan orang tua, dan koreksi tanggal saat konfirmasi):
//   - dosis ada dalam jadwal imunisasi dan belum pernah tercatat,
//   - tanggal tidak sebelum lahir dan tidak di masa depan,
//   - usia anak memenuhi usia minimal dan maksimal,
//   - dosis sebelumnya sudah tercatat dan jarak minimal terpenuhi,
//   - tidak bertentangan dengan dosis berikutnya yang sudah tercatat.
func validasiRiwayat(repo *repository.VaksinRepository, anak *models.Anak, items []itemRiwayat,
	kecualiPendaftaran, kecualiRiwayat *uuid.UUID) error {
	if len(items) == 0 {
		return nil
	}
	master, err := repo.ListJadwalMaster()
	if err != nil {
		return err
	}
	petaMaster := map[kunciDosis]*models.JadwalImunisasi{}
	for i := range master {
		petaMaster[kunciDosis{master[i].JenisVaksinID, master[i].DosisKe}] = &master[i]
	}
	riwayat, err := repo.ListRiwayatAnak(anak.ID)
	if err != nil {
		return err
	}
	diberi := map[kunciDosis]time.Time{}
	for i := range riwayat {
		r := &riwayat[i]
		if kecualiPendaftaran != nil && r.PendaftaranID != nil && *r.PendaftaranID == *kecualiPendaftaran {
			continue
		}
		if kecualiRiwayat != nil && r.ID == *kecualiRiwayat {
			continue
		}
		diberi[kunciDosis{r.JenisVaksinID, r.DosisKe}] = tglSaja(r.TanggalPemberian)
	}

	urut := append([]itemRiwayat(nil), items...)
	sort.SliceStable(urut, func(a, b int) bool {
		if urut[a].JenisVaksinID != urut[b].JenisVaksinID {
			return urut[a].JenisVaksinID.String() < urut[b].JenisVaksinID.String()
		}
		return urut[a].DosisKe < urut[b].DosisKe
	})

	lahir := tglSaja(anak.TanggalLahir)
	hari := hariIni()
	dipilih := map[kunciDosis]bool{}
	for _, it := range urut {
		k := kunciDosis{it.JenisVaksinID, it.DosisKe}
		j, ok := petaMaster[k]
		if !ok {
			return validasi("vaksin dosis ke-%d tidak ada dalam jadwal imunisasi", it.DosisKe)
		}
		nama := j.JenisVaksin.Nama
		tanggal := tglSaja(it.Tanggal)
		if dipilih[k] {
			return validasi("%s dosis ke-%d dipilih lebih dari sekali", nama, it.DosisKe)
		}
		dipilih[k] = true
		if _, sudah := diberi[k]; sudah {
			return konflik("%s dosis ke-%d sudah tercatat untuk anak ini, tidak boleh diberikan dua kali", nama, it.DosisKe)
		}
		if tanggal.Before(lahir) {
			return validasi("tanggal %s dosis ke-%d tidak boleh sebelum tanggal lahir anak", nama, it.DosisKe)
		}
		if tanggal.After(hari) {
			return validasi("tanggal %s dosis ke-%d tidak boleh di masa depan", nama, it.DosisKe)
		}
		usia := usiaBulan(lahir, tanggal)
		if usia < int(j.UsiaMinBulan) {
			return validasi("%s dosis ke-%d baru boleh diberikan mulai usia %d bulan (usia anak saat itu %s)",
				nama, it.DosisKe, j.UsiaMinBulan, usiaTeks(lahir, tanggal))
		}
		if j.UsiaMaksBulan != nil && usia > int(*j.UsiaMaksBulan) {
			return validasi("%s dosis ke-%d hanya diberikan sampai usia %d bulan (usia anak saat itu %s)",
				nama, it.DosisKe, *j.UsiaMaksBulan, usiaTeks(lahir, tanggal))
		}
		if it.DosisKe > 1 {
			prev, ada := diberi[kunciDosis{it.JenisVaksinID, it.DosisKe - 1}]
			if !ada {
				return validasi("%s dosis ke-%d belum tercatat, catat dosis tersebut lebih dulu", nama, it.DosisKe-1)
			}
			if j.JarakMinimalHari != nil {
				boleh := prev.AddDate(0, 0, int(*j.JarakMinimalHari))
				if tanggal.Before(boleh) {
					return validasi("%s dosis ke-%d minimal %d hari setelah dosis sebelumnya (paling cepat %s)",
						nama, it.DosisKe, *j.JarakMinimalHari, notifTglIndo(boleh))
				}
			}
		}
		if berikut, ada := diberi[kunciDosis{it.JenisVaksinID, it.DosisKe + 1}]; ada {
			jarak := 0
			if jb := petaMaster[kunciDosis{it.JenisVaksinID, it.DosisKe + 1}]; jb != nil && jb.JarakMinimalHari != nil {
				jarak = int(*jb.JarakMinimalHari)
			}
			if berikut.Before(tanggal.AddDate(0, 0, jarak)) {
				return validasi("tanggal %s dosis ke-%d tidak sesuai dengan dosis ke-%d yang sudah tercatat (%s)",
					nama, it.DosisKe, it.DosisKe+1, notifTglIndo(berikut))
			}
		}
		diberi[k] = tanggal
	}
	return nil
}

// ---------------------------------------------------------------- vaksin dari luar (bidan)

type CatatRiwayatInput struct {
	AnakID           uuid.UUID `json:"anak_id" binding:"required"`
	JenisVaksinID    uuid.UUID `json:"jenis_vaksin_id" binding:"required"`
	DosisKe          int16     `json:"dosis_ke" binding:"required"`
	TanggalPemberian string    `json:"tanggal_pemberian" binding:"required"`
	Tempat           string    `json:"tempat"`
	NomorBatch       string    `json:"nomor_batch"`
	PemberiLuar      string    `json:"pemberi_luar"`
	FotoBukti        string    `json:"foto_bukti"`
	KondisiAnak      string    `json:"kondisi_anak"`
	Catatan          string    `json:"catatan"`
}

func batasTeks(s string, maks int, nama string) (string, error) {
	s = strings.TrimSpace(s)
	if len([]rune(s)) > maks {
		return "", validasi("%s maksimal %d karakter", nama, maks)
	}
	return s, nil
}

// CatatRiwayat: bidan mencatat vaksin yang diberikan di luar posyandu
// (berdasarkan keterangan orang tua saat konsultasi). Langsung dikonfirmasi.
func (s *VaksinService) CatatRiwayat(bidanID uint, pos string, in CatatRiwayatInput) (*RiwayatVaksinResp, error) {
	anak, err := s.CekAkses(in.AnakID, bidanID, "bidan", pos)
	if err != nil {
		return nil, err
	}
	if anak.Status != "aktif" {
		return nil, konflik("anak sudah diarsipkan")
	}
	tgl, err := time.Parse(vaksinTglLayout, strings.TrimSpace(in.TanggalPemberian))
	if err != nil {
		return nil, validasi("tanggal pemberian harus berformat YYYY-MM-DD")
	}
	tempat, err := batasTeks(in.Tempat, 100, "tempat")
	if err != nil {
		return nil, err
	}
	if tempat == "" {
		return nil, validasi("tempat pemberian vaksin wajib diisi (mis. RSUD Porsea, Puskesmas Balige)")
	}
	batch, err := batasTeks(in.NomorBatch, 50, "nomor batch")
	if err != nil {
		return nil, err
	}
	pemberi, err := batasTeks(in.PemberiLuar, 100, "nama petugas")
	if err != nil {
		return nil, err
	}
	foto, err := cekNamaBukti(in.FotoBukti)
	if err != nil {
		return nil, err
	}
	item := []itemRiwayat{{JenisVaksinID: in.JenisVaksinID, DosisKe: in.DosisKe, Tanggal: tgl}}
	if err := validasiRiwayat(s.repo, anak, item, nil, nil); err != nil {
		return nil, err
	}
	now := time.Now()
	oleh := bidanID
	m := &models.ImunisasiAnak{
		AnakID: anak.ID, JenisVaksinID: in.JenisVaksinID, DosisKe: in.DosisKe,
		TanggalPemberian: tglSaja(tgl), Tempat: tempat,
		Sumber: models.SumberImunisasiLuar, StatusKonfirmasi: models.KonfirmasiImunisasiOK,
		NomorBatch: batch, PemberiLuar: pemberi, FotoBukti: foto,
		KondisiAnak: strings.TrimSpace(in.KondisiAnak), Catatan: strings.TrimSpace(in.Catatan),
		DiberikanOleh: bidanID, DikonfirmasiOleh: &oleh, DikonfirmasiPada: &now, Version: 1,
	}
	if err := s.repo.CreateRiwayat(m); err != nil {
		return nil, err
	}
	full, err := s.repo.GetRiwayat(m.ID)
	if err != nil {
		return nil, err
	}
	r := riwayatResp(full, anak.TanggalLahir)
	return &r, nil
}

// HapusRiwayat: koreksi / batalkan catatan vaksin dari luar atau laporan orang tua.
// Vaksin dari sesi posyandu diubah lewat catatan bidan pada sesi tersebut.
func (s *VaksinService) HapusRiwayat(bidanID uint, pos string, id uuid.UUID) error {
	m, err := s.repo.GetRiwayat(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrRiwayatVaksinTidakAda
	}
	if err != nil {
		return err
	}
	if _, err := s.CekAkses(m.AnakID, bidanID, "bidan", pos); err != nil {
		return err
	}
	if m.PendaftaranID != nil {
		return konflik("vaksin ini dicatat pada sesi posyandu, ubah melalui catatan bidan pada sesi tersebut")
	}
	if s.repo.RiwayatAda(m.AnakID, m.JenisVaksinID, m.DosisKe+1, nil) {
		return konflik("dosis berikutnya sudah tercatat, hapus dosis berikutnya terlebih dahulu")
	}
	return s.repo.DeleteRiwayat(id)
}

// ---------------------------------------------------------------- riwayat awal (orang tua)

type RiwayatAwalItem struct {
	JenisVaksinID    uuid.UUID `json:"jenis_vaksin_id" binding:"required"`
	DosisKe          int16     `json:"dosis_ke" binding:"required"`
	TanggalPemberian string    `json:"tanggal_pemberian" binding:"required"`
	Tempat           string    `json:"tempat"`
	FotoBukti        string    `json:"foto_bukti"`
}

type RiwayatAwalInput struct {
	Status string            `json:"status" binding:"required"` // sudah | belum_pernah | lupa
	Items  []RiwayatAwalItem `json:"items"`
}

// LaporRiwayatAwal: orang tua mengisi vaksin yang sudah diterima anak sebelum ke posyandu.
// Dosis yang dilaporkan langsung terkunci (tidak bisa diberikan lagi) dan menunggu konfirmasi bidan.
func (s *VaksinService) LaporRiwayatAwal(uid uint, anakID uuid.UUID, in RiwayatAwalInput) (*KartuVaksinResp, error) {
	anak, err := s.CekAkses(anakID, uid, "orang_tua", "")
	if err != nil {
		return nil, err
	}
	if anak.StatusRiwayatVaksin == models.RiwayatVaksinDikonfirmasi {
		return nil, konflik("riwayat vaksin sudah dikonfirmasi bidan; sampaikan perubahan kepada bidan saat posyandu")
	}

	status := ""
	switch strings.TrimSpace(in.Status) {
	case "belum_pernah":
		status = models.RiwayatVaksinBelumPernah
	case "lupa":
		status = models.RiwayatVaksinPerluDitanyakan
	case "sudah":
		status = models.RiwayatVaksinDilaporkan
		if len(in.Items) == 0 {
			return nil, validasi("pilih minimal satu vaksin yang sudah diterima anak")
		}
	default:
		return nil, validasi("status riwayat vaksin harus sudah, belum_pernah, atau lupa")
	}

	err = s.repo.Tx(func(r *repository.VaksinRepository) error {
		if err := r.HapusLaporanOrangTua(anak.ID); err != nil {
			return err
		}
		if status == models.RiwayatVaksinDilaporkan {
			items := make([]itemRiwayat, 0, len(in.Items))
			baru := make([]models.ImunisasiAnak, 0, len(in.Items))
			for _, x := range in.Items {
				tgl, err := time.Parse(vaksinTglLayout, strings.TrimSpace(x.TanggalPemberian))
				if err != nil {
					return validasi("tanggal pemberian harus berformat YYYY-MM-DD")
				}
				tempat, err := batasTeks(x.Tempat, 100, "tempat")
				if err != nil {
					return err
				}
				if tempat == "" {
					return validasi("tempat pemberian setiap vaksin wajib diisi (mis. RSUD Porsea)")
				}
				foto, err := cekNamaBukti(x.FotoBukti)
				if err != nil {
					return err
				}
				items = append(items, itemRiwayat{JenisVaksinID: x.JenisVaksinID, DosisKe: x.DosisKe, Tanggal: tgl})
				baru = append(baru, models.ImunisasiAnak{
					AnakID: anak.ID, JenisVaksinID: x.JenisVaksinID, DosisKe: x.DosisKe,
					TanggalPemberian: tglSaja(tgl), Tempat: tempat, FotoBukti: foto,
					Sumber: models.SumberImunisasiOrangTua, StatusKonfirmasi: models.KonfirmasiImunisasiMenunggu,
					DiberikanOleh: uid, Version: 1,
				})
			}
			if err := validasiRiwayat(r, anak, items, nil, nil); err != nil {
				return err
			}
			for i := range baru {
				if err := r.CreateRiwayat(&baru[i]); err != nil {
					return err
				}
			}
		}
		return r.SimpanStatusRiwayat(anak.ID, status, nil, nil)
	})
	if err != nil {
		return nil, err
	}
	return s.KartuAnak(anak.ID, uid, "orang_tua", "")
}

// ---------------------------------------------------------------- konfirmasi riwayat (bidan)

type KonfirmasiRiwayatInput struct {
	TanggalPemberian string `json:"tanggal_pemberian"` // kosong = tidak diubah
	Tempat           string `json:"tempat"`
	NomorBatch       string `json:"nomor_batch"`
	PemberiLuar      string `json:"pemberi_luar"`
}

// KonfirmasiRiwayat: bidan membenarkan (dan bila perlu memperbaiki) laporan vaksin orang tua.
func (s *VaksinService) KonfirmasiRiwayat(bidanID uint, pos string, id uuid.UUID, in KonfirmasiRiwayatInput) (*RiwayatVaksinResp, error) {
	m, err := s.repo.GetRiwayat(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrRiwayatVaksinTidakAda
	}
	if err != nil {
		return nil, err
	}
	anak, err := s.CekAkses(m.AnakID, bidanID, "bidan", pos)
	if err != nil {
		return nil, err
	}
	if m.PendaftaranID != nil {
		return nil, konflik("vaksin dari sesi posyandu tidak perlu dikonfirmasi")
	}
	if t := strings.TrimSpace(in.TanggalPemberian); t != "" {
		tgl, err := time.Parse(vaksinTglLayout, t)
		if err != nil {
			return nil, validasi("tanggal pemberian harus berformat YYYY-MM-DD")
		}
		item := []itemRiwayat{{JenisVaksinID: m.JenisVaksinID, DosisKe: m.DosisKe, Tanggal: tgl}}
		if err := validasiRiwayat(s.repo, anak, item, nil, &m.ID); err != nil {
			return nil, err
		}
		m.TanggalPemberian = tglSaja(tgl)
	}
	if t, err := batasTeks(in.Tempat, 100, "tempat"); err != nil {
		return nil, err
	} else if t != "" {
		m.Tempat = t
	}
	if t, err := batasTeks(in.NomorBatch, 50, "nomor batch"); err != nil {
		return nil, err
	} else if t != "" {
		m.NomorBatch = t
	}
	if t, err := batasTeks(in.PemberiLuar, 100, "nama petugas"); err != nil {
		return nil, err
	} else if t != "" {
		m.PemberiLuar = t
	}
	now := time.Now()
	oleh := bidanID
	m.StatusKonfirmasi = models.KonfirmasiImunisasiOK
	m.DikonfirmasiOleh = &oleh
	m.DikonfirmasiPada = &now
	m.Version++
	if err := s.repo.SaveRiwayat(m); err != nil {
		return nil, err
	}
	full, err := s.repo.GetRiwayat(m.ID)
	if err != nil {
		return nil, err
	}
	r := riwayatResp(full, anak.TanggalLahir)
	return &r, nil
}

// SelesaiKonfirmasi: bidan menyatakan riwayat vaksin anak sudah benar.
// Setelah ini imunisasi di posyandu dapat diberikan.
func (s *VaksinService) SelesaiKonfirmasi(bidanID uint, pos string, anakID uuid.UUID) (*KartuVaksinResp, error) {
	anak, err := s.CekAkses(anakID, bidanID, "bidan", pos)
	if err != nil {
		return nil, err
	}
	if n := s.repo.JumlahMenungguKonfirmasi(anak.ID); n > 0 {
		return nil, konflik("masih ada %d vaksin laporan orang tua yang belum dikonfirmasi atau dibatalkan", n)
	}
	now := time.Now()
	oleh := bidanID
	if err := s.repo.SimpanStatusRiwayat(anak.ID, models.RiwayatVaksinDikonfirmasi, &oleh, &now); err != nil {
		return nil, err
	}
	return s.KartuAnak(anak.ID, bidanID, "bidan", pos)
}

// RiwayatLuar: catatan vaksin selain dari sesi posyandu (untuk kartu konfirmasi bidan).
func (s *VaksinService) RiwayatLuar(anak *models.Anak) ([]RiwayatVaksinResp, error) {
	list, err := s.repo.ListRiwayatAnak(anak.ID)
	if err != nil {
		return nil, err
	}
	out := []RiwayatVaksinResp{}
	for i := range list {
		if list[i].PendaftaranID != nil {
			continue
		}
		out = append(out, riwayatResp(&list[i], anak.TanggalLahir))
	}
	return out, nil
}

// ---------------------------------------------------------------- reaksi setelah imunisasi (KIPI)

type LaporKipiInput struct {
	Reaksi string `json:"reaksi" binding:"required"`
}

// LaporKipi: orang tua melaporkan reaksi anak setelah imunisasi; diteruskan ke bidan.
func (s *VaksinService) LaporKipi(uid uint, id uuid.UUID, in LaporKipiInput) (*RiwayatVaksinResp, error) {
	m, err := s.repo.GetRiwayat(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrRiwayatVaksinTidakAda
	}
	if err != nil {
		return nil, err
	}
	anak, err := s.CekAkses(m.AnakID, uid, "orang_tua", "")
	if err != nil {
		return nil, err
	}
	reaksi, err := batasTeks(in.Reaksi, 500, "keterangan reaksi")
	if err != nil {
		return nil, err
	}
	if reaksi == "" {
		return nil, validasi("ceritakan reaksi yang dialami anak")
	}
	if hariIni().Sub(tglSaja(m.TanggalPemberian)) > 30*24*time.Hour {
		return nil, validasi("laporan reaksi hanya untuk imunisasi dalam 30 hari terakhir; hubungi bidan atau puskesmas")
	}
	now := time.Now()
	m.ReaksiKipi = reaksi
	m.KipiDilaporkanPada = &now
	m.Version++
	if err := s.repo.SaveRiwayat(m); err != nil {
		return nil, err
	}
	if s.notif != nil {
		salin := *m
		go s.notif.LaporanKipi(anak, &salin, uid)
	}
	r := riwayatResp(m, anak.TanggalLahir)
	return &r, nil
}

type TindakLanjutKipiInput struct {
	Reaksi       string `json:"reaksi"`
	TindakLanjut string `json:"tindak_lanjut" binding:"required"`
}

// TindakLanjutKipi: bidan mencatat reaksi (bila belum) dan tindak lanjutnya.
func (s *VaksinService) TindakLanjutKipi(bidanID uint, pos string, id uuid.UUID, in TindakLanjutKipiInput) (*RiwayatVaksinResp, error) {
	m, err := s.repo.GetRiwayat(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrRiwayatVaksinTidakAda
	}
	if err != nil {
		return nil, err
	}
	anak, err := s.CekAkses(m.AnakID, bidanID, "bidan", pos)
	if err != nil {
		return nil, err
	}
	reaksi, err := batasTeks(in.Reaksi, 500, "keterangan reaksi")
	if err != nil {
		return nil, err
	}
	tindak, err := batasTeks(in.TindakLanjut, 500, "tindak lanjut")
	if err != nil {
		return nil, err
	}
	if tindak == "" {
		return nil, validasi("tindak lanjut wajib diisi")
	}
	now := time.Now()
	oleh := bidanID
	if reaksi != "" {
		m.ReaksiKipi = reaksi
		if m.KipiDilaporkanPada == nil {
			m.KipiDilaporkanPada = &now
		}
	}
	if m.ReaksiKipi == "" {
		return nil, validasi("isi reaksi yang dialami anak")
	}
	m.KipiTindakLanjut = tindak
	m.KipiDitanganiOleh = &oleh
	m.KipiDitanganiPada = &now
	m.Version++
	if err := s.repo.SaveRiwayat(m); err != nil {
		return nil, err
	}
	r := riwayatResp(m, anak.TanggalLahir)
	return &r, nil
}

// ---------------------------------------------------------------- foto bukti vaksin

var polaNamaBukti = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png)$`)

// FolderBukti: lokasi penyimpanan foto bukti vaksin di server.
const FolderBukti = "uploads/bukti_vaksin"

func cekNamaBukti(nama string) (string, error) {
	nama = strings.TrimSpace(nama)
	if nama == "" {
		return "", nil
	}
	if !polaNamaBukti.MatchString(nama) {
		return "", validasi("foto bukti tidak valid, unggah ulang foto")
	}
	return nama, nil
}

// NamaBuktiValid: dipakai handler sebelum mengirim file.
func NamaBuktiValid(nama string) bool { return polaNamaBukti.MatchString(nama) }

// ---------------------------------------------------------------- statistik (sekretaris)

type StatistikJenisItem struct {
	JenisVaksin  JenisVaksinResp `json:"jenis_vaksin"`
	JumlahDosis  int             `json:"jumlah_dosis"`
	JumlahAnak   int             `json:"jumlah_anak"`
	DosisPerAnak int16           `json:"dosis_per_anak"`
}

type StatistikVaksinResp struct {
	Posyandu          string               `json:"posyandu"`
	JumlahBalita      int                  `json:"jumlah_balita"`
	TotalDiberikan    int                  `json:"total_diberikan"`
	TotalAnakDivaksin int                  `json:"total_anak_divaksin"`
	AnakJatuhTempo    int                  `json:"anak_jatuh_tempo"`
	AnakTerlambat     int                  `json:"anak_terlambat"`
	AnakDasarLengkap  int                  `json:"anak_dasar_lengkap"`
	AnakUsia12Bulan   int                  `json:"anak_usia_12_bulan"` // sasaran IDL (>= 12 bulan)
	Jenis             []StatistikJenisItem `json:"jenis"`
}

func (s *VaksinService) Statistik(pos string) (*StatistikVaksinResp, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	anakList, err := s.repo.AnakAktifPosyandu(pos)
	if err != nil {
		return nil, err
	}
	master, err := s.repo.ListJadwalMaster()
	if err != nil {
		return nil, err
	}
	jenis, err := s.repo.ListJenisAktif()
	if err != nil {
		return nil, err
	}
	ids := make([]uuid.UUID, 0, len(anakList))
	for _, a := range anakList {
		ids = append(ids, a.ID)
	}
	semua, err := s.repo.ListRiwayatBanyakAnak(ids)
	if err != nil {
		return nil, err
	}
	perAnak := map[uuid.UUID][]models.ImunisasiAnak{}
	dosisJenis := map[uuid.UUID]int{}
	anakJenis := map[uuid.UUID]map[uuid.UUID]bool{}
	for _, r := range semua {
		perAnak[r.AnakID] = append(perAnak[r.AnakID], r)
		dosisJenis[r.JenisVaksinID]++
		if anakJenis[r.JenisVaksinID] == nil {
			anakJenis[r.JenisVaksinID] = map[uuid.UUID]bool{}
		}
		anakJenis[r.JenisVaksinID][r.AnakID] = true
	}

	hari := hariIni()
	out := &StatistikVaksinResp{Posyandu: pos, TotalDiberikan: len(semua), TotalAnakDivaksin: len(perAnak)}
	for i := range anakList {
		a := &anakList[i]
		usia := usiaBulan(a.TanggalLahir, hari)
		if usia > 60 {
			continue
		}
		out.JumlahBalita++
		_, rk := hitungJadwal(a, master, perAnak[a.ID], hari)
		if rk.JatuhTempo > 0 {
			out.AnakJatuhTempo++
		}
		if rk.Terlambat > 0 {
			out.AnakTerlambat++
		}
		if usia >= 12 {
			out.AnakUsia12Bulan++
			if rk.DasarLengkap {
				out.AnakDasarLengkap++
			}
		}
	}
	for i := range jenis {
		j := &jenis[i]
		out.Jenis = append(out.Jenis, StatistikJenisItem{
			JenisVaksin: jenisResp(j), JumlahDosis: dosisJenis[j.ID],
			JumlahAnak: len(anakJenis[j.ID]), DosisPerAnak: j.JumlahDosis,
		})
	}
	return out, nil
}