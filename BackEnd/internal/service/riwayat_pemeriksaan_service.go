package service

// Riwayat pemeriksaan untuk orang tua: daftar kunjungan balita beserta
// pengukuran, status gizi, catatan bidan, imunisasi, suplemen, dan hasil KPSP.
//
// Riwayat jadwal posyandu ada di riwayat_jadwal_service.go.

import (
	"errors"
	"sort"
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Fitur riwayat untuk orang tua: daftar kunjungan balita beserta pengukuran,
// status gizi, catatan bidan, imunisasi, suplemen, dan hasil KPSP.

type PengukuranRiwayat struct {
	TanggalUkur     time.Time `json:"tanggal_ukur"`
	UsiaBulan       int16     `json:"usia_bulan"`
	BbKg            float64   `json:"bb_kg"`
	TbCm            float64   `json:"tb_cm"`
	CaraUkur        string    `json:"cara_ukur"`
	LingkarKepalaCm *float64  `json:"lingkar_kepala_cm"`
	LilaCm          *float64  `json:"lila_cm"`
}

type RiwayatItem struct {
	PendaftaranID uuid.UUID                `json:"pendaftaran_id"`
	BalitaID      uuid.UUID                `json:"balita_id"`
	NamaBalita    string                   `json:"nama_balita"`
	Tanggal       time.Time                `json:"tanggal"`
	JamMulai      string                   `json:"jam_mulai"`
	Pengukuran    *PengukuranRiwayat       `json:"pengukuran"`
	StatusGizi    *models.StatusGizi       `json:"status_gizi"`
	Penilaian     *models.PenilaianTimbang `json:"penilaian"`
	Catatan       *models.PemeriksaanBidan `json:"catatan"`
	Imunisasi     []models.ImunisasiBalita `json:"imunisasi"`
	Suplemen      []models.SuplemenBalita  `json:"suplemen"`
	Kpsp          *models.HasilKpsp        `json:"kpsp"` // skrining perkembangan kunjungan ini
}

// Riwayat menampilkan kunjungan yang SUDAH diukur kader atau SUDAH diberi catatan bidan,
// hanya untuk balita keluarga sendiri. Status gizi tampil begitu kader menyimpan pengukuran.
func (s *PelayananService) Riwayat(userID uint, balitaID *uuid.UUID) ([]RiwayatItem, error) {
	kosong := []RiwayatItem{}
	ibu, err := s.kel.FindIbuByUser(userID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return kosong, nil
	}
	if err != nil {
		return nil, err
	}
	balitaList, err := s.kel.ListBalita(ibu.KeluargaID)
	if err != nil {
		return nil, err
	}
	nama := map[uuid.UUID]string{}
	ids := make([]uuid.UUID, 0, len(balitaList))
	for _, a := range balitaList {
		nama[a.ID] = a.Nama
		ids = append(ids, a.ID)
	}
	if balitaID != nil {
		if _, ok := nama[*balitaID]; !ok {
			return nil, terlarang("balita bukan bagian dari keluarga Anda")
		}
		ids = []uuid.UUID{*balitaID}
	}
	if len(ids) == 0 {
		return kosong, nil
	}

	list, err := s.repo.RiwayatPendaftaran(ids)
	if err != nil {
		return nil, err
	}
	pids := idPendaftaran(list)
	ukur, err := s.repo.ListPengukuran(pids)
	if err != nil {
		return nil, err
	}
	periksa, err := s.repo.ListPemeriksaan(pids)
	if err != nil {
		return nil, err
	}
	imun, err := s.repo.ListImunisasi(pids)
	if err != nil {
		return nil, err
	}
	sup, err := s.repo.ListSuplemen(pids)
	if err != nil {
		return nil, err
	}
	kpsp, err := s.repo.ListKpsp(pids)
	if err != nil {
		return nil, err
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
	petaUkur := map[uuid.UUID]models.Pengukuran{}
	for _, u := range ukur {
		petaUkur[u.PendaftaranID] = u
	}
	petaCatatan := map[uuid.UUID]models.PemeriksaanBidan{}
	for _, c := range periksa {
		if c.TampilKeOrangTua {
			petaCatatan[c.PendaftaranID] = c
		}
	}
	petaImun := map[uuid.UUID][]models.ImunisasiBalita{}
	for _, i := range imun {
		if i.PendaftaranID != nil {
			petaImun[*i.PendaftaranID] = append(petaImun[*i.PendaftaranID], i)
		}
	}
	petaSup := map[uuid.UUID][]models.SuplemenBalita{}
	for _, x := range sup {
		if x.PendaftaranID != nil {
			petaSup[*x.PendaftaranID] = append(petaSup[*x.PendaftaranID], x)
		}
	}

	petaKpsp := map[uuid.UUID]models.HasilKpsp{}
	for _, x := range kpsp {
		if x.PendaftaranID != nil {
			petaKpsp[*x.PendaftaranID] = x
		}
	}

	out := make([]RiwayatItem, 0, len(list))
	for _, p := range list {
		it := RiwayatItem{
			PendaftaranID: p.ID,
			BalitaID:      p.BalitaID,
			NamaBalita:    nama[p.BalitaID],
			Imunisasi:     petaImun[p.ID],
			Suplemen:      petaSup[p.ID],
		}
		if it.Imunisasi == nil {
			it.Imunisasi = []models.ImunisasiBalita{}
		}
		if it.Suplemen == nil {
			it.Suplemen = []models.SuplemenBalita{}
		}
		if k, ok := petaKpsp[p.ID]; ok {
			it.Kpsp = &k
		}
		if p.Jadwal != nil {
			it.Tanggal = p.Jadwal.Tanggal
			it.JamMulai = p.Jadwal.JamMulai
		}
		if u, ok := petaUkur[p.ID]; ok {
			it.Pengukuran = &PengukuranRiwayat{
				TanggalUkur: u.TanggalUkur, UsiaBulan: u.UsiaBulan, BbKg: u.BbKg, TbCm: u.TbCm,
				CaraUkur: u.CaraUkur, LingkarKepalaCm: u.LingkarKepalaCm, LilaCm: u.LilaCm,
			}
			if g, ok := petaGizi[u.ID]; ok {
				gg := g
				it.StatusGizi = &gg
			}
			if n, ok := nilai[u.ID]; ok {
				nn := n
				it.Penilaian = &nn
			}
		}
		if c, ok := petaCatatan[p.ID]; ok {
			cc := c
			it.Catatan = &cc
		}
		out = append(out, it)
	}
	sort.Slice(out, func(i, j int) bool {
		if !out[i].Tanggal.Equal(out[j].Tanggal) {
			return out[i].Tanggal.After(out[j].Tanggal)
		}
		return out[i].JamMulai > out[j].JamMulai
	})
	return out, nil
}