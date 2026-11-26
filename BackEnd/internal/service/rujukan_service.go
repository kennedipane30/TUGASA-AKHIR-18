package service

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ============================================================================
// RUJUKAN BALITA (bidan membuat, orang tua melihat)
//
// Bidan memilih anak -> data anak, orang tua, dan pemeriksaan terakhir terisi
// otomatis -> bidan mengisi keluhan, diagnosis, tindakan, tujuan -> surat
// rujukan bernomor dibuat & orang tua diberi notifikasi -> bidan mencatat
// rujukan balik (hasil dari faskes) -> selesai.
// ============================================================================

var ErrRujukanTidakAda = errors.New("rujukan tidak ditemukan")

type RujukanService struct {
	repo  *repository.RujukanRepository
	notif *NotifikasiService
}

func NewRujukanService(repo *repository.RujukanRepository) *RujukanService {
	return &RujukanService{repo: repo}
}

// SetNotifikasi: notifikasi ke orang tua saat rujukan dibuat / selesai / dibatalkan.
func (s *RujukanService) SetNotifikasi(n *NotifikasiService) { s.notif = n }

// ---------------------------------------------------------------- data anak otomatis

type PemeriksaanRujukan struct {
	TanggalUkur string   `json:"tanggal_ukur"`
	UsiaUkur    string   `json:"usia_ukur"`
	BbKg        *float64 `json:"bb_kg"`
	TbCm        *float64 `json:"tb_cm"`
	LilaCm      *float64 `json:"lila_cm"`
	LkCm        *float64 `json:"lk_cm"`
	StatusBbu   string   `json:"status_bbu"`
	StatusTbu   string   `json:"status_tbu"`
	StatusBbtb  string   `json:"status_bbtb"`
	DuaT        bool     `json:"dua_t"`
	Bgm         bool     `json:"bgm"`
}

type DataAnakRujukan struct {
	AnakID           uuid.UUID           `json:"anak_id"`
	Nama             string              `json:"nama"`
	NIK              string              `json:"nik"`
	JenisKelamin     string              `json:"jenis_kelamin"`
	TanggalLahir     string              `json:"tanggal_lahir"`
	UsiaTeks         string              `json:"usia_teks"`
	BeratLahirKg     *float64            `json:"berat_lahir_kg"`
	PanjangLahirCm   *float64            `json:"panjang_lahir_cm"`
	NamaIbu          string              `json:"nama_ibu"`
	NamaAyah         string              `json:"nama_ayah"`
	NamaWali         string              `json:"nama_wali"`
	NoHP             string              `json:"no_hp"`
	Alamat           string              `json:"alamat"`
	Posyandu         string              `json:"posyandu"`
	Pemeriksaan      *PemeriksaanRujukan `json:"pemeriksaan"`
	KeluhanTerakhir  string              `json:"keluhan_terakhir"`
	PenyakitPenyerta string              `json:"penyakit_penyerta"`
}

type AnakCariRujukan struct {
	AnakID       uuid.UUID `json:"anak_id"`
	Nama         string    `json:"nama"`
	JenisKelamin string    `json:"jenis_kelamin"`
	UsiaTeks     string    `json:"usia_teks"`
	NamaOrangTua string    `json:"nama_orang_tua"`
}

func tglTeksRujukan(t time.Time) string { return t.Format("2006-01-02") }

func namaOrtu(list []models.OrangTua) (ibu, ayah, wali, hp string) {
	for _, o := range list {
		n := strings.TrimSpace(o.Nama)
		switch strings.ToLower(o.PeranKeluarga) {
		case "ibu":
			if ibu == "" {
				ibu = n
			}
		case "ayah":
			if ayah == "" {
				ayah = n
			}
		default:
			if wali == "" {
				wali = n
			}
		}
		if hp == "" && strings.TrimSpace(o.NoHP) != "" {
			hp = strings.TrimSpace(o.NoHP)
		}
	}
	return
}

