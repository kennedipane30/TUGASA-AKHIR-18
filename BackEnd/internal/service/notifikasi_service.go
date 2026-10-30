package service

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

var ErrNotifikasiTidakAda = errors.New("notifikasi tidak ditemukan")

var notifRolePenerima = []string{
	string(models.RoleOrangTua),
	string(models.RoleKader),
	string(models.RoleBidan),
}

var notifNamaHari = [...]string{"Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"}

var notifNamaBulan = [...]string{
	"Januari", "Februari", "Maret", "April", "Mei", "Juni",
	"Juli", "Agustus", "September", "Oktober", "November", "Desember",
}

type NotifikasiService struct {
	repo *repository.NotifikasiRepository
	push *PushService
	loc  *time.Location
}

func NewNotifikasiService(r *repository.NotifikasiRepository, p *PushService) *NotifikasiService {
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		loc = time.FixedZone("WIB", 7*3600)
	}
	return &NotifikasiService{repo: r, push: p, loc: loc}
}

// ---------------------------------------------------------------- input / keluaran

type TokenPerangkatInput struct {
	Token         string `json:"token" binding:"required"`
	Platform      string `json:"platform"`
	NamaPerangkat string `json:"nama_perangkat"`
	VersiAplikasi string `json:"versi_aplikasi"`
}

type DaftarNotifikasi struct {
	Data        []models.Notifikasi `json:"data"`
	Total       int64               `json:"total"`
	BelumDibaca int64               `json:"belum_dibaca"`
}

// ---------------------------------------------------------------- fungsi bantu

func notifParseJam(s string) (int, int, int, bool) {
	s = strings.TrimSpace(s)
	if i := strings.Index(s, "T"); i >= 0 {
		s = s[i+1:]
	}
	if len(s) > 8 {
		s = s[:8]
	}
	for _, f := range []string{"15:04:05", "15:04"} {
		if t, err := time.Parse(f, s); err == nil {
			return t.Hour(), t.Minute(), t.Second(), true
		}
	}
	return 0, 0, 0, false
}

func notifPotong(s string, maks int) string {
	s = strings.TrimSpace(s)
	r := []rune(s)
	if len(r) > maks {
		return string(r[:maks])
	}
	return s
}

func notifNamaPosyandu(kode string) string {
	for _, p := range models.DaftarPosyandu {
		if p.Kode == kode {
			return p.Nama
		}
	}
	return kode
}

func notifLokasi(j *models.JadwalPosyandu) string {
	if l := strings.TrimSpace(j.Lokasi); l != "" {
		return " di " + l
	}
	return ""
}

func notifMenitCheckin(j *models.JadwalPosyandu) int {
	if j.BukaCheckinMenit <= 0 {
		return 60
	}
	return int(j.BukaCheckinMenit)
}

func (s *NotifikasiService) waktuMulai(j *models.JadwalPosyandu) (time.Time, bool) {
	h, m, d, ok := notifParseJam(j.JamMulai)
	if !ok {
		return time.Time{}, false
	}
	y, mo, dd := j.Tanggal.Date()
	return time.Date(y, mo, dd, h, m, d, 0, s.loc), true
}

func (s *NotifikasiService) waktuSelesai(j *models.JadwalPosyandu, mulai time.Time) time.Time {
	if j.JamSelesai != nil {
		if h, m, d, ok := notifParseJam(*j.JamSelesai); ok {
			y, mo, dd := mulai.Date()
			t := time.Date(y, mo, dd, h, m, d, 0, s.loc)
			if t.After(mulai) {
				return t
			}
		}
	}
	return mulai.Add(4 * time.Hour)
}

func (s *NotifikasiService) teksWaktu(t time.Time) string {
	t = t.In(s.loc)
	return fmt.Sprintf("%s, %d %s %d pukul %s WIB",
		notifNamaHari[t.Weekday()], t.Day(), notifNamaBulan[t.Month()-1], t.Year(), t.Format("15.04"))
}

func (s *NotifikasiService) kataHari(mulai, now time.Time) string {
	y1, m1, d1 := now.In(s.loc).Date()
	y2, m2, d2 := mulai.In(s.loc).Date()
	a := time.Date(y1, m1, d1, 0, 0, 0, 0, s.loc)
	b := time.Date(y2, m2, d2, 0, 0, 0, 0, s.loc)
	switch int(b.Sub(a).Hours() / 24) {
	case 0:
		return "hari ini"
	case 1:
		return "besok"
	}
	return ""
}

func (s *NotifikasiService) pulih(nama string) {
	if r := recover(); r != nil {
		log.Printf("notifikasi: panic pada %s: %v", nama, r)
	}
}

// ---------------------------------------------------------------- pengiriman

