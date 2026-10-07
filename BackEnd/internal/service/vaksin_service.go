package service

import (
	"errors"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

const (
	vaksinRoleBidan    = "bidan"
	vaksinRoleKader    = "kader"
	vaksinRoleOrangTua = "orangtua"

	vaksinTglLayout = "2006-01-02"
)

var (
	ErrVaksinAnakTidakDitemukan     = errors.New("data anak tidak ditemukan")
	ErrVaksinJadwalTidakDitemukan   = errors.New("jadwal imunisasi tidak ditemukan")
	ErrVaksinRencanaTidakDitemukan  = errors.New("rencana vaksin tidak ditemukan")
	ErrVaksinAksesDitolak           = errors.New("tidak memiliki akses ke data anak ini")
	ErrVaksinTanggalTidakValid      = errors.New("format tanggal harus YYYY-MM-DD")
	ErrVaksinTanggalLampau          = errors.New("tanggal rencana tidak boleh sebelum hari ini")
	ErrVaksinTanggalMasaDepan       = errors.New("tanggal pemberian tidak boleh di masa depan")
	ErrVaksinTanggalSebelumLahir    = errors.New("tanggal tidak boleh sebelum tanggal lahir anak")
	ErrVaksinAlasanWajib            = errors.New("alasan/dasar hasil pemeriksaan wajib diisi")
	ErrVaksinRencanaDuplikat        = errors.New("rencana untuk vaksin dan dosis ini sudah ada")
	ErrVaksinSudahDiberikan         = errors.New("vaksin dan dosis ini sudah tercatat diberikan")
	ErrVaksinRencanaTidakBisaDiubah = errors.New("rencana yang sudah selesai atau dibatalkan tidak dapat diubah")
	ErrVaksinDosisTidakValid        = errors.New("dosis tidak valid")
)

type VaksinService struct{ repo *repository.VaksinRepository }

func NewVaksinService(repo *repository.VaksinRepository) *VaksinService {
	return &VaksinService{repo}
}

// ---------------------------------------------------------------- input & response

type BuatRencanaInput struct {
	AnakID            uuid.UUID
	JadwalImunisasiID uuid.UUID
	PerkiraanTanggal  string
	Alasan            string
}

type UbahRencanaInput struct {
	PerkiraanTanggal string
	Alasan           string
}

type CatatRiwayatInput struct {
	AnakID           uuid.UUID
	JenisVaksinID    uuid.UUID
	DosisKe          int16
	TanggalPemberian string
	KondisiAnak      string
	Catatan          string
}

type JadwalMasterResp struct {
	ID               uuid.UUID           `json:"id"`
	JenisVaksin      *models.JenisVaksin `json:"jenis_vaksin"`
	DosisKe          int16               `json:"dosis_ke"`
	UsiaMinBulan     int16               `json:"usia_min_bulan"`
	UsiaIdealBulan   int16               `json:"usia_ideal_bulan"`
	UsiaMaksBulan    *int16              `json:"usia_maks_bulan"`
	JarakMinimalHari *int16              `json:"jarak_minimal_hari"`
}

type RencanaVaksinResp struct {
	ID                uuid.UUID           `json:"id"`
	AnakID            uuid.UUID           `json:"anak_id"`
	JadwalImunisasiID uuid.UUID           `json:"jadwal_imunisasi_id"`
	JenisVaksin       *models.JenisVaksin `json:"jenis_vaksin"`
	DosisKe           int16               `json:"dosis_ke"`
	UsiaIdealBulan    int16               `json:"usia_ideal_bulan"`
	PerkiraanTanggal  string              `json:"perkiraan_tanggal"`
	Status            string              `json:"status"`
	Terlambat         bool                `json:"terlambat"`
	DisesuaikanOleh   *uint               `json:"disesuaikan_oleh"`
	Alasan            string              `json:"alasan"`
}

type RiwayatVaksinResp struct {
	ID               uuid.UUID           `json:"id"`
	AnakID           uuid.UUID           `json:"anak_id"`
	JenisVaksin      *models.JenisVaksin `json:"jenis_vaksin"`
	DosisKe          int16               `json:"dosis_ke"`
	TanggalPemberian string              `json:"tanggal_pemberian"`
	KondisiAnak      string              `json:"kondisi_anak"`
	Catatan          string              `json:"catatan"`
	DiberikanOleh    uint                `json:"diberikan_oleh"`
	NamaPemberi      string              `json:"nama_pemberi"`
}

// ---------------------------------------------------------------- helper

func vaksinHariIni() time.Time {
	n := time.Now()
	return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, time.UTC)
}