func alamatKeluarga(k *models.Keluarga) string {
	if k == nil {
		return ""
	}
	a := strings.TrimSpace(k.Alamat)
	rtrw := ""
	if strings.TrimSpace(k.RT) != "" || strings.TrimSpace(k.RW) != "" {
		rtrw = fmt.Sprintf("RT %s / RW %s", strings.TrimSpace(k.RT), strings.TrimSpace(k.RW))
	}
	switch {
	case a != "" && rtrw != "":
		return a + ", " + rtrw
	case a != "":
		return a
	default:
		return rtrw
	}
}

func kosongNil(v *float64) *float64 {
	if v == nil || *v <= 0 {
		return nil
	}
	x := *v
	return &x
}

func angkaNil(v float64) *float64 {
	if v <= 0 {
		return nil
	}
	return &v
}

// cekAnakPosyandu: anak harus ada dan terdaftar di posyandu bidan.
func (s *RujukanService) cekAnakPosyandu(anakID uuid.UUID, pos string) (*models.Anak, error) {
	a, err := s.repo.GetAnak(anakID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrAnakTidakAda
	}
	if err != nil {
		return nil, err
	}
	if a.Keluarga == nil || a.Keluarga.Posyandu != pos {
		return nil, terlarang("anak terdaftar di posyandu lain")
	}
	return a, nil
}

// CariAnak: bidan mencari anak berdasarkan nama / NIK di posyandunya.
func (s *RujukanService) CariAnak(pos, kata string) ([]AnakCariRujukan, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	list, err := s.repo.CariAnak(pos, kata)
	if err != nil {
		return nil, err
	}
	hi := hariIni()
	out := make([]AnakCariRujukan, 0, len(list))
	for _, a := range list {
		it := AnakCariRujukan{AnakID: a.ID, Nama: a.Nama, JenisKelamin: a.JenisKelamin,
			UsiaTeks: usiaTeks(tglSaja(a.TanggalLahir), hi)}
		if ortu, err := s.repo.OrangTuaKeluarga(a.KeluargaID); err == nil {
			ibu, ayah, wali, _ := namaOrtu(ortu)
			for _, n := range []string{ibu, ayah, wali} {
				if n != "" {
					it.NamaOrangTua = n
					break
				}
			}
		}
		out = append(out, it)
	}
	return out, nil
}

// dataAnak: identitas anak, orang tua, dan pemeriksaan terakhir (untuk form & salinan surat).
func (s *RujukanService) dataAnak(a *models.Anak) (*DataAnakRujukan, error) {
	hi := hariIni()
	lahir := tglSaja(a.TanggalLahir)
	d := &DataAnakRujukan{
		AnakID: a.ID, Nama: a.Nama, JenisKelamin: a.JenisKelamin,
		TanggalLahir: tglTeksRujukan(lahir), UsiaTeks: usiaTeks(lahir, hi),
		BeratLahirKg: kosongNil(a.BeratLahirKg), PanjangLahirCm: kosongNil(a.PanjangLahirCm),
	}
	if a.NIK != nil {
		d.NIK = strings.TrimSpace(*a.NIK)
	}
	if a.Keluarga != nil {
		d.Alamat = alamatKeluarga(a.Keluarga)
		d.NoHP = strings.TrimSpace(a.Keluarga.NoKontak)
		d.Posyandu = a.Keluarga.Posyandu
	}
	ortu, err := s.repo.OrangTuaKeluarga(a.KeluargaID)
	if err != nil {
		return nil, err
	}
	var hp string
	d.NamaIbu, d.NamaAyah, d.NamaWali, hp = namaOrtu(ortu)
	if d.NoHP == "" {
		d.NoHP = hp
	}

	p, err := s.repo.PengukuranTerakhir(a.ID)
	if err != nil {
		return nil, err
	}
	if p != nil {
		tu := tglSaja(p.TanggalUkur)
		pr := &PemeriksaanRujukan{
			TanggalUkur: tglTeksRujukan(tu), UsiaUkur: usiaTeks(lahir, tu),
			BbKg: angkaNil(p.BbKg), TbCm: angkaNil(p.TbCm),
			LilaCm: kosongNil(p.LilaCm), LkCm: kosongNil(p.LingkarKepalaCm),
		}
		if g, err := s.repo.StatusGiziPengukuran(p.ID); err != nil {
			return nil, err
		} else if g != nil {
			pr.StatusBbu, pr.StatusTbu, pr.StatusBbtb = g.KategoriBbu, g.KategoriTbu, g.KategoriBbtb
		}
		if t, err := s.repo.PenilaianPengukuran(p.ID); err != nil {
			return nil, err
		} else if t != nil {
			pr.DuaT, pr.Bgm = t.DuaT, t.Bgm
		}
		d.Pemeriksaan = pr
	}
	if pb, err := s.repo.PemeriksaanTerakhir(a.ID); err != nil {
		return nil, err
	} else if pb != nil {
		d.KeluhanTerakhir = strings.TrimSpace(pb.Keluhan)
		d.PenyakitPenyerta = strings.TrimSpace(pb.PenyakitPenyerta)
	}
	return d, nil
}