func (s *NotifikasiService) kirimKeRole(
	j *models.JadwalPosyandu,
	roles []string,
	jenis, kunci string,
	pengirim *uint,
	pesan func(role models.Role) (string, string),
) {
	users, err := s.repo.Penerima(j.Posyandu, roles)
	if err != nil {
		log.Printf("notifikasi: gagal mengambil penerima: %v", err)
		return
	}
	now := time.Now()
	baru := make([]models.Notifikasi, 0, len(users))
	for _, u := range users {
		judul, isi := pesan(u.Role)
		if judul == "" {
			continue
		}
		jid := j.ID
		n := models.Notifikasi{
			UserID:      u.ID,
			Kunci:       kunci,
			Jenis:       jenis,
			Judul:       notifPotong(judul, 150),
			Isi:         isi,
			ObjekTabel:  "jadwal_posyandu",
			ObjekID:     &jid,
			DikirimOleh: pengirim,
			DikirimPada: &now,
			Version:     1,
		}
		ok, err := s.repo.SimpanJikaBaru(&n)
		if err != nil {
			log.Printf("notifikasi: gagal menyimpan untuk user %d: %v", u.ID, err)
			continue
		}
		if ok {
			baru = append(baru, n)
		}
	}
	s.kirimPush(baru)
}

func (s *NotifikasiService) kirimPush(list []models.Notifikasi) {
	if len(list) == 0 || !s.push.Aktif() {
		return
	}
	peta := make(map[uint]models.Notifikasi, len(list))
	ids := make([]uint, 0, len(list))
	for _, n := range list {
		peta[n.UserID] = n
		ids = append(ids, n.UserID)
	}
	perangkat, err := s.repo.TokenPerangkat(ids)
	if err != nil {
		log.Printf("notifikasi: gagal mengambil token perangkat: %v", err)
		return
	}
	for _, p := range perangkat {
		n, ok := peta[p.UserID]
		if !ok {
			continue
		}
		data := map[string]string{
			"notifikasi_id": n.ID.String(),
			"jenis":         n.Jenis,
			"objek_tabel":   n.ObjekTabel,
			"click_action":  "FLUTTER_NOTIFICATION_CLICK",
		}
		if n.ObjekID != nil {
			data["objek_id"] = n.ObjekID.String()
			data["jadwal_id"] = n.ObjekID.String()
		}
		err := s.push.Kirim(p.TokenFCM, n.Judul, n.Isi, data)
		switch {
		case errors.Is(err, ErrTokenPushTidakValid):
			_ = s.repo.KosongkanToken(p.TokenFCM)
		case err != nil:
			log.Printf("notifikasi: push ke user %d gagal: %v", p.UserID, err)
		}
	}
}

// ---------------------------------------------------------------- peristiwa jadwal

// JadwalDibuat: dipanggil setelah sekretaris menambahkan jadwal.
func (s *NotifikasiService) JadwalDibuat(jadwalID uuid.UUID, pengirim uint) {
	defer s.pulih("jadwal dibuat")
	j, err := s.repo.GetJadwal(jadwalID)
	if err != nil {
		log.Printf("notifikasi: jadwal %s tidak ditemukan: %v", jadwalID, err)
		return
	}
	mulai, ok := s.waktuMulai(j)
	if !ok || !time.Now().Before(s.waktuSelesai(j, mulai)) {
		return
	}
	nama := notifNamaPosyandu(j.Posyandu)
	waktu := s.teksWaktu(mulai)
	lokasi := notifLokasi(j)
	kunci := fmt.Sprintf("%s:%s", models.NotifJadwalBaru, j.ID)

	s.kirimKeRole(j, notifRolePenerima, models.NotifJadwalBaru, kunci, &pengirim, func(role models.Role) (string, string) {
		judul := "Jadwal Posyandu Baru"
		if role == models.RoleOrangTua {
			return judul, fmt.Sprintf(
				"Posyandu %s dijadwalkan pada %s%s. Daftarkan anak Anda melalui aplikasi.",
				nama, waktu, lokasi)
		}
		return judul, fmt.Sprintf("Posyandu %s dijadwalkan pada %s%s.", nama, waktu, lokasi)
	})

	// jadwal yang dibuat mendadak langsung diperiksa (misalnya check-in sudah dibuka)
	s.periksaSatuJadwal(j, time.Now().In(s.loc))
}

