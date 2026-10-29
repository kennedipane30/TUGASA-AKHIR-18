package service

import (
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
)

type RiwayatJadwalItem struct {
	ID              uuid.UUID `json:"id"`
	Tanggal         time.Time `json:"tanggal"`
	JamMulai        string    `json:"jam_mulai"`
	JamSelesai      *string   `json:"jam_selesai"`
	Lokasi          string    `json:"lokasi"`
	Status          string    `json:"status"`
	JumlahTerdaftar int       `json:"jumlah_terdaftar"`
	JumlahCheckin   int       `json:"jumlah_checkin"`
}

// RiwayatJadwal: jadwal posyandu akun (hari ini dan sebelumnya) beserta jumlah check-in.
func (s *PelayananService) RiwayatJadwal(pos string) ([]RiwayatJadwalItem, error) {
	if err := wajibPosyandu(pos); err != nil {
		return nil, err
	}
	semua, err := s.jadwal.ListJadwal(pos)
	if err != nil {
		return nil, err
	}
	batas := hariIni()
	pilih := make([]models.JadwalPosyandu, 0, len(semua))
	ids := make([]uuid.UUID, 0, len(semua))
	for _, j := range semua {
		if j.Tanggal.After(batas) {
			continue
		}
		pilih = append(pilih, j)
		ids = append(ids, j.ID)
	}
	ring, err := s.jadwal.RingkasanPendaftaran(ids)
	if err != nil {
		return nil, err
	}
	out := make([]RiwayatJadwalItem, 0, len(pilih))
	for _, j := range pilih {
		r := ring[j.ID]
		out = append(out, RiwayatJadwalItem{
			ID:              j.ID,
			Tanggal:         j.Tanggal,
			JamMulai:        j.JamMulai,
			JamSelesai:      j.JamSelesai,
			Lokasi:          j.Lokasi,
			Status:          j.Status,
			JumlahTerdaftar: r.Terdaftar + r.Checkin,
			JumlahCheckin:   r.Checkin,
		})
	}
	return out, nil
}