// DataAnak: bidan memilih anak, data otomatis untuk form rujukan.
func (s *RujukanService) DataAnak(pos string, anakID uuid.UUID) (*DataAnakRujukan, error) {
	a, err := s.cekAnakPosyandu(anakID, pos)
	if err != nil {
		return nil, err
	}
	return s.dataAnak(a)
}

// ---------------------------------------------------------------- respons

type RujukanRingkas struct {
	ID           uuid.UUID `json:"id"`
	Nomor        string    `json:"nomor"`
	Tanggal      string    `json:"tanggal"`
	AnakID       uuid.UUID `json:"anak_id"`
	NamaAnak     string    `json:"nama_anak"`
	JenisKelamin string    `json:"jenis_kelamin"`
	UsiaTeks     string    `json:"usia_teks"`
	Diagnosis    string    `json:"diagnosis"`
	Tujuan       string    `json:"tujuan"`
	Status       string    `json:"status"`
}

type RujukanBalik struct {
	TanggalDiperiksa string `json:"tanggal_diperiksa"`
	HasilDiagnosis   string `json:"hasil_diagnosis"`
	TerapiSaran      string `json:"terapi_saran"`
	TindakLanjut     string `json:"tindak_lanjut"`
	DicatatPada      string `json:"dicatat_pada"`
}

type RujukanDetail struct {
	ID             uuid.UUID        `json:"id"`
	Nomor          string           `json:"nomor"`
	Tanggal        string           `json:"tanggal"`
	Posyandu       string           `json:"posyandu"`
	Status         string           `json:"status"`
	DataAnak       *DataAnakRujukan `json:"data_anak"`
	Keluhan        string           `json:"keluhan"`
	Diagnosis      string           `json:"diagnosis"`
	Tindakan       string           `json:"tindakan"`
	Tujuan         string           `json:"tujuan"`
	BidanNama      string           `json:"bidan_nama"`
	Balik          *RujukanBalik    `json:"rujukan_balik"`
	AlasanBatal    string           `json:"alasan_batal"`
	DibatalkanPada string           `json:"dibatalkan_pada"`
	DibuatPada     string           `json:"dibuat_pada"`
}

func (s *RujukanService) salinan(m *models.Rujukan) *DataAnakRujukan {
	d := &DataAnakRujukan{}
	if strings.TrimSpace(m.DataAnak) != "" {
		_ = json.Unmarshal([]byte(m.DataAnak), d)
	}
	if d.Nama == "" {
		d.Nama = m.NamaAnak
	}
	d.AnakID = m.AnakID
	return d
}

func (s *RujukanService) ringkas(m *models.Rujukan) RujukanRingkas {
	d := s.salinan(m)
	return RujukanRingkas{ID: m.ID, Nomor: m.Nomor, Tanggal: tglTeksRujukan(tglSaja(m.Tanggal)),
		AnakID: m.AnakID, NamaAnak: m.NamaAnak, JenisKelamin: d.JenisKelamin, UsiaTeks: d.UsiaTeks,
		Diagnosis: m.Diagnosis, Tujuan: m.Tujuan, Status: m.Status}
}

