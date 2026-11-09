package service

import (
	"context"
	"errors"
	"fmt"
	"hash/fnv"
	"log"
	"strings"
	"sync"
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

	// pengingat imunisasi, Vitamin A, dan obat cacing (aktif setelah SetVaksin)
	vaksin         *repository.VaksinRepository
	muHarian       sync.Mutex
	harianTerakhir string
}

func NewNotifikasiService(r *repository.NotifikasiRepository, p *PushService) *NotifikasiService {
	loc, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		loc = time.FixedZone("WIB", 7*3600)
	}
	return &NotifikasiService{repo: r, push: p, loc: loc}
}

// SetVaksin: aktifkan rencana & pengingat imunisasi, Vitamin A, dan obat cacing.
func (s *NotifikasiService) SetVaksin(v *repository.VaksinRepository) { s.vaksin = v }

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
	jid := j.ID
	s.kirimKeUser(users, jenis, kunci, "jadwal_posyandu", &jid, pengirim, pesan)
}

// kirimKeUser: simpan notifikasi untuk setiap pengguna (sekali per kunci) lalu kirim push.
func (s *NotifikasiService) kirimKeUser(
	users []models.User,
	jenis, kunci, objekTabel string,
	objekID *uuid.UUID,
	pengirim *uint,
	pesan func(role models.Role) (string, string),
) {
	now := time.Now()
	baru := make([]models.Notifikasi, 0, len(users))
	for _, u := range users {
		judul, isi := pesan(u.Role)
		if judul == "" {
			continue
		}
		n := models.Notifikasi{
			UserID:      u.ID,
			Kunci:       kunci,
			Jenis:       jenis,
			Judul:       notifPotong(judul, 150),
			Isi:         isi,
			ObjekTabel:  objekTabel,
			ObjekID:     objekID,
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
			switch n.ObjekTabel {
			case "jadwal_posyandu":
				data["jadwal_id"] = n.ObjekID.String()
			case "anak":
				data["anak_id"] = n.ObjekID.String()
			}
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

	// rencana imunisasi, Vitamin A, dan obat cacing per anak
	s.KirimRencana(j, &pengirim, false)
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

	// tanggal berubah: rencana dihitung ulang (notifikasi baru hanya bila isi rencana berubah)
	s.KirimRencana(j, &pengirim, false)
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

	// rencana imunisasi & suplemen pindah ke jadwal berikutnya (bila sudah dibuat)
	s.RencanaSetelahBatal(j, &pengirim)
}

// ---------------------------------------------------------------- peringatan penimbangan

// PeringatanTimbang: dipanggil setelah pengukuran dinilai 2T atau BGM.
// Dikirim sekali per pengukuran ke bidan posyandu anak tersebut dan orang tuanya.
func (s *NotifikasiService) PeringatanTimbang(anak *models.Anak, p *models.PenilaianTimbang, pengirim *uint) {
	defer s.pulih("peringatan timbang")
	if anak == nil || p == nil || !(p.DuaT || p.Bgm) {
		return
	}
	pos, err := s.repo.PosyanduAnak(anak.ID)
	if err != nil {
		log.Printf("notifikasi: posyandu anak %s tidak ditemukan: %v", anak.ID, err)
		return
	}
	// hanya bidan di posyandu anak tersebut (kader tidak menerima)
	bidan, err := s.repo.Penerima(pos, []string{string(models.RoleBidan)})
	if err != nil {
		log.Printf("notifikasi: gagal mengambil bidan: %v", err)
		return
	}
	ortu, err := s.repo.OrangTuaAnak(anak.ID)
	if err != nil {
		log.Printf("notifikasi: gagal mengambil orang tua: %v", err)
	}
	penerima := append(bidan, ortu...)
	if len(penerima) == 0 {
		return
	}

	nama := strings.TrimSpace(anak.Nama)
	usia := usiaTeks(anak.TanggalLahir, p.TanggalUkur)
	bb := fmt.Sprintf("%.1f kg", p.BbKg)
	rincianNaik := ""
	if p.KenaikanGram != nil && p.KbmGram != nil {
		rincianNaik = fmt.Sprintf(" Perubahan BB %+d g, minimal kenaikan %d g.", *p.KenaikanGram, *p.KbmGram)
	}

	var masalahPetugas, masalahOrtu []string
	if p.DuaT {
		masalahPetugas = append(masalahPetugas, "tidak naik berat badan 2 bulan berturut-turut (2T)")
		masalahOrtu = append(masalahOrtu, "belum naik sesuai standar selama 2 bulan berturut-turut")
	}
	if p.Bgm {
		masalahPetugas = append(masalahPetugas, "berada di bawah garis merah (BGM)")
		masalahOrtu = append(masalahOrtu, "masih di bawah batas yang dianjurkan untuk usianya")
	}
	label := "2T"
	if p.DuaT && p.Bgm {
		label = "2T dan BGM"
	} else if p.Bgm {
		label = "BGM"
	}

	aid := anak.ID
	kunci := fmt.Sprintf("%s:%s", models.NotifPeringatanTimbang, p.PengukuranID)
	s.kirimKeUser(penerima, models.NotifPeringatanTimbang, kunci, "anak", &aid, pengirim,
		func(role models.Role) (string, string) {
			if role == models.RoleOrangTua {
				return fmt.Sprintf("Perhatian Pertumbuhan %s", nama), fmt.Sprintf(
					"Berat badan %s %s. Silakan konsultasikan dengan bidan di posyandu atau puskesmas agar mendapat saran gizi yang tepat.",
					nama, strings.Join(masalahOrtu, " dan "))
			}
			return fmt.Sprintf("Peringatan %s: %s", label, nama), fmt.Sprintf(
				"%s (%s) %s. BB %s.%s Perlu pemeriksaan bidan dan pertimbangan rujukan ke puskesmas.",
				nama, usia, strings.Join(masalahPetugas, " dan "), bb, rincianNaik)
		})
}

// ---------------------------------------------------------------- hasil penimbangan

func notifTeksKg(v float64) string {
	return strings.Replace(fmt.Sprintf("%.1f", v), ".", ",", 1) + " kg"
}

// notifLabelBbu: kategori BB/U sesuai Permenkes No. 2 Tahun 2020.
func notifLabelBbu(z *float64) string {
	if z == nil {
		return ""
	}
	switch {
	case *z < -3:
		return "berat badan sangat kurang"
	case *z < -2:
		return "berat badan kurang"
	case *z <= 1:
		return "berat badan normal"
	default:
		return "berisiko berat badan lebih"
	}
}

// HasilTimbang: dipanggil setiap kader menyimpan pengukuran yang BUKAN 2T/BGM.
// Dikirim ke orang tua anak, sekali per versi pengukuran (koreksi kader = notifikasi baru).
func (s *NotifikasiService) HasilTimbang(anak *models.Anak, p *models.PenilaianTimbang, versi int, pengirim *uint) {
	defer s.pulih("hasil timbang")
	if anak == nil || p == nil {
		return
	}
	ortu, err := s.repo.OrangTuaAnak(anak.ID)
	if err != nil {
		log.Printf("notifikasi: gagal mengambil orang tua anak %s: %v", anak.ID, err)
		return
	}
	if len(ortu) == 0 {
		log.Printf("notifikasi: anak %s belum terhubung ke akun orang tua", anak.ID)
		return
	}

	nama := strings.TrimSpace(anak.Nama)
	bb := notifTeksKg(p.BbKg)
	status := ""
	if l := notifLabelBbu(p.ZBbu); l != "" {
		status = fmt.Sprintf(" Status: %s untuk usianya.", l)
	}

	var judul, isi string
	switch p.Status {
	case models.StatusTimbangBaru:
		judul = fmt.Sprintf("Hasil Penimbangan %s", nama)
		isi = fmt.Sprintf(
			"Berat badan %s hari ini %s.%s Ini penimbangan pertama, kenaikan berat badan akan dinilai pada penimbangan bulan depan.",
			nama, bb, status)

	case models.StatusTimbangNaik:
		naik := 0
		if p.KenaikanGram != nil {
			naik = *p.KenaikanGram
		}
		judul = fmt.Sprintf("Berat Badan %s Naik", nama)
		isi = fmt.Sprintf(
			"Berat badan %s hari ini %s, naik %d gram dari bulan lalu.%s Pertahankan ASI dan pola makannya, ya!",
			nama, bb, naik, status)

	case models.StatusTimbangTidakNaik:
		perubahan := "tidak berubah"
		if p.KenaikanGram != nil {
			switch g := *p.KenaikanGram; {
			case g < 0:
				perubahan = fmt.Sprintf("turun %d gram", -g)
			case g > 0:
				perubahan = fmt.Sprintf("hanya naik %d gram", g)
			}
		}
		minimal := ""
		if p.KbmGram != nil {
			minimal = fmt.Sprintf(" (seharusnya naik minimal %d gram)", *p.KbmGram)
		}
		judul = fmt.Sprintf("Berat Badan %s Belum Naik", nama)
		isi = fmt.Sprintf(
			"Berat badan %s hari ini %s, %s dari bulan lalu%s.%s Silakan konsultasikan dengan bidan atau kader posyandu.",
			nama, bb, perubahan, minimal, status)

	default:
		judul = fmt.Sprintf("Hasil Penimbangan %s", nama)
		isi = fmt.Sprintf("Berat badan %s hari ini %s.%s", nama, bb, status)
		if p.SelisihBulan != nil && *p.SelisihBulan > 1 {
			isi += " Kenaikan berat badan belum dapat dinilai karena bulan lalu tidak ditimbang. Usahakan datang ke posyandu setiap bulan, ya."
		}
	}
	if versi > 1 {
		judul = "Diperbarui: " + judul
	}

	aid := anak.ID
	kunci := fmt.Sprintf("%s:%s:v%d", models.NotifHasilTimbang, p.PengukuranID, versi)
	s.kirimKeUser(ortu, models.NotifHasilTimbang, kunci, "anak", &aid, pengirim,
		func(role models.Role) (string, string) { return judul, isi })
}

// ---------------------------------------------------------------- pengingat otomatis

// JalankanPengingat: diperiksa setiap menit selama server berjalan
// (jadwal: 24 jam sebelum & check-in dibuka; kesehatan anak: sekali sehari 07.00 WIB).
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
	s.periksaHarian(now)
}

// periksaHarian: pengingat imunisasi, Vitamin A, dan obat cacing sekali sehari mulai 07.00 WIB.
// Bila server dinyalakan ulang, kunci notifikasi mencegah pengiriman ganda.
func (s *NotifikasiService) periksaHarian(now time.Time) {
	if s.vaksin == nil || now.Hour() < jamCekHarian {
		return
	}
	tgl := now.Format("2006-01-02")
	s.muHarian.Lock()
	if s.harianTerakhir == tgl {
		s.muHarian.Unlock()
		return
	}
	s.harianTerakhir = tgl
	s.muHarian.Unlock()
	go s.Harian(now)
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

// ============================================================================
// PENGINGAT KESEHATAN ANAK (imunisasi, Vitamin A, obat cacing)
//
//   - Imunisasi ikut jadwal posyandu berikutnya: dosis dengan tanggal ideal
//     <= tanggal jadwal (termasuk yang terlambat/dikejar) masuk rencana.
//   - Vitamin A: Februari dan Agustus (kapsul biru 6-11 bln, merah 12-59 bln),
//     ikut jadwal posyandu pada bulan tersebut.
//   - Obat cacing: 12-59 bulan, setiap 6 bulan sejak dosis terakhir.
//   - Rencana tidak disimpan (tanpa tabel baru), selalu dihitung ulang.
//   - Kader tidak menerima notifikasi pengingat ini.
// ============================================================================

const (
	kodeHB0          = "HB0"
	rencanaImunisasi = "imunisasi"
	rencanaVitaminA  = "vitamin_a"
	rencanaCacing    = "obat_cacing"
	maksPengingatH1  = 3
	jamCekHarian     = 7 // 07.00 WIB
)

type RencanaItem struct {
	Jenis         string `json:"jenis"` // imunisasi | vitamin_a | obat_cacing
	Kode          string `json:"kode"`
	JenisVaksinID string `json:"jenis_vaksin_id,omitempty"` // untuk centang otomatis di catatan bidan
	Nama          string `json:"nama"`
	DosisKe       int16  `json:"dosis_ke"`
	Keterangan    string `json:"keterangan"`
	Terlambat     bool   `json:"terlambat"`
}

type RencanaAnak struct {
	Imunisasi []RencanaItem `json:"imunisasi"`
	Suplemen  []RencanaItem `json:"suplemen"`
	KeFaskes  []RencanaItem `json:"ke_faskes"` // harus diberikan di puskesmas/faskes
}

func notifRencanaKosong() *RencanaAnak {
	return &RencanaAnak{Imunisasi: []RencanaItem{}, Suplemen: []RencanaItem{}, KeFaskes: []RencanaItem{}}
}

func (r *RencanaAnak) adaPosyandu() bool { return len(r.Imunisasi)+len(r.Suplemen) > 0 }

func notifKunciItem(it RencanaItem) string {
	return fmt.Sprintf("%s:%s:%d", it.Jenis, it.Kode, it.DosisKe)
}

// kurangi: hapus item yang sudah menjadi rencana jadwal sebelumnya.
func (r *RencanaAnak) kurangi(lain *RencanaAnak) {
	if lain == nil {
		return
	}
	ada := map[string]bool{}
	for _, it := range lain.Imunisasi {
		ada[notifKunciItem(it)] = true
	}
	for _, it := range lain.Suplemen {
		ada[notifKunciItem(it)] = true
	}
	saring := func(list []RencanaItem) []RencanaItem {
		out := []RencanaItem{}
		for _, it := range list {
			if !ada[notifKunciItem(it)] {
				out = append(out, it)
			}
		}
		return out
	}
	r.Imunisasi = saring(r.Imunisasi)
	r.Suplemen = saring(r.Suplemen)
}

func (r *RencanaAnak) semuaPosyandu() []RencanaItem {
	out := make([]RencanaItem, 0, len(r.Imunisasi)+len(r.Suplemen))
	out = append(out, r.Imunisasi...)
	return append(out, r.Suplemen...)
}

// notifSidikItem: penanda pendek isi rencana agar perubahan rencana menghasilkan notifikasi baru.
func notifSidikItem(items []RencanaItem) string {
	h := fnv.New32a()
	for _, it := range items {
		h.Write([]byte(notifKunciItem(it) + "|"))
	}
	return fmt.Sprintf("%08x", h.Sum32())
}

func notifGabungKata(list []string) string {
	switch len(list) {
	case 0:
		return ""
	case 1:
		return list[0]
	}
	return strings.Join(list[:len(list)-1], ", ") + " dan " + list[len(list)-1]
}

func notifTeksItem(items []RencanaItem) string {
	nama := make([]string, 0, len(items))
	for _, it := range items {
		nama = append(nama, it.Nama)
	}
	return notifGabungKata(nama)
}

func notifTglIndo(t time.Time) string {
	return fmt.Sprintf("%d %s %d", t.Day(), notifNamaBulan[t.Month()-1], t.Year())
}

func notifBulanVitaminA(m time.Month) bool { return m == time.February || m == time.August }

func notifAwalSemester(t time.Time) time.Time {
	if t.Month() >= time.July {
		return time.Date(t.Year(), time.July, 1, 0, 0, 0, 0, time.UTC)
	}
	return time.Date(t.Year(), time.January, 1, 0, 0, 0, 0, time.UTC)
}

func notifNamaDosis(it *JadwalAnakItem) string {
	nama := strings.TrimSpace(it.JenisVaksin.Nama)
	if nama == "" {
		nama = it.JenisVaksin.Kode
	}
	if it.JumlahDosis > 1 {
		nama += fmt.Sprintf(" dosis ke-%d", it.DosisKe)
	}
	return nama
}

func notifPerluDiberi(s string) bool {
	return s == StatusVaksinJatuhTemp || s == StatusVaksinTerlambat
}

type notifDataAnak struct {
	master  []models.JadwalImunisasi
	riwayat map[uuid.UUID][]models.ImunisasiAnak
	sup     map[uuid.UUID][]models.SuplemenAnak
}

func (s *NotifikasiService) muat(anak []models.Anak) (*notifDataAnak, error) {
	master, err := s.vaksin.ListJadwalMaster()
	if err != nil {
		return nil, err
	}
	ids := make([]uuid.UUID, 0, len(anak))
	for _, a := range anak {
		ids = append(ids, a.ID)
	}
	riw, err := s.vaksin.ListRiwayatBanyakAnak(ids)
	if err != nil {
		return nil, err
	}
	sup, err := s.repo.SuplemenBanyakAnak(ids)
	if err != nil {
		return nil, err
	}
	d := &notifDataAnak{
		master:  master,
		riwayat: map[uuid.UUID][]models.ImunisasiAnak{},
		sup:     map[uuid.UUID][]models.SuplemenAnak{},
	}
	for _, r := range riw {
		d.riwayat[r.AnakID] = append(d.riwayat[r.AnakID], r)
	}
	for _, s := range sup {
		d.sup[s.AnakID] = append(d.sup[s.AnakID], s)
	}
	return d, nil
}

// notifBalitaAktif: anak yang sudah lahir dan berusia 0-59 bulan pada [hari].
func notifBalitaAktif(list []models.Anak, hari time.Time) []models.Anak {
	out := make([]models.Anak, 0, len(list))
	for _, a := range list {
		lahir := tglSaja(a.TanggalLahir)
		if lahir.After(hari) || usiaBulan(lahir, hari) > batasUsiaBalita {
			continue
		}
		out = append(out, a)
	}
	return out
}

// rencana: imunisasi dan suplemen anak untuk jadwal posyandu tanggal [tgl], dinilai dari [hari].
func (s *NotifikasiService) rencana(a *models.Anak, d *notifDataAnak, tgl, hari time.Time) *RencanaAnak {
	out := notifRencanaKosong()
	tgl, hari = tglSaja(tgl), tglSaja(hari)
	lahir := tglSaja(a.TanggalLahir)
	riw := d.riwayat[a.ID]

	pada, _ := hitungJadwal(a, d.master, riw, tgl)
	kini, _ := hitungJadwal(a, d.master, riw, hari)
	for i := range pada {
		it := &pada[i]
		if it.Opsional {
			continue
		}
		if it.JenisVaksin.Kode == kodeHB0 {
			if i < len(kini) && notifPerluDiberi(kini[i].Status) && int(hari.Sub(lahir).Hours()/24) <= 7 {
				out.KeFaskes = append(out.KeFaskes, RencanaItem{
					Jenis: rencanaImunisasi, Kode: it.JenisVaksin.Kode, Nama: notifNamaDosis(it), DosisKe: it.DosisKe,
					Keterangan: "Diberikan di puskesmas/bidan, paling lambat usia 7 hari",
				})
			}
			continue
		}
		ideal, err := time.Parse(vaksinTglLayout, it.TanggalJadwal)
		if err != nil {
			continue
		}
		item := RencanaItem{Jenis: rencanaImunisasi, Kode: it.JenisVaksin.Kode, Nama: notifNamaDosis(it), DosisKe: it.DosisKe,
			JenisVaksinID: it.JenisVaksin.ID.String()}
		switch {
		case notifPerluDiberi(it.Status) && !ideal.After(tgl):
			item.Terlambat = it.Status == StatusVaksinTerlambat
			if item.Terlambat {
				item.Keterangan = "Terlambat, jadwal ideal " + notifTglIndo(ideal)
			} else {
				item.Keterangan = "Jadwal ideal " + notifTglIndo(ideal)
			}
			out.Imunisasi = append(out.Imunisasi, item)
		case it.Status == StatusVaksinTerlewat && i < len(kini) && notifPerluDiberi(kini[i].Status):
			if it.UsiaMaksBulan != nil {
				batas := lahir.AddDate(0, int(*it.UsiaMaksBulan)+1, 0).AddDate(0, 0, -1)
				item.Keterangan = "Batas usia " + notifTglIndo(batas) + ", berikan di puskesmas sebelum tanggal ini"
			}
			out.KeFaskes = append(out.KeFaskes, item)
		}
	}
	out.Suplemen = s.rencanaSuplemen(a, d, tgl)
	return out
}

func (s *NotifikasiService) rencanaSuplemen(a *models.Anak, d *notifDataAnak, tgl time.Time) []RencanaItem {
	out := []RencanaItem{}
	lahir := tglSaja(a.TanggalLahir)
	if lahir.After(tgl) {
		return out
	}
	u := usiaBulan(lahir, tgl)
	if u < 6 || u > batasUsiaBalita {
		return out
	}
	sup := d.sup[a.ID]

	if notifBulanVitaminA(tgl.Month()) {
		awal := notifAwalSemester(tgl)
		sudah := false
		for _, s := range sup {
			if isVitaminA(s.Jenis) && !tglSaja(s.Tanggal).Before(awal) {
				sudah = true
				break
			}
		}
		if !sudah {
			if u <= 11 {
				out = append(out, RencanaItem{Jenis: rencanaVitaminA, Kode: "VITA-BIRU",
					Nama: "Vitamin A kapsul biru", Keterangan: "100.000 IU, usia 6-11 bulan"})
			} else {
				out = append(out, RencanaItem{Jenis: rencanaVitaminA, Kode: "VITA-MERAH",
					Nama: "Vitamin A kapsul merah", Keterangan: "200.000 IU, usia 12-59 bulan"})
			}
		}
	}

	if u >= 12 {
		var akhir *time.Time
		for i := range sup {
			if !isObatCacing(sup[i].Jenis) {
				continue
			}
			t := tglSaja(sup[i].Tanggal)
			if t.After(tgl) {
				continue
			}
			if akhir == nil || t.After(*akhir) {
				tt := t
				akhir = &tt
			}
		}
		if akhir == nil {
			out = append(out, RencanaItem{Jenis: rencanaCacing, Kode: "OBAT-CACING",
				Nama: "Obat cacing", Keterangan: "Belum pernah tercatat, usia 12-59 bulan"})
		} else if !tgl.Before(akhir.AddDate(0, 6, 0)) {
			out = append(out, RencanaItem{Jenis: rencanaCacing, Kode: "OBAT-CACING",
				Nama: "Obat cacing", Keterangan: "Dosis terakhir " + notifTglIndo(*akhir)})
		}
	}
	return out
}

// RencanaBanyak: rencana per anak untuk satu jadwal (dipakai halaman pendaftaran orang tua).
func (s *NotifikasiService) RencanaBanyak(anak []models.Anak, j *models.JadwalPosyandu) map[uuid.UUID]*RencanaAnak {
	out := map[uuid.UUID]*RencanaAnak{}
	if s.vaksin == nil || j == nil || len(anak) == 0 {
		return out
	}
	hari := hariIni()
	aktif := notifBalitaAktif(anak, hari)
	d, err := s.muat(aktif)
	if err != nil {
		log.Printf("pengingat: gagal memuat data rencana: %v", err)
		return out
	}
	tgl := tglSaja(j.Tanggal)
	for i := range aktif {
		out[aktif[i].ID] = s.rencana(&aktif[i], d, tgl, hari)
	}
	return out
}

// RencanaPendaftaran: "Rencana Hari Ini" satu anak pada kunjungan posyandunya (halaman catatan bidan).
// Vaksin/suplemen yang dicatat pada kunjungan ini diabaikan agar tetap tampil sebagai bagian rencana.
func (s *NotifikasiService) RencanaPendaftaran(a *models.Anak, j *models.JadwalPosyandu, pendaftaranID uuid.UUID) *RencanaAnak {
	if s == nil || s.vaksin == nil || a == nil || j == nil {
		return nil
	}
	tgl := tglSaja(j.Tanggal)
	lahir := tglSaja(a.TanggalLahir)
	if lahir.After(tgl) || usiaBulan(lahir, tgl) > batasUsiaBalita {
		return notifRencanaKosong()
	}
	d, err := s.muat([]models.Anak{*a})
	if err != nil {
		log.Printf("pengingat: gagal memuat rencana anak %s: %v", a.ID, err)
		return nil
	}
	riw := []models.ImunisasiAnak{}
	for _, r := range d.riwayat[a.ID] {
		if r.PendaftaranID == nil || *r.PendaftaranID != pendaftaranID {
			riw = append(riw, r)
		}
	}
	d.riwayat[a.ID] = riw
	sup := []models.SuplemenAnak{}
	for _, x := range d.sup[a.ID] {
		if x.PendaftaranID == nil || *x.PendaftaranID != pendaftaranID {
			sup = append(sup, x)
		}
	}
	d.sup[a.ID] = sup
	return s.rencana(a, d, tgl, tgl)
}

// ---------------------------------------------------------------- rencana saat jadwal dibuat / diubah / dibatalkan

// KirimRencana: rencana imunisasi & suplemen per anak ke orang tua, ringkasan ke bidan.
// [pindahan] = rencana berasal dari jadwal sebelumnya yang dibatalkan.
func (s *NotifikasiService) KirimRencana(j *models.JadwalPosyandu, pengirim *uint, pindahan bool) {
	if s.vaksin == nil || j == nil {
		return
	}
	defer s.pulih("rencana posyandu")
	if j.Status != "terjadwal" {
		return
	}
	hari := hariIni()
	tgl := tglSaja(j.Tanggal)
	if tgl.Before(hari) {
		return
	}
	mulai, ok := s.waktuMulai(j)
	if !ok || !time.Now().Before(s.waktuSelesai(j, mulai)) {
		return
	}

	semua, err := s.vaksin.AnakAktifPosyandu(j.Posyandu)
	if err != nil {
		log.Printf("pengingat: gagal mengambil anak posyandu %s: %v", j.Posyandu, err)
		return
	}
	anak := notifBalitaAktif(semua, hari)
	if len(anak) == 0 {
		return
	}
	d, err := s.muat(anak)
	if err != nil {
		log.Printf("pengingat: gagal memuat data: %v", err)
		return
	}

	// jadwal mendatang lain yang lebih dulu: rencananya tidak diulang di jadwal ini
	var sebelum *models.JadwalPosyandu
	if list, err := s.repo.JadwalMendatangPosyandu(j.Posyandu, hari); err == nil {
		for i := range list {
			if list[i].ID != j.ID && tglSaja(list[i].Tanggal).Before(tgl) {
				sebelum = &list[i]
			}
		}
	}

	namaPos := notifNamaPosyandu(j.Posyandu)
	waktu := s.teksWaktu(mulai)
	lokasi := notifLokasi(j)
	jid := j.ID
	var nAnak, nImun, nVit, nCacing int

	for i := range anak {
		a := &anak[i]
		r := s.rencana(a, d, tgl, hari)
		if sebelum != nil {
			r.kurangi(s.rencana(a, d, tglSaja(sebelum.Tanggal), hari))
		}
		if !r.adaPosyandu() {
			continue
		}
		nAnak++
		if len(r.Imunisasi) > 0 {
			nImun++
		}
		for _, s := range r.Suplemen {
			switch s.Jenis {
			case rencanaVitaminA:
				nVit++
			case rencanaCacing:
				nCacing++
			}
		}

		ortu, err := s.repo.OrangTuaAnak(a.ID)
		if err != nil || len(ortu) == 0 {
			continue
		}
		nama := strings.TrimSpace(a.Nama)
		items := r.semuaPosyandu()
		kunci := fmt.Sprintf("%s:%s:%s:%s:%s", models.NotifRencanaPosyandu, j.ID, a.ID, tgl.Format("20060102"), notifSidikItem(items))
		judul := "Rencana Pelayanan " + nama
		isi := fmt.Sprintf("Pada posyandu %s, %s%s, %s dijadwalkan menerima %s.", namaPos, waktu, lokasi, nama, notifTeksItem(items))
		if pindahan {
			judul = "Rencana " + nama + " Dipindahkan"
			isi = "Jadwal sebelumnya dibatalkan. " + isi
		}
		for _, it := range r.Imunisasi {
			if it.Terlambat {
				isi += " Sebagian imunisasi sudah terlambat, mohon tidak dilewatkan."
				break
			}
		}
		isi += fmt.Sprintf(" Daftarkan %s melalui aplikasi dan bawa buku KIA.", nama)
		s.kirimKeUser(ortu, models.NotifRencanaPosyandu, kunci, "jadwal_posyandu", &jid, pengirim,
			func(models.Role) (string, string) { return judul, isi })
	}

	if nAnak == 0 {
		return
	}
	bidan, err := s.repo.Penerima(j.Posyandu, []string{string(models.RoleBidan)})
	if err != nil || len(bidan) == 0 {
		return
	}
	bagian := []string{}
	if nImun > 0 {
		bagian = append(bagian, fmt.Sprintf("%d balita imunisasi", nImun))
	}
	if nVit > 0 {
		bagian = append(bagian, fmt.Sprintf("%d balita Vitamin A", nVit))
	}
	if nCacing > 0 {
		bagian = append(bagian, fmt.Sprintf("%d balita obat cacing", nCacing))
	}
	kunci := fmt.Sprintf("%s:%s:ringkas:%s:%d-%d-%d-%d", models.NotifRencanaPosyandu, j.ID, tgl.Format("20060102"),
		nAnak, nImun, nVit, nCacing)
	isi := fmt.Sprintf("Posyandu %s, %s%s: %s. Mohon siapkan vaksin dan logistik suplemen.",
		namaPos, waktu, lokasi, notifGabungKata(bagian))
	s.kirimKeUser(bidan, models.NotifRencanaPosyandu, kunci, "jadwal_posyandu", &jid, pengirim,
		func(models.Role) (string, string) { return "Rencana Pelayanan Posyandu", isi })
}

// RencanaSetelahBatal: rencana jadwal yang dibatalkan pindah ke jadwal berikutnya (bila sudah ada).
func (s *NotifikasiService) RencanaSetelahBatal(batal *models.JadwalPosyandu, pengirim *uint) {
	if s.vaksin == nil || batal == nil {
		return
	}
	defer s.pulih("rencana setelah batal")
	list, err := s.repo.JadwalMendatangPosyandu(batal.Posyandu, hariIni())
	if err != nil {
		return
	}
	for i := range list {
		if list[i].ID == batal.ID {
			continue
		}
		mulai, ok := s.waktuMulai(&list[i])
		if !ok || !time.Now().Before(s.waktuSelesai(&list[i], mulai)) {
			continue
		}
		s.KirimRencana(&list[i], pengirim, true)
		return
	}
}

// ---------------------------------------------------------------- pemeriksaan harian (07.00 WIB)

// Harian: H-3, imunisasi terlambat (H-1, maks 3 kali), ke faskes, dan jadwal belum dibuat.
func (s *NotifikasiService) Harian(now time.Time) {
	if s.vaksin == nil {
		return
	}
	defer s.pulih("pengingat kesehatan harian")
	hari := tglSaja(now.In(s.loc))
	for _, pos := range models.DaftarPosyandu {
		s.harianPosyandu(pos.Kode, hari)
	}
}

func (s *NotifikasiService) harianPosyandu(pos string, hari time.Time) {
	semua, err := s.repo.JadwalMendatangPosyandu(pos, hari)
	if err != nil {
		log.Printf("pengingat: gagal mengambil jadwal %s: %v", pos, err)
		return
	}
	now := time.Now()
	jadwal := make([]models.JadwalPosyandu, 0, len(semua))
	for i := range semua {
		mulai, ok := s.waktuMulai(&semua[i])
		if ok && now.Before(s.waktuSelesai(&semua[i], mulai)) {
			jadwal = append(jadwal, semua[i])
		}
	}

	daftar, err := s.vaksin.AnakAktifPosyandu(pos)
	if err != nil {
		log.Printf("pengingat: gagal mengambil anak %s: %v", pos, err)
		return
	}
	anak := notifBalitaAktif(daftar, hari)
	if len(anak) == 0 {
		return
	}
	d, err := s.muat(anak)
	if err != nil {
		log.Printf("pengingat: gagal memuat data %s: %v", pos, err)
		return
	}

	for i := range anak {
		a := &anak[i]
		s.cekFaskes(a, d, hari, jadwal)
		s.cekH3(a, d, hari, jadwal)
		s.cekTerlambat(a, d, hari, jadwal)
	}
	s.cekJadwalBelumAda(pos, anak, d, hari, jadwal)
}

func (s *NotifikasiService) kirimOrtu(a *models.Anak, jenis, kunci, objekTabel string, objekID *uuid.UUID, judul, isi string) {
	if s.repo.KunciSudahAda(kunci) {
		return
	}
	ortu, err := s.repo.OrangTuaAnak(a.ID)
	if err != nil || len(ortu) == 0 {
		return
	}
	s.kirimKeUser(ortu, jenis, kunci, objekTabel, objekID, nil,
		func(models.Role) (string, string) { return judul, isi })
}

// cekFaskes: HB0 bayi baru lahir dan imunisasi yang batas usianya habis sebelum jadwal posyandu berikutnya.
func (s *NotifikasiService) cekFaskes(a *models.Anak, d *notifDataAnak, hari time.Time, jadwal []models.JadwalPosyandu) {
	lahir := tglSaja(a.TanggalLahir)
	kini, _ := hitungJadwal(a, d.master, d.riwayat[a.ID], hari)
	var berikut *time.Time
	if len(jadwal) > 0 {
		t := tglSaja(jadwal[0].Tanggal)
		berikut = &t
	}

	var hb0 bool
	items := []RencanaItem{}
	var batasAwal time.Time
	for i := range kini {
		it := &kini[i]
		if it.Opsional || !notifPerluDiberi(it.Status) {
			continue
		}
		if it.JenisVaksin.Kode == kodeHB0 {
			if int(hari.Sub(lahir).Hours()/24) <= 7 {
				hb0 = true
			}
			continue
		}
		if it.UsiaMaksBulan == nil {
			continue
		}
		batas := lahir.AddDate(0, int(*it.UsiaMaksBulan)+1, 0) // hari pertama lewat batas
		if batas.Sub(hari) > 14*24*time.Hour {
			continue
		}
		if berikut != nil && berikut.Before(batas) {
			continue
		}
		items = append(items, RencanaItem{Jenis: rencanaImunisasi, Kode: it.JenisVaksin.Kode, Nama: notifNamaDosis(it), DosisKe: it.DosisKe})
		if batasAwal.IsZero() || batas.Before(batasAwal) {
			batasAwal = batas
		}
	}

	nama := strings.TrimSpace(a.Nama)
	aid := a.ID
	if hb0 {
		kunci := fmt.Sprintf("%s:%s:%s", models.NotifImunisasiFaskes, a.ID, kodeHB0)
		s.kirimOrtu(a, models.NotifImunisasiFaskes, kunci, "anak", &aid,
			"Imunisasi Hepatitis B (HB0) "+nama,
			fmt.Sprintf("%s perlu mendapat imunisasi Hepatitis B (HB0) di puskesmas, bidan, atau fasilitas kesehatan terdekat, paling lambat usia 7 hari (%s).",
				nama, notifTglIndo(lahir.AddDate(0, 0, 7))))
	}
	if len(items) == 0 {
		return
	}
	kunci := fmt.Sprintf("%s:%s:%s", models.NotifImunisasiFaskes, a.ID, notifSidikItem(items))
	alasan := "belum ada jadwal posyandu sebelum tanggal tersebut"
	if berikut != nil {
		alasan = "jadwal posyandu berikutnya (" + notifTglIndo(*berikut) + ") sudah melewati batas usia"
	}
	s.kirimOrtu(a, models.NotifImunisasiFaskes, kunci, "anak", &aid,
		"Segera ke Puskesmas: Imunisasi "+nama,
		fmt.Sprintf("Imunisasi %s untuk %s harus diberikan paling lambat %s karena batas usia pemberiannya hampir lewat, sedangkan %s. Silakan datang ke puskesmas atau fasilitas kesehatan terdekat.",
			notifTeksItem(items), nama, notifTglIndo(batasAwal.AddDate(0, 0, -1)), alasan))
}

// cekH3: pengingat 3 hari sebelum posyandu yang berisi imunisasi/suplemen untuk anak.
func (s *NotifikasiService) cekH3(a *models.Anak, d *notifDataAnak, hari time.Time, jadwal []models.JadwalPosyandu) {
	target := hari.AddDate(0, 0, 3)
	for ji := range jadwal {
		j := &jadwal[ji]
		tgl := tglSaja(j.Tanggal)
		if !tgl.Equal(target) {
			continue
		}
		r := s.rencana(a, d, tgl, hari)
		if ji > 0 {
			r.kurangi(s.rencana(a, d, tglSaja(jadwal[ji-1].Tanggal), hari))
		}
		if !r.adaPosyandu() {
			return
		}
		mulai, ok := s.waktuMulai(j)
		if !ok {
			return
		}
		nama := strings.TrimSpace(a.Nama)
		items := r.semuaPosyandu()
		jenis := models.NotifPengingatSuplemen
		judul := "3 Hari Lagi: Vitamin A/Obat Cacing " + nama
		if len(r.Imunisasi) > 0 {
			jenis = models.NotifPengingatImunisasi
			judul = "3 Hari Lagi: Imunisasi " + nama
		}
		kunci := fmt.Sprintf("%s:%s:%s:%s", jenis, j.ID, a.ID, notifSidikItem(items))
		jid := j.ID
		s.kirimOrtu(a, jenis, kunci, "jadwal_posyandu", &jid, judul,
			fmt.Sprintf("Posyandu %s dilaksanakan %s%s. %s dijadwalkan menerima %s. Pastikan anak dalam keadaan sehat dan bawa buku KIA.",
				notifNamaPosyandu(j.Posyandu), s.teksWaktu(mulai), notifLokasi(j), nama, notifTeksItem(items)))
		return
	}
}

// cekTerlambat: sekali saat terdeteksi, lalu H-1 sebelum setiap posyandu (maksimal 3 kali).
func (s *NotifikasiService) cekTerlambat(a *models.Anak, d *notifDataAnak, hari time.Time, jadwal []models.JadwalPosyandu) {
	kini, _ := hitungJadwal(a, d.master, d.riwayat[a.ID], hari)
	telat := []RencanaItem{}
	for i := range kini {
		it := &kini[i]
		if it.Opsional || it.JenisVaksin.Kode == kodeHB0 || it.Status != StatusVaksinTerlambat {
			continue
		}
		telat = append(telat, RencanaItem{Jenis: rencanaImunisasi, Kode: it.JenisVaksin.Kode, Nama: notifNamaDosis(it), DosisKe: it.DosisKe, Terlambat: true})
	}
	if len(telat) == 0 {
		return
	}
	nama := strings.TrimSpace(a.Nama)
	awalan := fmt.Sprintf("%s:%s:%s:", models.NotifImunisasiTerlambat, a.ID, notifSidikItem(telat))
	aid := a.ID

	kunciAwal := awalan + "awal"
	if !s.repo.KunciSudahAda(kunciAwal) {
		saran := " Silakan datang ke posyandu berikutnya atau puskesmas terdekat."
		if len(jadwal) > 0 {
			saran = fmt.Sprintf(" Bawa %s ke posyandu %s.", nama, notifTglIndo(tglSaja(jadwal[0].Tanggal)))
		}
		s.kirimOrtu(a, models.NotifImunisasiTerlambat, kunciAwal, "anak", &aid,
			"Imunisasi "+nama+" Terlambat",
			fmt.Sprintf("Imunisasi %s untuk %s sudah melewati jadwal yang dianjurkan, tetapi masih dapat dikejar.%s",
				notifTeksItem(telat), nama, saran))
		return
	}

	besok := hari.AddDate(0, 0, 1)
	for ji := range jadwal {
		j := &jadwal[ji]
		if !tglSaja(j.Tanggal).Equal(besok) {
			continue
		}
		if s.repo.JumlahKunci(awalan+"h1:") >= maksPengingatH1 {
			return
		}
		mulai, ok := s.waktuMulai(j)
		if !ok {
			return
		}
		jid := j.ID
		s.kirimOrtu(a, models.NotifImunisasiTerlambat, awalan+"h1:"+j.ID.String(), "jadwal_posyandu", &jid,
			"Besok: Kejar Imunisasi "+nama,
			fmt.Sprintf("Posyandu %s dilaksanakan besok, %s%s. Imunisasi %s untuk %s sudah terlambat, mohon datang agar dapat segera diberikan.",
				notifNamaPosyandu(j.Posyandu), s.teksWaktu(mulai), notifLokasi(j), notifTeksItem(telat), nama))
		return
	}
}

// cekJadwalBelumAda: ke sekretaris dan bidan bila ada kebutuhan dalam 7 hari tetapi
// belum ada jadwal posyandu dalam 30 hari ke depan (sekali per minggu).
func (s *NotifikasiService) cekJadwalBelumAda(pos string, anak []models.Anak, d *notifDataAnak,
	hari time.Time, jadwal []models.JadwalPosyandu) {
	if len(jadwal) > 0 && !tglSaja(jadwal[0].Tanggal).After(hari.AddDate(0, 0, 30)) {
		return
	}
	cek := hari.AddDate(0, 0, 7)
	var nImun, nTelat, nVit int
	for i := range anak {
		a := &anak[i]
		pada, _ := hitungJadwal(a, d.master, d.riwayat[a.ID], cek)
		punya, telat := false, false
		for k := range pada {
			it := &pada[k]
			if it.Opsional || it.JenisVaksin.Kode == kodeHB0 || !notifPerluDiberi(it.Status) {
				continue
			}
			ideal, err := time.Parse(vaksinTglLayout, it.TanggalJadwal)
			if err != nil || ideal.After(cek) {
				continue
			}
			punya = true
			if it.Status == StatusVaksinTerlambat {
				telat = true
			}
		}
		if punya {
			nImun++
		}
		if telat {
			nTelat++
		}
		for _, s := range s.rencanaSuplemen(a, d, cek) {
			if s.Jenis == rencanaVitaminA {
				nVit++
			}
		}
	}
	if nImun+nVit == 0 {
		return
	}
	users, err := s.repo.Penerima(pos, []string{string(models.RoleSekretaris), string(models.RoleBidan)})
	if err != nil || len(users) == 0 {
		return
	}
	bagian := []string{}
	if nImun > 0 {
		t := fmt.Sprintf("%d balita memiliki imunisasi yang jatuh tempo dalam 7 hari", nImun)
		if nTelat > 0 {
			t += fmt.Sprintf(" (%d di antaranya terlambat)", nTelat)
		}
		bagian = append(bagian, t)
	}
	if nVit > 0 {
		bagian = append(bagian, fmt.Sprintf("%d balita belum menerima Vitamin A bulan %s", nVit, notifNamaBulan[cek.Month()-1]))
	}
	ringkas := notifGabungKata(bagian)
	tahun, minggu := hari.ISOWeek()
	kunci := fmt.Sprintf("%s:%s:%d-%02d", models.NotifJadwalBelumAda, pos, tahun, minggu)
	namaPos := notifNamaPosyandu(pos)
	s.kirimKeUser(users, models.NotifJadwalBelumAda, kunci, "", nil, nil,
		func(role models.Role) (string, string) {
			judul := "Jadwal Posyandu Berikutnya Belum Dibuat"
			if role == models.RoleSekretaris {
				return judul, fmt.Sprintf("Posyandu %s belum memiliki jadwal dalam 30 hari ke depan, sementara %s. Segera buat jadwal posyandu agar pelayanan tidak terlambat.", namaPos, ringkas)
			}
			return judul, fmt.Sprintf("Posyandu %s belum memiliki jadwal dalam 30 hari ke depan, sementara %s. Mohon koordinasikan dengan sekretaris untuk membuat jadwal.", namaPos, ringkas)
		})
}

// ---------------------------------------------------------------- laporan reaksi imunisasi (KIPI)

// LaporanKipi: orang tua melaporkan reaksi setelah imunisasi; dikirim hanya ke bidan posyandu anak.
func (s *NotifikasiService) LaporanKipi(anak *models.Anak, m *models.ImunisasiAnak, pengirim uint) {
	defer s.pulih("laporan KIPI")
	if anak == nil || m == nil {
		return
	}
	pos, err := s.repo.PosyanduAnak(anak.ID)
	if err != nil || pos == "" {
		return
	}
	bidan, err := s.repo.Penerima(pos, []string{string(models.RoleBidan)})
	if err != nil || len(bidan) == 0 {
		return
	}
	vaksin := "imunisasi"
	if m.JenisVaksin != nil && m.JenisVaksin.Nama != "" {
		vaksin = m.JenisVaksin.Nama
		if m.JenisVaksin.JumlahDosis > 1 {
			vaksin += fmt.Sprintf(" dosis ke-%d", m.DosisKe)
		}
	}
	h := fnv.New32a()
	h.Write([]byte(m.ReaksiKipi))
	kunci := fmt.Sprintf("%s:%s:%08x", models.NotifLaporanKipi, m.ID, h.Sum32())
	aid := anak.ID
	nama := strings.TrimSpace(anak.Nama)
	isi := fmt.Sprintf("Orang tua %s melaporkan reaksi setelah %s (%s): %s. Mohon segera dihubungi dan ditindaklanjuti.",
		nama, vaksin, notifTglIndo(tglSaja(m.TanggalPemberian)), m.ReaksiKipi)
	s.kirimKeUser(bidan, models.NotifLaporanKipi, kunci, "anak", &aid, &pengirim,
		func(models.Role) (string, string) { return "Laporan Reaksi Imunisasi: " + nama, isi })
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