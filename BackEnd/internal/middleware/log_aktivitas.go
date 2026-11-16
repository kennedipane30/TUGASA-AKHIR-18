package middleware

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"regexp"
	"strings"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/gin-gonic/gin"
)

// ---------------------------------------------------------------------------
// LOG AKTIVITAS OTOMATIS
// Dipasang sekali pada grup /api/v1. Setiap permintaan yang MENGUBAH data
// (POST, PUT, PATCH, DELETE) dan BERHASIL dicatat: siapa, melakukan apa, kapan.
// Permintaan membaca data (GET) tidak dicatat. Isi permintaan (PIN, data
// kesehatan) tidak pernah disimpan.
// ---------------------------------------------------------------------------

type infoAksi struct {
	aksi  string
	modul string
}

// Kunci: METODE + jalur tanpa /api/v1; semua parameter ditulis :id.
var petaAksi = map[string]infoAksi{
	// akun (semua role)
	"POST /auth/login":        {"Masuk ke aplikasi", "Akun"},
	"POST /auth/register":     {"Mendaftar akun baru", "Akun"},
	"POST /auth/ubah-pin":     {"Mengganti PIN", "Akun"},
	"DELETE /perangkat/token": {"Keluar dari aplikasi", "Akun"},

	// sekretaris: akun petugas
	"POST /sekretaris/users":               {"Membuat akun", "Akun"},
	"PUT /sekretaris/users/:id":            {"Mengubah data akun", "Akun"},
	"PATCH /sekretaris/users/:id/aktif":    {"Mengubah status aktif akun", "Akun"},
	"DELETE /sekretaris/users/:id":         {"Menghapus akun", "Akun"},
	"POST /sekretaris/users/:id/reset-pin": {"Mereset PIN akun", "Akun"},

	// sekretaris: jadwal
	"POST /sekretaris/jadwal":              {"Membuat jadwal posyandu", "Jadwal"},
	"PUT /sekretaris/jadwal/:id":           {"Mengubah jadwal posyandu", "Jadwal"},
	"DELETE /sekretaris/jadwal/:id":        {"Menghapus jadwal posyandu", "Jadwal"},
	"POST /sekretaris/jadwal/:id/batalkan": {"Membatalkan jadwal posyandu", "Jadwal"},

	// orang tua
	"PUT /keluarga/saya":             {"Memperbarui data keluarga", "Keluarga"},
	"PUT /keluarga":                  {"Memperbarui data keluarga", "Keluarga"},
	"POST /keluarga/saya/anak":       {"Menambah data anak", "Keluarga"},
	"POST /keluarga/anak":            {"Menambah data anak", "Keluarga"},
	"PUT /keluarga/saya/anak/:id":    {"Mengubah data anak", "Keluarga"},
	"PUT /keluarga/anak/:id":         {"Mengubah data anak", "Keluarga"},
	"DELETE /keluarga/saya/anak/:id": {"Menghapus data anak", "Keluarga"},
	"DELETE /keluarga/anak/:id":      {"Menghapus data anak", "Keluarga"},
	"POST /jadwal/:id/daftar":        {"Mendaftar ke jadwal posyandu", "Pendaftaran"},
	"POST /jadwal/:id/batal":         {"Membatalkan pendaftaran", "Pendaftaran"},
	"POST /jadwal/:id/scan":          {"Check-in dengan scan QR", "Pendaftaran"},

	// kader
	"POST /kader/users/:id/reset-pin":       {"Mereset PIN orang tua", "Akun"},
	"POST /kader/jadwal/:id/walkin":         {"Mendaftarkan anak di posyandu", "Pendaftaran"},
	"POST /kader/daftar-anak/:id":           {"Mendaftarkan anak di posyandu", "Pendaftaran"},
	"POST /kader/pendaftaran/:id/checkin":   {"Check-in manual", "Pendaftaran"},
	"PUT /kader/pendaftaran/:id/pengukuran": {"Mencatat hasil pengukuran", "Pendataan"},
	"POST /kader/keluarga":                  {"Menambahkan akun keluarga", "Keluarga"},
	"PUT /kader/keluarga/:id":               {"Mengubah data keluarga", "Keluarga"},
	"POST /kader/keluarga/:id/anak":         {"Menambah data anak", "Keluarga"},
	"PUT /kader/keluarga/:id/anak/:id":      {"Mengubah data anak", "Keluarga"},

	// bidan
	"PUT /bidan/pendaftaran/:id/catatan": {"Menyimpan catatan pemeriksaan", "Pemeriksaan"},
	"POST /bidan/vaksin/riwayat":         {"Mencatat vaksin dari luar posyandu", "Imunisasi"},
	"DELETE /bidan/vaksin/riwayat/:id":   {"Membatalkan catatan vaksin", "Imunisasi"},
}