func (s *RujukanService) detail(m *models.Rujukan) *RujukanDetail {
	out := &RujukanDetail{ID: m.ID, Nomor: m.Nomor, Tanggal: tglTeksRujukan(tglSaja(m.Tanggal)),
		Posyandu: m.Posyandu, Status: m.Status, DataAnak: s.salinan(m),
		Keluhan: m.Keluhan, Diagnosis: m.Diagnosis, Tindakan: m.Tindakan, Tujuan: m.Tujuan,
		BidanNama: m.BidanNama, AlasanBatal: m.AlasanBatal,
		DibuatPada: m.CreatedAt.In(wib).Format("2006-01-02 15:04")}
	if m.DibatalkanPada != nil {
		out.DibatalkanPada = m.DibatalkanPada.In(wib).Format("2006-01-02 15:04")
	}
	if m.BalikDicatatPada != nil {
		b := &RujukanBalik{HasilDiagnosis: m.HasilDiagnosis, TerapiSaran: m.TerapiSaran,
			TindakLanjut: m.TindakLanjut, DicatatPada: m.BalikDicatatPada.In(wib).Format("2006-01-02 15:04")}
		if m.TanggalDiperiksa != nil {
			b.TanggalDiperiksa = tglTeksRujukan(tglSaja(*m.TanggalDiperiksa))
		}
		out.Balik = b
	}
	return out
}

func (s *RujukanService) daftar(list []models.Rujukan) []RujukanRingkas {
	out := make([]RujukanRingkas, 0, len(list))
	for i := range list {
		out = append(out, s.ringkas(&list[i]))
	}
	return out
}

// ---------------------------------------------------------------- bidan

type BuatRujukanInput struct {
	AnakID    uuid.UUID `json:"anak_id"`
	Keluhan   string    `json:"keluhan"`
	Diagnosis string    `json:"diagnosis"`
	Tindakan  string    `json:"tindakan"`
	Tujuan    string    `json:"tujuan"`
}

type UbahRujukanInput struct {
	Keluhan   string `json:"keluhan"`
	Diagnosis string `json:"diagnosis"`
	Tindakan  string `json:"tindakan"`
	Tujuan    string `json:"tujuan"`
}

type RujukanBalikInput struct {
	TanggalDiperiksa string `json:"tanggal_diperiksa"` // YYYY-MM-DD
	HasilDiagnosis   string `json:"hasil_diagnosis"`
	TerapiSaran      string `json:"terapi_saran"`
	TindakLanjut     string `json:"tindak_lanjut"`
}

type BatalRujukanInput struct {
	Alasan string `json:"alasan"`
}

// DaftarBidan: [status] "aktif" (dirujuk) | "selesai" (selesai & dibatalkan) | kosong (semua).
func (s *RujukanService) DaftarBidan(pos, status string) ([]RujukanRingkas, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	var st []string
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "aktif":
		st = []string{models.StatusRujukanDirujuk}
	case "selesai":
		st = []string{models.StatusRujukanSelesai, models.StatusRujukanDibatalkan}
	}
	list, err := s.repo.DaftarPosyandu(pos, st)
	if err != nil {
		return nil, err
	}
	return s.daftar(list), nil
}

func (s *RujukanService) ambilBidan(pos string, id uuid.UUID) (*models.Rujukan, error) {
	m, err := s.repo.Get(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrRujukanTidakAda
	}
	if err != nil {
		return nil, err
	}
	if m.Posyandu != pos {
		return nil, terlarang("rujukan milik posyandu lain")
	}
	return m, nil
}

func (s *RujukanService) DetailBidan(pos string, id uuid.UUID) (*RujukanDetail, error) {
	m, err := s.ambilBidan(pos, id)
	if err != nil {
		return nil, err
	}
	return s.detail(m), nil
}