func vaksinParseTanggal(s string) (time.Time, error) {
	t, err := time.Parse(vaksinTglLayout, strings.TrimSpace(s))
	if err != nil {
		return time.Time{}, ErrVaksinTanggalTidakValid
	}
	return t, nil
}

func vaksinTglDate(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func vaksinNotFound(err error, ganti error) error {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ganti
	}
	return err
}

func toRencanaResp(m *models.RencanaImunisasi) RencanaVaksinResp {
	resp := RencanaVaksinResp{
		ID:                m.ID,
		AnakID:            m.AnakID,
		JadwalImunisasiID: m.JadwalImunisasiID,
		PerkiraanTanggal:  m.PerkiraanTanggal.Format(vaksinTglLayout),
		Status:            m.Status,
		DisesuaikanOleh:   m.DisesuaikanOleh,
		Alasan:            m.AlasanPenyesuaian,
		Terlambat: (m.Status == "direncanakan" || m.Status == "terlewat") &&
			vaksinTglDate(m.PerkiraanTanggal).Before(vaksinHariIni()),
	}
	if m.JadwalImunisasi != nil {
		resp.DosisKe = m.JadwalImunisasi.DosisKe
		resp.UsiaIdealBulan = m.JadwalImunisasi.UsiaIdealBulan
		resp.JenisVaksin = m.JadwalImunisasi.JenisVaksin
	}
	return resp
}

func toRiwayatResp(m *models.ImunisasiAnak) RiwayatVaksinResp {
	resp := RiwayatVaksinResp{
		ID:               m.ID,
		AnakID:           m.AnakID,
		JenisVaksin:      m.JenisVaksin,
		DosisKe:          m.DosisKe,
		TanggalPemberian: m.TanggalPemberian.Format(vaksinTglLayout),
		KondisiAnak:      m.KondisiAnak,
		Catatan:          m.Catatan,
		DiberikanOleh:    m.DiberikanOleh,
	}
	if m.DiberikanOlehUser != nil {
		resp.NamaPemberi = m.DiberikanOlehUser.Nama
	}
	return resp
}

// ---------------------------------------------------------------- akses

func (s *VaksinService) CekAkses(anakID uuid.UUID, uid uint, role string) (*models.Anak, error) {
	a, err := s.repo.GetAnak(anakID)
	if err != nil {
		return nil, vaksinNotFound(err, ErrVaksinAnakTidakDitemukan)
	}
	switch role {
	case vaksinRoleBidan, vaksinRoleKader:
		return a, nil
	case vaksinRoleOrangTua:
		kid, err := s.repo.KeluargaIDByUser(uid)
		if err != nil {
			return nil, vaksinNotFound(err, ErrVaksinAksesDitolak)
		}
		if kid != a.KeluargaID {
			return nil, ErrVaksinAksesDitolak
		}
		return a, nil
	}
	return nil, ErrVaksinAksesDitolak
}

// ---------------------------------------------------------------- master

func (s *VaksinService) ListJadwalMaster() ([]JadwalMasterResp, error) {
	list, err := s.repo.ListJadwalMaster()
	if err != nil {
		return nil, err
	}
	out := make([]JadwalMasterResp, 0, len(list))
	for _, j := range list {
		out = append(out, JadwalMasterResp{
			ID:               j.ID,
			JenisVaksin:      j.JenisVaksin,
			DosisKe:          j.DosisKe,
			UsiaMinBulan:     j.UsiaMinBulan,
			UsiaIdealBulan:   j.UsiaIdealBulan,
			UsiaMaksBulan:    j.UsiaMaksBulan,
			JarakMinimalHari: j.JarakMinimalHari,
		})
	}
	return out, nil
}

