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

// ============================================================================
// DAFTARKAN BALITA KE SESI POSYANDU HARI INI (kader, walk-in)
//
//   - hanya bila ada sesi posyandu HARI INI yang belum selesai
//   - cari berdasarkan nama balita ATAU nama orang tua
//   - balita yang sudah terdaftar (daftar online) atau sudah check-in
//     TIDAK dapat didaftarkan lagi
//   - pendaftaran baru: langsung check-in + nomor antrean berikutnya
// ============================================================================

const (
	statusBelumTerdaftar = "belum_terdaftar"
	statusTerdaftar      = "terdaftar"
	statusSudahCheckin   = "sudah_checkin"
)

type BalitaSesi struct {
	BalitaID     uuid.UUID `json:"balita_id"`
	Nama         string    `json:"nama"`
	JenisKelamin string    `json:"jenis_kelamin"`
	TanggalLahir string    `json:"tanggal_lahir"`
	UsiaTeks     string    `json:"usia_teks"`
	NamaIbu      string    `json:"nama_ibu"`
	Status       string    `json:"status"` // belum_terdaftar | terdaftar | sudah_checkin
	NomorAntrean *int16    `json:"nomor_antrean"`
	BolehDaftar  bool      `json:"boleh_daftar"`
}

type SesiDaftarBalita struct {
	SesiAktif bool                   `json:"sesi_aktif"`
	Pesan     string                 `json:"pesan,omitempty"`
	Jadwal    *models.JadwalPosyandu `json:"jadwal"`
	Balita    []BalitaSesi           `json:"balita"`
}

type HasilDaftarBalita struct {
	PendaftaranID uuid.UUID `json:"pendaftaran_id"`
	BalitaID      uuid.UUID `json:"balita_id"`
	Nama          string    `json:"nama"`
	NomorAntrean  *int16    `json:"nomor_antrean"`
}

// sesiHariIni: jadwal posyandu hari ini yang masih aktif (belum lewat jam selesai).
func (s *JadwalService) sesiHariIni(pos string) (*models.JadwalPosyandu, error) {
	hi := hariIni()
	kandidat, err := s.repo.JadwalMendatang(hi.Format("2006-01-02"), pos)
	if err != nil {
		return nil, err
	}
	for i := range kandidat {
		j := &kandidat[i]
		y, m, d := j.Tanggal.Date()
		if y == hi.Year() && m == hi.Month() && d == hi.Day() && !jadwalSelesai(j) {
			return j, nil
		}
	}
	return nil, nil
}

// CariBalitaSesi: balita + status pendaftarannya pada sesi hari ini.
func (s *JadwalService) CariBalitaSesi(pos, kata string) (*SesiDaftarBalita, error) {
	pos, err := posKader(pos)
	if err != nil {
		return nil, err
	}
	out := &SesiDaftarBalita{Balita: []BalitaSesi{}}
	j, err := s.sesiHariIni(pos)
	if err != nil {
		return nil, err
	}
	if j == nil {
		out.Pesan = "Tidak ada sesi posyandu hari ini. Balita hanya dapat didaftarkan pada hari pelaksanaan posyandu."
		return out, nil
	}
	out.SesiAktif = true
	out.Jadwal = j

	kata = strings.TrimSpace(kata)
	if len([]rune(kata)) < 2 {
		return out, nil
	}
	rows, err := s.repo.CariBalitaDanIbu(pos, kata)
	if err != nil {
		return nil, err
	}
	ids := make([]uuid.UUID, 0, len(rows))
	for _, r := range rows {
		ids = append(ids, r.BalitaID)
	}
	daftar, err := s.repo.ListPendaftaranBalita(ids, j.ID)
	if err != nil {
		return nil, err
	}
	peta := map[uuid.UUID]models.Pendaftaran{}
	for _, p := range daftar {
		peta[p.BalitaID] = p
	}

	acuan := hariIni()
	for _, r := range rows {
		st := statusBelumTerdaftar
		var nomor *int16
		if p, ok := peta[r.BalitaID]; ok {
			switch p.StatusKehadiran {
			case statusTerdaftar:
				st, nomor = statusTerdaftar, p.NomorAntrean
			case statusSudahCheckin:
				st, nomor = statusSudahCheckin, p.NomorAntrean
			}
		}
		lahir := tglRekap(r.TanggalLahir)
		out.Balita = append(out.Balita, BalitaSesi{
			BalitaID:     r.BalitaID,
			Nama:         r.Nama,
			JenisKelamin: r.JenisKelamin,
			TanggalLahir: lahir.Format("2006-01-02"),
			UsiaTeks:     usiaTeks(lahir, acuan),
			NamaIbu:      r.NamaIbu,
			Status:       st,
			NomorAntrean: nomor,
			BolehDaftar:  st == statusBelumTerdaftar,
		})
	}
	return out, nil
}

// DaftarkanBalita: daftarkan balita ke sesi hari ini dan langsung check-in.
func (s *JadwalService) DaftarkanBalita(kaderID uint, pos string, balitaID uuid.UUID) (*HasilDaftarBalita, error) {
	pos, err := posKader(pos)
	if err != nil {
		return nil, err
	}
	j, err := s.sesiHariIni(pos)
	if err != nil {
		return nil, err
	}
	if j == nil {
		return nil, konflik("tidak ada sesi posyandu hari ini")
	}
	a, err := s.repo.GetBalita(balitaID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrBalitaTidakAda
	}
	if err != nil {
		return nil, err
	}
	if a.Status != "aktif" {
		return nil, konflik("data balita tidak aktif")
	}
	posBalita, err := s.repo.PosyanduBalita(a.ID)
	if err != nil {
		return nil, err
	}
	if pa, _ := models.NormalisasiPosyandu(posBalita); pa != pos {
		return nil, terlarang("balita ini terdaftar di posyandu lain")
	}

	now := time.Now()
	var hasil *models.Pendaftaran
	err = s.repo.Tx(func(r *repository.JadwalRepository) error {
		p, err := r.FindPendaftaran(j.ID, a.ID)
		switch {
		case err == nil:
			// sudah terdaftar (online) atau sudah check-in: tidak boleh didaftarkan lagi
			if p.StatusKehadiran == statusTerdaftar || p.StatusKehadiran == statusSudahCheckin {
				return konflik("%s sudah terdaftar pada sesi hari ini", a.Nama)
			}
			// pendaftaran lama yang dibatalkan: dipakai lagi dengan nomor antrean baru
			n := r.NomorAntreanBerikut(j.ID)
			p.NomorAntrean = &n
			p.Sumber = "walk_in"
			p.Version++
		case errors.Is(err, gorm.ErrRecordNotFound):
			n := r.NomorAntreanBerikut(j.ID)
			p = &models.Pendaftaran{
				JadwalID:     j.ID,
				BalitaID:     a.ID,
				Sumber:       "walk_in",
				NomorAntrean: &n,
				WaktuDaftar:  now,
				Version:      1,
			}
		default:
			return err
		}
		p.StatusKehadiran = statusSudahCheckin
		p.WaktuCheckin = &now
		p.MetodeCheckin = "manual"
		p.DiverifikasiOleh = &kaderID
		p.WaktuBatal = nil
		hasil = p
		if p.CreatedAt.IsZero() {
			return r.CreatePendaftaran(p)
		}
		return r.SavePendaftaran(p)
	})
	if err != nil {
		return nil, err
	}
	return &HasilDaftarBalita{
		PendaftaranID: hasil.ID,
		BalitaID:      a.ID,
		Nama:          a.Nama,
		NomorAntrean:  hasil.NomorAntrean,
	}, nil
}