func wajibTeks(isi string, maks int, nama string) (string, error) {
	v, err := batasTeks(isi, maks, nama)
	if err != nil {
		return "", err
	}
	if v == "" {
		return "", validasi("%s wajib diisi", nama)
	}
	return v, nil
}

// Buat: bidan membuat surat rujukan baru.
func (s *RujukanService) Buat(bidanID uint, pos string, in BuatRujukanInput) (*RujukanDetail, error) {
	if pos == "" {
		return nil, terlarang("akun belum terhubung ke posyandu")
	}
	if in.AnakID == uuid.Nil {
		return nil, validasi("pilih anak yang akan dirujuk")
	}
	a, err := s.cekAnakPosyandu(in.AnakID, pos)
	if err != nil {
		return nil, err
	}
	keluhan, err := wajibTeks(in.Keluhan, 1000, "keluhan")
	if err != nil {
		return nil, err
	}
	diagnosis, err := wajibTeks(in.Diagnosis, 500, "diagnosis")
	if err != nil {
		return nil, err
	}
	tindakan, err := batasTeks(in.Tindakan, 1000, "tindakan yang sudah dilakukan")
	if err != nil {
		return nil, err
	}
	tujuan, err := wajibTeks(in.Tujuan, 200, "tujuan rujukan")
	if err != nil {
		return nil, err
	}
	data, err := s.dataAnak(a)
	if err != nil {
		return nil, err
	}
	js, _ := json.Marshal(data)
	m := &models.Rujukan{
		Posyandu: pos, AnakID: a.ID, BidanID: bidanID, BidanNama: s.repo.NamaUser(bidanID),
		Tanggal: hariIni(), NamaAnak: a.Nama, DataAnak: string(js),
		Keluhan: keluhan, Diagnosis: diagnosis, Tindakan: tindakan, Tujuan: tujuan,
		Status: models.StatusRujukanDirujuk, Version: 1,
	}
	if err := s.repo.Buat(m); err != nil {
		return nil, err
	}
	if s.notif != nil {
		go s.notif.RujukanDibuat(a, m, bidanID)
	}
	return s.detail(m), nil
}

// Ubah: bidan memperbaiki isian rujukan (keluhan, diagnosis, tindakan, tujuan)
// selama rujukan masih aktif. Nomor, tanggal, dan data anak pada surat tetap.
func (s *RujukanService) Ubah(bidanID uint, pos string, id uuid.UUID, in UbahRujukanInput) (*RujukanDetail, error) {
	m, err := s.ambilBidan(pos, id)
	if err != nil {
		return nil, err
	}
	if m.Status != models.StatusRujukanDirujuk {
		return nil, konflik("rujukan yang sudah selesai atau dibatalkan tidak dapat diubah")
	}
	keluhan, err := wajibTeks(in.Keluhan, 1000, "keluhan")
	if err != nil {
		return nil, err
	}
	diagnosis, err := wajibTeks(in.Diagnosis, 500, "diagnosis")
	if err != nil {
		return nil, err
	}
	tindakan, err := batasTeks(in.Tindakan, 1000, "tindakan yang sudah dilakukan")
	if err != nil {
		return nil, err
	}
	tujuan, err := wajibTeks(in.Tujuan, 200, "tujuan rujukan")
	if err != nil {
		return nil, err
	}
	if keluhan == m.Keluhan && diagnosis == m.Diagnosis && tindakan == m.Tindakan && tujuan == m.Tujuan {
		return s.detail(m), nil // tidak ada perubahan
	}
	m.Keluhan, m.Diagnosis, m.Tindakan, m.Tujuan = keluhan, diagnosis, tindakan, tujuan
	m.Version++
	if err := s.repo.Simpan(m); err != nil {
		return nil, err
	}
	if s.notif != nil {
		go s.notif.RujukanDiubah(m, bidanID)
	}
	return s.detail(m), nil
}