// ---------------------------------------------------------------- rencana

func (s *VaksinService) BuatRencana(bidanID uint, in BuatRencanaInput) (*RencanaVaksinResp, error) {
	alasan := strings.TrimSpace(in.Alasan)
	if alasan == "" {
		return nil, ErrVaksinAlasanWajib
	}
	tgl, err := vaksinParseTanggal(in.PerkiraanTanggal)
	if err != nil {
		return nil, err
	}
	if tgl.Before(vaksinHariIni()) {
		return nil, ErrVaksinTanggalLampau
	}

	anak, err := s.repo.GetAnak(in.AnakID)
	if err != nil {
		return nil, vaksinNotFound(err, ErrVaksinAnakTidakDitemukan)
	}
	if anak.Status != "aktif" {
		return nil, ErrVaksinAnakTidakDitemukan
	}
	if tgl.Before(vaksinTglDate(anak.TanggalLahir)) {
		return nil, ErrVaksinTanggalSebelumLahir
	}

	jadwal, err := s.repo.GetJadwalMaster(in.JadwalImunisasiID)
	if err != nil {
		return nil, vaksinNotFound(err, ErrVaksinJadwalTidakDitemukan)
	}
	if s.repo.RiwayatAda(anak.ID, jadwal.JenisVaksinID, jadwal.DosisKe) {
		return nil, ErrVaksinSudahDiberikan
	}
	if s.repo.RencanaAktifAda(anak.ID, jadwal.ID, uuid.Nil) {
		return nil, ErrVaksinRencanaDuplikat
	}

	uid := bidanID
	m := &models.RencanaImunisasi{
		AnakID:            anak.ID,
		JadwalImunisasiID: jadwal.ID,
		PerkiraanTanggal:  tgl,
		Status:            "direncanakan",
		DisesuaikanOleh:   &uid,
		AlasanPenyesuaian: alasan,
	}
	if err := s.repo.CreateRencana(m); err != nil {
		return nil, err
	}
	m.JadwalImunisasi = jadwal
	resp := toRencanaResp(m)
	return &resp, nil
}

func (s *VaksinService) UbahRencana(bidanID uint, id uuid.UUID, in UbahRencanaInput) (*RencanaVaksinResp, error) {
	alasan := strings.TrimSpace(in.Alasan)
	if alasan == "" {
		return nil, ErrVaksinAlasanWajib
	}
	tgl, err := vaksinParseTanggal(in.PerkiraanTanggal)
	if err != nil {
		return nil, err
	}
	if tgl.Before(vaksinHariIni()) {
		return nil, ErrVaksinTanggalLampau
	}

	m, err := s.repo.GetRencana(id)
	if err != nil {
		return nil, vaksinNotFound(err, ErrVaksinRencanaTidakDitemukan)
	}
	if m.Status != "direncanakan" && m.Status != "terlewat" {
		return nil, ErrVaksinRencanaTidakBisaDiubah
	}

	anak, err := s.repo.GetAnak(m.AnakID)
	if err != nil {
		return nil, vaksinNotFound(err, ErrVaksinAnakTidakDitemukan)
	}
	if tgl.Before(vaksinTglDate(anak.TanggalLahir)) {
		return nil, ErrVaksinTanggalSebelumLahir
	}

	uid := bidanID
	m.PerkiraanTanggal = tgl
	m.Status = "direncanakan"
	m.DisesuaikanOleh = &uid
	m.AlasanPenyesuaian = alasan
	m.Version++
	if err := s.repo.SaveRencana(m); err != nil {
		return nil, err
	}
	resp := toRencanaResp(m)
	return &resp, nil
}

