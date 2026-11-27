package service

// Pemeriksaan bidan: antrean pemeriksaan, detail satu kunjungan, dan
// penyimpanan catatan pemeriksaan beserta imunisasi, suplemen, dan KPSP
// dalam satu transaksi.
//
// Perakitan dan validasi KPSP-nya ada di kpsp_service.go.

import (
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Fitur bidan: antrean pemeriksaan, detail satu kunjungan, dan penyimpanan
// catatan pemeriksaan beserta imunisasi, suplemen, dan KPSP dalam satu transaksi.
//
// Perakitan dan validasi KPSP-nya sendiri ada di pelayanan_kpsp.go.


type ImunisasiInput struct {
	JenisImunisasiID string `json:"jenis_vaksin_id" binding:"required"`
	DosisKe       int16  `json:"dosis_ke" binding:"required"`
	KondisiAnak   string `json:"kondisi_anak"` // sehat | demam_ringan (sakit = imunisasi ditunda)
	NomorBatch    string `json:"nomor_batch"`  // opsional
	ReaksiKipi    string `json:"reaksi_kipi"`  // opsional, reaksi setelah imunisasi
	Catatan       string `json:"catatan"`
}

// SuplemenInput: suplemen diinput manual oleh bidan (nama, dosis, jumlah, satuan).
type SuplemenInput struct {
	Nama        string `json:"nama" binding:"required"`
	Dosis       string `json:"dosis"`
	Jumlah      int16  `json:"jumlah"`
	Satuan      string `json:"satuan"`
	AturanPakai string `json:"aturan_pakai"` // mis. "1 x 1 sehari" (opsional)
	Catatan     string `json:"catatan"`
}

// keteranganSuplemenAturan: "dosis · jumlah satuan · aturan pakai" untuk tampilan.
func keteranganSuplemenAturan(dosis string, jumlah int16, satuan, aturan string) string {
	ket := KeteranganSuplemen(dosis, jumlah, satuan)
	if aturan == "" {
		return ket
	}
	if ket == "" {
		return aturan
	}
	return ket + " · " + aturan
}

// CatatanBidanInput: Demam/Diare/Batuk, PenyakitPenyerta, SaranPolaAsuh, Keluhan, dan
// TanggalKunjunganUlang tidak lagi diisi dari aplikasi (kolom tetap ada untuk data lama).
// Keluhan anak diambil dari pendataan kader (pengukuran.keluhan).
type CatatanBidanInput struct {
	Demam                 bool            `json:"demam"`
	Diare                 bool            `json:"diare"`
	Batuk                 bool            `json:"batuk"`
	PenyakitPenyerta      string          `json:"penyakit_penyerta"`
	Keluhan               string          `json:"keluhan"`
	CatatanEvaluasi       string          `json:"catatan_evaluasi"`
	SaranGizi             string          `json:"saran_gizi"`
	SaranPolaAsuh         string          `json:"saran_pola_asuh"`
	TanggalKunjunganUlang string          `json:"tanggal_kunjungan_ulang"` // YYYY-MM-DD
	Imunisasi                []ImunisasiInput   `json:"vaksin"`
	Suplemen              []SuplemenInput `json:"suplemen"`
	Kpsp                  *KpspInput      `json:"kpsp"`
}

type BidanItem struct {
	PendaftaranID      uuid.UUID                `json:"pendaftaran_id"`
	AnakID             uuid.UUID                `json:"anak_id"`
	Nama               string                   `json:"nama"`
	JenisKelamin       string                   `json:"jenis_kelamin"`
	TanggalLahir       string                   `json:"tanggal_lahir"` // YYYY-MM-DD, untuk usia detail di aplikasi
	UsiaBulan          int                      `json:"usia_bulan"`
	NomorAntrean       *int16                   `json:"nomor_antrean"`
	SudahDiukur        bool                     `json:"sudah_diukur"`
	BbKg               float64                  `json:"bb_kg"`
	TbCm               float64                  `json:"tb_cm"`
	PeringatanValidasi string                   `json:"peringatan_validasi"`
	StatusCatatan      string                   `json:"status_catatan"` // perlu_catatan | selesai
	StatusGizi         *models.StatusGizi       `json:"status_gizi"`
	Penilaian          *models.PenilaianTimbang `json:"penilaian"`
}

type DetailBidan struct {
	Anak             models.Anak              `json:"anak"`
	Jadwal           models.JadwalPosyandu    `json:"jadwal"`
	UsiaBulan        int                      `json:"usia_bulan"`
	Pengukuran       *models.Pengukuran       `json:"pengukuran"`
	Sebelumnya       *models.Pengukuran       `json:"pengukuran_sebelumnya"`
	StatusGizi       *models.StatusGizi       `json:"status_gizi"`
	Penilaian        *models.PenilaianTimbang `json:"penilaian"`
	Catatan          *models.PemeriksaanBidan `json:"catatan"`
	Imunisasi        []models.ImunisasiAnak   `json:"imunisasi"`
	Suplemen         []models.SuplemenAnak    `json:"suplemen"`
	RiwayatImunisasi []models.ImunisasiAnak   `json:"riwayat_imunisasi"`
	Kpsp             *models.HasilKpsp        `json:"kpsp"` // skrining perkembangan kunjungan ini
	Rencana          *RencanaAnak             `json:"rencana"` // rencana imunisasi & suplemen kunjungan ini

	// Riwayat imunisasi sebelum posyandu: harus dikonfirmasi bidan sebelum imunisasi diberikan.
	StatusRiwayatImunisasi string              `json:"status_riwayat_vaksin"`
	RiwayatLuar         []RiwayatImunisasiResp `json:"riwayat_luar"`

	// JadwalSelesai: waktu jadwal posyandu sudah lewat. Catatan bidan yang sudah
	// tersimpan tidak dapat diubah lagi (hanya dapat dilihat).
	JadwalSelesai bool `json:"jadwal_selesai"`
}

// AntreanBidan: semua anak yang sudah check-in pada satu jadwal di posyandu bidan.
func (s *PelayananService) AntreanBidan(jadwalID uuid.UUID, pos string) ([]BidanItem, error) {
	if _, err := s.jadwalPos(jadwalID, pos); err != nil {
		return nil, err
	}
	list, err := s.jadwal.ListPendaftaranJadwal(jadwalID, "sudah_checkin")
	if err != nil {
		return nil, err
	}
	ids := idPendaftaran(list)
	ukur, err := s.repo.ListPengukuran(ids)
	if err != nil {
		return nil, err
	}
	periksa, err := s.repo.ListPemeriksaan(ids)
	if err != nil {
		return nil, err
	}
	petaUkur := map[uuid.UUID]models.Pengukuran{}
	for _, u := range ukur {
		petaUkur[u.PendaftaranID] = u
	}
	adaCatatan := map[uuid.UUID]bool{}
	for _, c := range periksa {
		adaCatatan[c.PendaftaranID] = true
	}
	petaGizi := map[uuid.UUID]models.StatusGizi{}
	if s.gizi != nil {
		ukurIDs := make([]uuid.UUID, 0, len(ukur))
		for _, u := range ukur {
			ukurIDs = append(ukurIDs, u.ID)
		}
		if petaGizi, err = s.gizi.PetaPengukuran(ukurIDs); err != nil {
			return nil, err
		}
	}
	nilai, err := s.petaPenilaian(ukur)
	if err != nil {
		return nil, err
	}

	now := time.Now()
	out := make([]BidanItem, 0, len(list))
	for _, p := range list {
		u, diukur := petaUkur[p.ID]
		it := BidanItem{
			PendaftaranID:      p.ID,
			AnakID:             p.AnakID,
			NomorAntrean:       p.NomorAntrean,
			SudahDiukur:        diukur,
			BbKg:               u.BbKg,
			TbCm:               u.TbCm,
			PeringatanValidasi: u.PeringatanValidasi,
			StatusCatatan:      "perlu_catatan",
		}
		if adaCatatan[p.ID] {
			it.StatusCatatan = "selesai"
		}
		if g, ok := petaGizi[u.ID]; diukur && ok {
			gg := g
			it.StatusGizi = &gg
		}
		if n, ok := nilai[u.ID]; diukur && ok {
			nn := n
			it.Penilaian = &nn
		}
		if p.Anak != nil {
			it.Nama = p.Anak.Nama
			it.JenisKelamin = p.Anak.JenisKelamin
			it.TanggalLahir = p.Anak.TanggalLahir.Format("2006-01-02")
			it.UsiaBulan = usiaBulan(p.Anak.TanggalLahir, now)
		}
		out = append(out, it)
	}
	return out, nil
}

// DetailBidan: pengukuran boleh kosong (kader belum mengukur).
func (s *PelayananService) DetailBidan(pos string, pendaftaranID uuid.UUID) (*DetailBidan, error) {
	p, err := s.pendaftaranPos(pendaftaranID, pos)
	if err != nil {
		return nil, err
	}
	if p.Anak == nil {
		return nil, ErrPendaftaranTidakAda
	}

	d := &DetailBidan{
		Anak:          *p.Anak,
		Jadwal:        *p.Jadwal,
		UsiaBulan:     usiaBulan(p.Anak.TanggalLahir, time.Now()),
		JadwalSelesai: jadwalSelesai(p.Jadwal),
	}
	if m, err := s.repo.GetPengukuran(p.ID); err == nil {
		d.Pengukuran = m
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if d.Pengukuran != nil && s.gizi != nil {
		if d.StatusGizi, err = s.gizi.UntukPengukuran(d.Pengukuran.ID); err != nil {
			return nil, err
		}
	}
	if d.Pengukuran != nil && s.kbm != nil {
		if d.Penilaian, err = s.kbm.UntukPengukuran(d.Pengukuran.ID); err != nil {
			return nil, err
		}
	}
	if prev, err := s.repo.PengukuranSebelumnya(p.AnakID, p.ID); err == nil {
		d.Sebelumnya = prev
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if c, err := s.repo.GetPemeriksaan(p.ID); err == nil {
		d.Catatan = c
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}
	if d.Imunisasi, err = s.repo.ListImunisasi([]uuid.UUID{p.ID}); err != nil {
		return nil, err
	}
	sup, err := s.repo.ListSuplemen([]uuid.UUID{p.ID})
	if err != nil {
		return nil, err
	}
	d.Suplemen = sup
	if d.RiwayatImunisasi, err = s.repo.ListImunisasiAnak(p.AnakID); err != nil {
		return nil, err
	}
	if kpsp, err := s.repo.ListKpsp([]uuid.UUID{p.ID}); err != nil {
		return nil, err
	} else if len(kpsp) > 0 {
		d.Kpsp = &kpsp[0]
	}
	d.Rencana = s.notif.RencanaPendaftaran(p.Anak, p.Jadwal, p.ID)
	d.StatusRiwayatImunisasi = p.Anak.StatusRiwayatImunisasi
	if d.StatusRiwayatImunisasi == "" {
		d.StatusRiwayatImunisasi = models.RiwayatImunisasiBelumDitanya
	}
	d.RiwayatLuar = []RiwayatImunisasiResp{}
	if s.imunisasi != nil {
		if d.RiwayatLuar, err = s.imunisasi.RiwayatLuar(p.Anak); err != nil {
			return nil, err
		}
	}
	return d, nil
}

func (s *PelayananService) ListJenisImunisasi() ([]models.JenisImunisasi, error) {
	list, err := s.repo.ListJenisImunisasi()
	if err != nil {
		return nil, err
	}
	sort.SliceStable(list, func(i, j int) bool { return list[i].Urutan < list[j].Urutan })
	return list, nil
}

func (s *PelayananService) SimpanCatatan(bidanID uint, pos string, pendaftaranID uuid.UUID, in CatatanBidanInput) (*DetailBidan, error) {
	p, err := s.pendaftaranPos(pendaftaranID, pos)
	if err != nil {
		return nil, err
	}
	if err := cekSesiSudahMulai(p.Jadwal); err != nil {
		return nil, err
	}
	// Jadwal sudah selesai: catatan bidan yang sudah tersimpan tidak dapat diubah.
	if jadwalSelesai(p.Jadwal) {
		if _, err := s.repo.GetPemeriksaan(p.ID); err == nil {
			return nil, konflik("jadwal posyandu sudah selesai, pemeriksaan bidan tidak dapat diubah lagi")
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, err
		}
	}
	ukur, err := s.repo.GetPengukuran(p.ID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, konflik("kader belum menginput pengukuran")
	}
	if err != nil {
		return nil, err
	}

	// minimal satu isian
	isi := strings.TrimSpace(in.CatatanEvaluasi + in.SaranGizi + in.SaranPolaAsuh + in.Keluhan + in.PenyakitPenyerta)
	if isi == "" && len(in.Imunisasi) == 0 && len(in.Suplemen) == 0 && in.Kpsp == nil {
		return nil, validasi("isi minimal satu catatan, imunisasi, suplemen, atau KPSP")
	}
	ulang, err := parseTanggalMendatang(in.TanggalKunjunganUlang)
	if err != nil {
		return nil, err
	}

	// validasi imunisasi (jadwal imunisasi Kemenkes: usia, urutan dosis, jarak minimal)
	daftarImunisasi, err := s.repo.ListJenisImunisasi()
	if err != nil {
		return nil, err
	}
	petaImunisasi := map[uuid.UUID]models.JenisImunisasi{}
	for _, v := range daftarImunisasi {
		petaImunisasi[v.ID] = v
	}
	pid := p.ID
	tanggal := hariIni()
	imunisasi := make([]models.ImunisasiAnak, 0, len(in.Imunisasi))
	items := make([]ItemImunisasi, 0, len(in.Imunisasi))

	if len(in.Imunisasi) > 0 && p.Anak != nil && !p.Anak.RiwayatImunisasiSudahDikonfirmasi() {
		return nil, konflik("catat riwayat imunisasi anak (kunjungan pertama) terlebih dahulu sebelum memberikan imunisasi")
	}

	// data reaksi (KIPI) dari catatan lama sesi ini dipertahankan
	lama := map[string]models.ImunisasiAnak{}
	if sebelumnya, err := s.repo.ListImunisasi([]uuid.UUID{p.ID}); err == nil {
		for _, x := range sebelumnya {
			lama[fmt.Sprintf("%s|%d", x.JenisImunisasiID, x.DosisKe)] = x
		}
	}
	tempatPos := "Posyandu"
	if p.Jadwal != nil {
		tempatPos = "Posyandu " + notifNamaPosyandu(p.Jadwal.Posyandu)
	}
	oleh := bidanID
	now := time.Now()

	for _, v := range in.Imunisasi {
		id, err := uuid.Parse(strings.TrimSpace(v.JenisImunisasiID))
		if err != nil {
			return nil, validasi("jenis_vaksin_id tidak valid")
		}
		jv, ok := petaImunisasi[id]
		if !ok {
			return nil, validasi("jenis imunisasi tidak ditemukan atau tidak aktif")
		}
		if v.DosisKe < 1 || v.DosisKe > jv.JumlahDosis {
			return nil, validasi("dosis ke-%d tidak sesuai untuk %s (1-%d)", v.DosisKe, jv.Nama, jv.JumlahDosis)
		}
		if strings.EqualFold(jv.Kode, kodeHB0) {
			return nil, validasi("HB0 diberikan di faskes paling lambat usia 7 hari, tidak diberikan di posyandu")
		}
		if s.repo.ImunisasiSudahAda(p.AnakID, id, v.DosisKe, p.ID) {
			return nil, konflik("%s dosis ke-%d sudah tercatat untuk anak ini, tidak boleh diberikan dua kali", jv.Nama, v.DosisKe)
		}
		// Kondisi anak mengikuti pendataan kader (Kondisi Anak: "Sedang sakit").
		// Anak sakit: imunisasi baru ditolak; imunisasi yang sudah tersimpan sesi ini dipertahankan.
		kondisi := models.KondisiAnakSehat
		if ukur.SedangSakit {
			x, sudah := lama[fmt.Sprintf("%s|%d", id, v.DosisKe)]
			if !sudah {
				return nil, validasi("anak sedang sakit (pendataan kader), tunda imunisasi sampai anak sehat")
			}
			kondisi = x.KondisiAnak
		}
		batch, err := batasTeks(v.NomorBatch, 50, "nomor batch")
		if err != nil {
			return nil, err
		}
		reaksi, err := batasTeks(v.ReaksiKipi, 500, "reaksi setelah imunisasi")
		if err != nil {
			return nil, err
		}
		items = append(items, ItemImunisasi{JenisImunisasiID: id, DosisKe: v.DosisKe})
		m := models.ImunisasiAnak{
			AnakID:           p.AnakID,
			JenisImunisasiID:    id,
			DosisKe:          v.DosisKe,
			TanggalPemberian: tanggal,
			Tempat:           tempatPos,
			Sumber:           models.SumberImunisasiPosyandu,
			StatusKonfirmasi: models.KonfirmasiImunisasiOK,
			NomorBatch:       batch,
			KondisiAnak:      kondisi,
			PendaftaranID:    &pid,
			DiberikanOleh:    bidanID,
			DikonfirmasiOleh: &oleh,
			DikonfirmasiPada: &now,
			Catatan:          strings.TrimSpace(v.Catatan),
			Version:          1,
		}
		if x, ada := lama[fmt.Sprintf("%s|%d", id, v.DosisKe)]; ada {
			m.ReaksiKipi = x.ReaksiKipi
			m.KipiDilaporkanPada = x.KipiDilaporkanPada
			m.KipiTindakLanjut = x.KipiTindakLanjut
			m.KipiDitanganiOleh = x.KipiDitanganiOleh
			m.KipiDitanganiPada = x.KipiDitanganiPada
			m.TanggalPemberian = tglSaja(x.TanggalPemberian)
			// nomor batch tidak diisi lagi dari form bidan: data lama tidak boleh hilang
			if m.NomorBatch == "" {
				m.NomorBatch = x.NomorBatch
			}
		}
		if reaksi != "" {
			if m.ReaksiKipi != reaksi {
				m.KipiDilaporkanPada = &now
			}
			m.ReaksiKipi = reaksi
		}
		imunisasi = append(imunisasi, m)
	}
	if s.imunisasi != nil && p.Anak != nil {
		if err := s.imunisasi.ValidasiPemberian(p.Anak, tanggal, items, &pid); err != nil {
			return nil, err
		}
	}

	// suplemen (input manual)
	suplemen := make([]models.SuplemenAnak, 0, len(in.Suplemen))
	for _, x := range in.Suplemen {
		nama := strings.TrimSpace(x.Nama)
		if nama == "" {
			return nil, validasi("nama suplemen wajib diisi")
		}
		if len([]rune(nama)) > 100 {
			return nil, validasi("nama suplemen maksimal 100 karakter")
		}
		dosis := strings.TrimSpace(x.Dosis)
		if len([]rune(dosis)) > 60 {
			return nil, validasi("dosis %s maksimal 60 karakter", nama)
		}
		satuan := strings.TrimSpace(x.Satuan)
		if len([]rune(satuan)) > 30 {
			return nil, validasi("satuan %s maksimal 30 karakter", nama)
		}
		if x.Jumlah < 1 || x.Jumlah > 999 {
			return nil, validasi("jumlah %s harus antara 1-999", nama)
		}
		aturan := strings.TrimSpace(x.AturanPakai)
		if len([]rune(aturan)) > 60 {
			return nil, validasi("aturan pakai %s maksimal 60 karakter", nama)
		}
		// Vitamin A dan obat cacing: sesuai usia, selalu 1 kapsul/tablet.
		if p.Anak != nil {
			usiaSup := usiaBulan(p.Anak.TanggalLahir, tanggal)
			switch {
			case isVitaminA(nama):
				if usiaSup < 6 || usiaSup > batasUsiaAnak {
					return nil, validasi("Vitamin A diberikan untuk usia 6-59 bulan (usia anak %s)", usiaTeks(p.Anak.TanggalLahir, tanggal))
				}
				x.Jumlah, satuan = 1, "kapsul"
			case isObatCacing(nama):
				if usiaSup < 12 || usiaSup > batasUsiaAnak {
					return nil, validasi("obat cacing diberikan untuk usia 12-59 bulan (usia anak %s)", usiaTeks(p.Anak.TanggalLahir, tanggal))
				}
				x.Jumlah, satuan = 1, "tablet"
			}
		}
		suplemen = append(suplemen, models.SuplemenAnak{
			AnakID:          p.AnakID,
			Jenis:           nama,
			Dosis:           dosis,
			Jumlah:          x.Jumlah,
			Satuan:          satuan,
			AturanPakai:     aturan,
			Tanggal:         tanggal,
			KeteranganDosis: keteranganSuplemenAturan(dosis, x.Jumlah, satuan, aturan),
			PendaftaranID:   &pid,
			DiberikanOleh:   bidanID,
			Catatan:         strings.TrimSpace(x.Catatan),
			Version:         1,
		})
	}

	// simpan dalam satu transaksi
	kpsp, err := s.rakitKpsp(bidanID, p, tanggal, in.Kpsp)
	if err != nil {
		return nil, err
	}

	err = s.repo.Tx(func(r *repository.PelayananRepository) error {
		c, err := r.GetPemeriksaan(p.ID)
		baru := false
		if errors.Is(err, gorm.ErrRecordNotFound) {
			baru = true
			c = &models.PemeriksaanBidan{
				PendaftaranID:    p.ID,
				PengukuranID:     &ukur.ID,
				BidanID:          bidanID,
				TampilKeOrangTua: true,
				Version:          1,
			}
		} else if err != nil {
			return err
		} else {
			c.BidanID = bidanID
			c.Version++
		}
		c.Demam = in.Demam
		c.Diare = in.Diare
		c.Batuk = in.Batuk
		c.PenyakitPenyerta = strings.TrimSpace(in.PenyakitPenyerta)
		c.Keluhan = strings.TrimSpace(in.Keluhan)
		c.CatatanEvaluasi = strings.TrimSpace(in.CatatanEvaluasi)
		c.SaranGizi = strings.TrimSpace(in.SaranGizi)
		c.SaranPolaAsuh = strings.TrimSpace(in.SaranPolaAsuh)
		c.TanggalKunjunganUlang = ulang
		if baru {
			err = r.CreatePemeriksaan(c)
		} else {
			err = r.SavePemeriksaan(c)
		}
		if err != nil {
			return err
		}
		if err := r.GantiImunisasi(p.ID, imunisasi); err != nil {
			return err
		}
		if err := r.GantiSuplemen(p.ID, suplemen); err != nil {
			return err
		}
		return r.GantiKpsp(p.ID, kpsp)
	})
	if err != nil {
		return nil, err
	}
	d, err := s.DetailBidan(pos, p.ID)
	if err != nil {
		return nil, err
	}
	// Kabari orang tua: hasil pendataan anak selesai diperiksa bidan.
	if s.notif != nil && p.Anak != nil && d.Catatan != nil && d.Catatan.TampilKeOrangTua {
		a := *p.Anak
		pengirim := bidanID
		go s.notif.HasilPemeriksaan(&a, p.ID, int(d.Catatan.Version), &pengirim)
	}
	return d, nil
}