// CatatBalik: bidan mencatat (atau memperbaiki) hasil pemeriksaan dari faskes tujuan -> status selesai.
func (s *RujukanService) CatatBalik(bidanID uint, pos string, id uuid.UUID, in RujukanBalikInput) (*RujukanDetail, error) {
	m, err := s.ambilBidan(pos, id)
	if err != nil {
		return nil, err
	}
	if m.Status == models.StatusRujukanDibatalkan {
		return nil, konflik("rujukan sudah dibatalkan")
	}
	tgl, err := time.Parse("2006-01-02", strings.TrimSpace(in.TanggalDiperiksa))
	if err != nil {
		return nil, validasi("tanggal diperiksa harus berformat YYYY-MM-DD")
	}
	tgl = tglSaja(tgl)
	if tgl.Before(tglSaja(m.Tanggal)) {
		return nil, validasi("tanggal diperiksa tidak boleh sebelum tanggal rujukan")
	}
	if tgl.After(hariIni()) {
		return nil, validasi("tanggal diperiksa tidak boleh melewati hari ini")
	}
	hasil, err := wajibTeks(in.HasilDiagnosis, 1000, "hasil / diagnosis dari faskes")
	if err != nil {
		return nil, err
	}
	terapi, err := batasTeks(in.TerapiSaran, 1000, "terapi / saran dari faskes")
	if err != nil {
		return nil, err
	}
	lanjut, err := batasTeks(in.TindakLanjut, 1000, "tindak lanjut di posyandu")
	if err != nil {
		return nil, err
	}
	now := time.Now()
	m.TanggalDiperiksa, m.HasilDiagnosis, m.TerapiSaran, m.TindakLanjut = &tgl, hasil, terapi, lanjut
	m.BalikDicatatPada = &now
	m.Status = models.StatusRujukanSelesai
	m.Version++
	if err := s.repo.Simpan(m); err != nil {
		return nil, err
	}
	if s.notif != nil {
		go s.notif.RujukanSelesai(m, bidanID)
	}
	return s.detail(m), nil
}

// Batal: bidan membatalkan rujukan yang belum selesai.
func (s *RujukanService) Batal(bidanID uint, pos string, id uuid.UUID, in BatalRujukanInput) (*RujukanDetail, error) {
	m, err := s.ambilBidan(pos, id)
	if err != nil {
		return nil, err
	}
	if m.Status != models.StatusRujukanDirujuk {
		return nil, konflik("hanya rujukan yang masih aktif yang dapat dibatalkan")
	}
	alasan, err := wajibTeks(in.Alasan, 300, "alasan pembatalan")
	if err != nil {
		return nil, err
	}
	now := time.Now()
	m.AlasanBatal, m.DibatalkanPada = alasan, &now
	m.Status = models.StatusRujukanDibatalkan
	m.Version++
	if err := s.repo.Simpan(m); err != nil {
		return nil, err
	}
	if s.notif != nil {
		go s.notif.RujukanDibatalkan(m, bidanID)
	}
	return s.detail(m), nil
}

// Hapus: bidan menghapus rujukan (mis. salah input). Orang tua diberi tahu.
func (s *RujukanService) Hapus(bidanID uint, pos string, id uuid.UUID) error {
	m, err := s.ambilBidan(pos, id)
	if err != nil {
		return err
	}
	if err := s.repo.Hapus(m); err != nil {
		return err
	}
	if s.notif != nil {
		salinan := *m
		go s.notif.RujukanDihapus(&salinan, bidanID)
	}
	return nil
}

// ---------------------------------------------------------------- orang tua

func (s *RujukanService) DaftarOrangTua(userID uint) ([]RujukanRingkas, error) {
	list, err := s.repo.DaftarOrangTua(userID)
	if err != nil {
		return nil, err
	}
	return s.daftar(list), nil
}

func (s *RujukanService) DetailOrangTua(userID uint, id uuid.UUID) (*RujukanDetail, error) {
	m, err := s.repo.Get(id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrRujukanTidakAda
	}
	if err != nil {
		return nil, err
	}
	if !s.repo.MilikOrangTua(m.AnakID, userID) {
		return nil, terlarang("rujukan ini bukan untuk anak Anda")
	}
	return s.detail(m), nil
}