func (s *VaksinService) BatalkanRencana(bidanID uint, id uuid.UUID, alasan string) (*RencanaVaksinResp, error) {
	m, err := s.repo.GetRencana(id)
	if err != nil {
		return nil, vaksinNotFound(err, ErrVaksinRencanaTidakDitemukan)
	}
	if m.Status != "direncanakan" && m.Status != "terlewat" {
		return nil, ErrVaksinRencanaTidakBisaDiubah
	}

	uid := bidanID
	m.Status = "dibatalkan"
	m.DisesuaikanOleh = &uid
	if a := strings.TrimSpace(alasan); a != "" {
		m.AlasanPenyesuaian = a
	}
	m.Version++
	if err := s.repo.SaveRencana(m); err != nil {
		return nil, err
	}
	resp := toRencanaResp(m)
	return &resp, nil
}

func (s *VaksinService) ListRencana(anakID uuid.UUID, uid uint, role string) ([]RencanaVaksinResp, error) {
	if _, err := s.CekAkses(anakID, uid, role); err != nil {
		return nil, err
	}
	list, err := s.repo.ListRencanaAnak(anakID, "direncanakan", "terlewat")
	if err != nil {
		return nil, err
	}
	out := make([]RencanaVaksinResp, 0, len(list))
	for i := range list {
		out = append(out, toRencanaResp(&list[i]))
	}
	return out, nil
}

// ---------------------------------------------------------------- riwayat

func (s *VaksinService) CatatRiwayat(bidanID uint, in CatatRiwayatInput) (*RiwayatVaksinResp, error) {
	if in.DosisKe <= 0 {
		return nil, ErrVaksinDosisTidakValid
	}
	tgl, err := vaksinParseTanggal(in.TanggalPemberian)
	if err != nil {
		return nil, err
	}
	if tgl.After(vaksinHariIni()) {
		return nil, ErrVaksinTanggalMasaDepan
	}

	anak, err := s.repo.GetAnak(in.AnakID)
	if err != nil {
		return nil, vaksinNotFound(err, ErrVaksinAnakTidakDitemukan)
	}
	if anak.Status != "aktif" {
		return nil, ErrVaksinAnakTidakDitemukan
	}
	if tgl.Before(vaksinTglDate(anak.TanggalLahir)) {
		return nil, ErrVaksinTanggalSebelumLahir
	}

	master, err := s.repo.GetJadwalMasterByVaksinDosis(in.JenisVaksinID, in.DosisKe)
	if err != nil {
		return nil, vaksinNotFound(err, ErrVaksinJadwalTidakDitemukan)
	}
	if s.repo.RiwayatAda(anak.ID, in.JenisVaksinID, in.DosisKe) {
		return nil, ErrVaksinSudahDiberikan
	}

	m := &models.ImunisasiAnak{
		AnakID:           anak.ID,
		JenisVaksinID:    in.JenisVaksinID,
		DosisKe:          in.DosisKe,
		TanggalPemberian: tgl,
		KondisiAnak:      strings.TrimSpace(in.KondisiAnak),
		Catatan:          strings.TrimSpace(in.Catatan),
		DiberikanOleh:    bidanID,
	}

	err = s.repo.Tx(func(tx *repository.VaksinRepository) error {
		if err := tx.CreateRiwayat(m); err != nil {
			return err
		}
		aktif, err := tx.RencanaAktifByVaksinDosis(anak.ID, in.JenisVaksinID, in.DosisKe)
		if err != nil {
			return err
		}
		for i := range aktif {
			aktif[i].Status = "selesai"
			aktif[i].Version++
			if err := tx.SaveRencana(&aktif[i]); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	m.JenisVaksin = master.JenisVaksin
	resp := toRiwayatResp(m)
	if full, err := s.repo.GetRiwayat(m.ID); err == nil {
		resp = toRiwayatResp(full)
	}
	return &resp, nil
}

func (s *VaksinService) ListRiwayat(anakID uuid.UUID, uid uint, role string) ([]RiwayatVaksinResp, error) {
	if _, err := s.CekAkses(anakID, uid, role); err != nil {
		return nil, err
	}
	list, err := s.repo.ListRiwayatAnak(anakID)
	if err != nil {
		return nil, err
	}
	out := make([]RiwayatVaksinResp, 0, len(list))
	for i := range list {
		out = append(out, toRiwayatResp(&list[i]))
	}
	return out, nil
}