// JadwalDiubah: dipanggil setelah sekretaris mengubah jadwal.
func (s *NotifikasiService) JadwalDiubah(jadwalID uuid.UUID, pengirim uint) {
	defer s.pulih("jadwal diubah")
	j, err := s.repo.GetJadwal(jadwalID)
	if err != nil {
		log.Printf("notifikasi: jadwal %s tidak ditemukan: %v", jadwalID, err)
		return
	}
	if j.Status != "terjadwal" {
		return
	}
	mulai, ok := s.waktuMulai(j)
	if !ok || !time.Now().Before(s.waktuSelesai(j, mulai)) {
		return
	}
	nama := notifNamaPosyandu(j.Posyandu)
	waktu := s.teksWaktu(mulai)
	lokasi := notifLokasi(j)
	kunci := fmt.Sprintf("%s:%s:%d", models.NotifJadwalDiubah, j.ID, j.UpdatedAt.UnixMilli())

	s.kirimKeRole(j, notifRolePenerima, models.NotifJadwalDiubah, kunci, &pengirim, func(role models.Role) (string, string) {
		return "Jadwal Posyandu Diperbarui",
			fmt.Sprintf("Jadwal posyandu %s diperbarui menjadi %s%s.", nama, waktu, lokasi)
	})

	s.periksaSatuJadwal(j, time.Now().In(s.loc))
}

// JadwalDibatalkan: dipanggil setelah sekretaris membatalkan jadwal.
func (s *NotifikasiService) JadwalDibatalkan(jadwalID uuid.UUID, pengirim uint) {
	defer s.pulih("jadwal dibatalkan")
	j, err := s.repo.GetJadwal(jadwalID)
	if err != nil {
		log.Printf("notifikasi: jadwal %s tidak ditemukan: %v", jadwalID, err)
		return
	}
	mulai, ok := s.waktuMulai(j)
	if !ok || !time.Now().Before(s.waktuSelesai(j, mulai)) {
		return
	}
	nama := notifNamaPosyandu(j.Posyandu)
	waktu := s.teksWaktu(mulai)
	alasan := strings.TrimSpace(j.AlasanBatal)
	kunci := fmt.Sprintf("%s:%s", models.NotifJadwalDibatalkan, j.ID)

	s.kirimKeRole(j, notifRolePenerima, models.NotifJadwalDibatalkan, kunci, &pengirim, func(role models.Role) (string, string) {
		isi := fmt.Sprintf("Posyandu %s pada %s dibatalkan.", nama, waktu)
		if alasan != "" {
			isi += " Alasan: " + alasan + "."
		}
		return "Jadwal Posyandu Dibatalkan", isi
	})
}

// ---------------------------------------------------------------- pengingat otomatis

// JalankanPengingat: diperiksa setiap menit selama server berjalan.
func (s *NotifikasiService) JalankanPengingat(ctx context.Context) {
	s.periksaJadwal()
	t := time.NewTicker(time.Minute)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.periksaJadwal()
		}
	}
}

func (s *NotifikasiService) periksaJadwal() {
	defer s.pulih("pemeriksaan jadwal")
	now := time.Now().In(s.loc)
	list, err := s.repo.JadwalRentang(
		now.AddDate(0, 0, -1).Format("2006-01-02"),
		now.AddDate(0, 0, 2).Format("2006-01-02"),
	)
	if err != nil {
		log.Printf("notifikasi: gagal mengambil jadwal: %v", err)
		return
	}
	for i := range list {
		s.periksaSatuJadwal(&list[i], now)
	}
}

func (s *NotifikasiService) periksaSatuJadwal(j *models.JadwalPosyandu, now time.Time) {
	if j.Status != "terjadwal" {
		return
	}
	mulai, ok := s.waktuMulai(j)
	if !ok {
		return
	}
	if !now.Before(s.waktuSelesai(j, mulai)) {
		return
	}
	batas24 := mulai.Add(-24 * time.Hour)
	bukaCheckin := mulai.Add(-time.Duration(notifMenitCheckin(j)) * time.Minute)

	// pengingat 24 jam sebelum mulai (hanya untuk jadwal yang dibuat lebih dari 24 jam sebelumnya)
	if !now.Before(batas24) && now.Before(bukaCheckin) && j.CreatedAt.Before(batas24) {
		s.kirimPengingat(j, mulai, now)
	}
	// check-in dibuka (default 60 menit sebelum mulai)
	if !now.Before(bukaCheckin) {
		s.kirimCheckinDibuka(j, mulai)
	}
}