// Perubahan kecil yang tidak perlu dicatat.
var abaikanAksi = map[string]bool{
	"POST /notifikasi/baca-semua": true,
	"PATCH /notifikasi/:id/baca":  true,
	"DELETE /notifikasi/:id":      true,
	"POST /perangkat/token":       true,
}

var polaParam = regexp.MustCompile(`:[A-Za-z_]+`)

// Penampung isi jawaban (hanya untuk login & daftar, untuk mengetahui id akun).
type perekamJawaban struct {
	gin.ResponseWriter
	buf *bytes.Buffer
}

func (w *perekamJawaban) Write(b []byte) (int, error) {
	w.buf.Write(b)
	return w.ResponseWriter.Write(b)
}

func (w *perekamJawaban) WriteString(s string) (int, error) {
	w.buf.WriteString(s)
	return w.ResponseWriter.WriteString(s)
}

// CatatLogAktivitas mencatat aktivitas yang mengubah data setelah berhasil.
func CatatLogAktivitas(repo *repository.LogAktivitasRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		metode := c.Request.Method
		if metode == http.MethodGet || metode == http.MethodHead || metode == http.MethodOptions {
			c.Next()
			return
		}
		jalur := c.FullPath()
		if jalur == "" {
			c.Next()
			return
		}
		kunci := metode + " " + polaParam.ReplaceAllString(strings.TrimPrefix(jalur, "/api/v1"), ":id")
		if abaikanAksi[kunci] {
			c.Next()
			return
		}

		var rekam *bytes.Buffer
		if kunci == "POST /auth/login" || kunci == "POST /auth/register" {
			rekam = &bytes.Buffer{}
			c.Writer = &perekamJawaban{ResponseWriter: c.Writer, buf: rekam}
		}

		c.Next()

		if c.Writer.Status() >= 400 || len(c.Errors) > 0 {
			return
		}

		userID := c.GetUint("user_id")
		if userID == 0 && rekam != nil {
			userID = cariUserID(rekam.Bytes())
		}
		if userID == 0 {
			return
		}

		info, ada := petaAksi[kunci]
		if !ada {
			info = tebakAksi(metode, kunci)
		}

		objek := ""
		if n := len(c.Params); n > 0 {
			objek = c.Params[n-1].Value
		}

		catatan := models.LogAktivitas{
			UserID:  userID,
			Aksi:    info.aksi,
			Modul:   info.modul,
			ObjekID: objek,
			Metode:  metode,
			Jalur:   jalur,
			IP:      c.ClientIP(),
		}

		// Disimpan di latar belakang agar tidak memperlambat jawaban ke aplikasi.
		go func(a models.LogAktivitas) {
			p, err := repo.Pemilik(a.UserID)
			if err != nil || p.Posyandu == "" {
				return
			}
			a.NamaUser = p.Nama
			a.Role = p.Role
			a.Posyandu = p.Posyandu
			if err := repo.Simpan(&a); err != nil {
				log.Printf("log aktivitas: gagal menyimpan: %v", err)
			}
		}(catatan)
	}
}

// tebakAksi: keterangan umum untuk perubahan yang belum ada di petaAksi.
func tebakAksi(metode, kunci string) infoAksi {
	modul := "Lainnya"
	switch {
	case strings.Contains(kunci, "/vaksin"):
		modul = "Imunisasi"
	case strings.Contains(kunci, "/jadwal"):
		modul = "Jadwal"
	case strings.Contains(kunci, "/keluarga"):
		modul = "Keluarga"
	case strings.Contains(kunci, "/users"):
		modul = "Akun"
	case strings.Contains(kunci, "/pendaftaran"):
		modul = "Pendataan"
	}
	switch metode {
	case http.MethodPost:
		return infoAksi{"Menambah data " + strings.ToLower(modul), modul}
	case http.MethodDelete:
		return infoAksi{"Menghapus data " + strings.ToLower(modul), modul}
	default:
		return infoAksi{"Mengubah data " + strings.ToLower(modul), modul}
	}
}

// cariUserID mencari {"user": {"id": ...}} di jawaban login / daftar.
func cariUserID(isi []byte) uint {
	var v any
	if err := json.Unmarshal(isi, &v); err != nil {
		return 0
	}
	return cariID(v, 0)
}

func cariID(v any, dalam int) uint {
	m, ok := v.(map[string]any)
	if !ok || dalam > 3 {
		return 0
	}
	if u, ok := m["user"].(map[string]any); ok {
		if id, ok := u["id"].(float64); ok && id > 0 {
			return uint(id)
		}
	}
	for _, isi := range m {
		if id := cariID(isi, dalam+1); id > 0 {
			return id
		}
	}
	return 0
}