func (s *NotifikasiService) kirimPengingat(j *models.JadwalPosyandu, mulai, now time.Time) {
	kunci := fmt.Sprintf("%s:%s:%s", models.NotifPengingatJadwal, j.ID, mulai.Format("200601021504"))
	if s.repo.KunciSudahAda(kunci) {
		return
	}
	nama := notifNamaPosyandu(j.Posyandu)
	waktu := s.teksWaktu(mulai)
	lokasi := notifLokasi(j)
	kata := s.kataHari(mulai, now)
	judul := "Pengingat Jadwal Posyandu"
	switch kata {
	case "besok":
		judul = "Pengingat: Posyandu Besok"
	case "hari ini":
		judul = "Pengingat: Posyandu Hari Ini"
	}
	pembuka := fmt.Sprintf("Posyandu %s dilaksanakan", nama)
	if kata != "" {
		pembuka += " " + kata + ","
	}
	menit := notifMenitCheckin(j)

	s.kirimKeRole(j, notifRolePenerima, models.NotifPengingatJadwal, kunci, nil, func(role models.Role) (string, string) {
		if role == models.RoleOrangTua {
			return judul, fmt.Sprintf(
				"%s %s%s. Jangan lupa membawa anak dan buku KIA. Check-in dapat dilakukan %d menit sebelum kegiatan dimulai.",
				pembuka, waktu, lokasi, menit)
		}
		return judul, fmt.Sprintf("%s %s%s. Mohon persiapkan kegiatan pelayanan.", pembuka, waktu, lokasi)
	})
}

func (s *NotifikasiService) kirimCheckinDibuka(j *models.JadwalPosyandu, mulai time.Time) {
	kunci := fmt.Sprintf("%s:%s:%s", models.NotifCheckinDibuka, j.ID, mulai.Format("200601021504"))
	if s.repo.KunciSudahAda(kunci) {
		return
	}
	nama := notifNamaPosyandu(j.Posyandu)
	jam := mulai.In(s.loc).Format("15.04")
	lokasi := notifLokasi(j)
	judul := "Check-in Posyandu Sudah Dibuka"

	s.kirimKeRole(j, notifRolePenerima, models.NotifCheckinDibuka, kunci, nil, func(role models.Role) (string, string) {
		switch role {
		case models.RoleOrangTua:
			return judul, fmt.Sprintf(
				"Check-in posyandu %s sudah dapat dilakukan. Kegiatan dimulai pukul %s WIB%s. Pindai QR posyandu di lokasi untuk mendapatkan nomor antrean.",
				nama, jam, lokasi)
		case models.RoleKader:
			return judul, fmt.Sprintf(
				"Check-in posyandu %s sudah dibuka. Tampilkan QR posyandu untuk dipindai orang tua. Kegiatan dimulai pukul %s WIB%s.",
				nama, jam, lokasi)
		default:
			return judul, fmt.Sprintf(
				"Check-in posyandu %s sudah dibuka. Kegiatan dimulai pukul %s WIB%s.",
				nama, jam, lokasi)
		}
	})
}

// ---------------------------------------------------------------- notifikasi pengguna

func (s *NotifikasiService) List(userID uint, hanyaBelumDibaca bool, limit, offset int) (*DaftarNotifikasi, error) {
	list, total, err := s.repo.List(userID, hanyaBelumDibaca, limit, offset)
	if err != nil {
		return nil, err
	}
	belum, err := s.repo.JumlahBelumDibaca(userID)
	if err != nil {
		return nil, err
	}
	return &DaftarNotifikasi{Data: list, Total: total, BelumDibaca: belum}, nil
}

func (s *NotifikasiService) JumlahBelumDibaca(userID uint) (int64, error) {
	return s.repo.JumlahBelumDibaca(userID)
}

func (s *NotifikasiService) Baca(userID uint, id uuid.UUID) (*models.Notifikasi, error) {
	ok, err := s.repo.TandaiDibaca(userID, id)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrNotifikasiTidakAda
	}
	n, err := s.repo.GetMilik(userID, id)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotifikasiTidakAda
	}
	return n, err
}

func (s *NotifikasiService) BacaSemua(userID uint) (int64, error) {
	return s.repo.TandaiSemuaDibaca(userID)
}

func (s *NotifikasiService) Hapus(userID uint, id uuid.UUID) error {
	ok, err := s.repo.Hapus(userID, id)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotifikasiTidakAda
	}
	return nil
}

// ---------------------------------------------------------------- token perangkat

func (s *NotifikasiService) SimpanToken(userID uint, in TokenPerangkatInput) (*models.Perangkat, error) {
	token := strings.TrimSpace(in.Token)
	if token == "" {
		return nil, validasi("token wajib diisi")
	}
	if len(token) > 255 {
		return nil, validasi("token terlalu panjang")
	}
	return s.repo.SimpanToken(
		userID,
		token,
		notifPotong(in.Platform, 20),
		notifPotong(in.NamaPerangkat, 100),
		notifPotong(in.VersiAplikasi, 20),
	)
}

func (s *NotifikasiService) HapusToken(userID uint, token string) error {
	token = strings.TrimSpace(token)
	if token == "" {
		return validasi("token wajib diisi")
	}
	return s.repo.HapusToken(userID, token)
}