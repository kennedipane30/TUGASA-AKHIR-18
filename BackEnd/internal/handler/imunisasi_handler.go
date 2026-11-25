package handler

import (
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type ImunisasiHandler struct{ svc *service.ImunisasiService }

func NewImunisasiHandler(svc *service.ImunisasiService) *ImunisasiHandler { return &ImunisasiHandler{svc} }

func (h *ImunisasiHandler) gagal(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrAnakTidakAda):
		c.JSON(http.StatusNotFound, gin.H{"error": "anak tidak ditemukan"})
	case errors.Is(err, service.ErrRiwayatImunisasiTidakAda):
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
	default:
		tulisError(c, err)
	}
}

// ---------------------------------------------------------------- semua role

// GET /imunisasi/jadwal : jadwal imunisasi rutin (master, berlaku untuk semua anak).
func (h *ImunisasiHandler) JadwalMaster(c *gin.Context) {
	data, err := h.svc.ListJadwalMaster()
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /imunisasi/anak/:anak_id : kartu imunisasi anak (jadwal + status, riwayat imunisasi, suplemen).
// Bidan, kader, sekretaris: anak di posyandunya. Orang tua: anak di keluarganya.
func (h *ImunisasiHandler) KartuAnak(c *gin.Context) {
	anakID, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	data, err := h.svc.KartuAnak(anakID, c.GetUint("user_id"), c.GetString("role"), c.GetString("posyandu"))
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// ---------------------------------------------------------------- foto bukti imunisasi

const maksUkuranBukti = 3 << 20 // 3 MB

// POST /imunisasi/bukti (multipart, field "file") : unggah foto bukti imunisasi dari luar (orang tua, bidan).
func (h *ImunisasiHandler) UnggahBukti(c *gin.Context) {
	role := c.GetString("role")
	if role != "orang_tua" && role != "bidan" {
		c.JSON(http.StatusForbidden, gin.H{"error": "akses ditolak"})
		return
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maksUkuranBukti+(1<<20))
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "pilih foto bukti terlebih dahulu (maksimal 3 MB)"})
		return
	}
	if file.Size > maksUkuranBukti {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ukuran foto maksimal 3 MB"})
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	if ext == ".jpeg" {
		ext = ".jpg"
	}
	if ext != ".jpg" && ext != ".png" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "foto harus berformat JPG atau PNG"})
		return
	}
	f, err := file.Open()
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "foto tidak dapat dibaca"})
		return
	}
	kepala := make([]byte, 512)
	n, _ := f.Read(kepala)
	f.Close()
	jenis := http.DetectContentType(kepala[:n])
	if jenis != "image/jpeg" && jenis != "image/png" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file bukan foto JPG atau PNG"})
		return
	}
	if err := os.MkdirAll(service.FolderBukti, 0o750); err != nil {
		tulisError(c, err)
		return
	}
	nama := uuid.NewString() + ext
	if err := c.SaveUploadedFile(file, filepath.Join(service.FolderBukti, nama)); err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": gin.H{"nama": nama}})
}

// GET /imunisasi/bukti/:nama : tampilkan foto bukti (hanya pengguna yang login).
func (h *ImunisasiHandler) AmbilBukti(c *gin.Context) {
	nama := c.Param("nama")
	if !service.NamaBuktiValid(nama) {
		c.JSON(http.StatusNotFound, gin.H{"error": "foto tidak ditemukan"})
		return
	}
	path := filepath.Join(service.FolderBukti, nama)
	if _, err := os.Stat(path); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "foto tidak ditemukan"})
		return
	}
	c.Header("Cache-Control", "private, max-age=86400")
	c.File(path)
}

// ---------------------------------------------------------------- orang tua

// POST /imunisasi/riwayat/:id/kipi : orang tua melaporkan reaksi setelah imunisasi.
func (h *ImunisasiHandler) LaporKipi(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.LaporKipiInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ceritakan reaksi yang dialami anak"})
		return
	}
	data, err := h.svc.LaporKipi(c.GetUint("user_id"), id, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// ---------------------------------------------------------------- bidan

// POST /bidan/imunisasi/riwayat : catat imunisasi yang diberikan di luar posyandu.
func (h *ImunisasiHandler) CatatRiwayat(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	var in service.CatatRiwayatInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data imunisasi belum lengkap atau tidak valid"})
		return
	}
	data, err := h.svc.CatatRiwayat(c.GetUint("user_id"), pos, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": data})
}

// DELETE /bidan/imunisasi/riwayat/:id : batalkan catatan imunisasi dari luar / laporan orang tua.
func (h *ImunisasiHandler) HapusRiwayat(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	if err := h.svc.HapusRiwayat(c.GetUint("user_id"), pos, id); err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "riwayat imunisasi dihapus"})
}

// PUT /bidan/imunisasi/riwayat/:id/konfirmasi : benarkan (dan perbaiki) laporan imunisasi orang tua.
func (h *ImunisasiHandler) KonfirmasiRiwayat(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.KonfirmasiRiwayatInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data konfirmasi tidak valid"})
		return
	}
	data, err := h.svc.KonfirmasiRiwayat(c.GetUint("user_id"), pos, id, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// POST /bidan/imunisasi/anak/:anak_id/konfirmasi-selesai : riwayat imunisasi anak sudah benar.
func (h *ImunisasiHandler) SelesaiKonfirmasi(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	anakID, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	data, err := h.svc.SelesaiKonfirmasi(c.GetUint("user_id"), pos, anakID)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// PUT /bidan/imunisasi/riwayat/:id/kipi : catat tindak lanjut reaksi setelah imunisasi.
func (h *ImunisasiHandler) TindakLanjutKipi(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.TindakLanjutKipiInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "tindak lanjut wajib diisi"})
		return
	}
	data, err := h.svc.TindakLanjutKipi(c.GetUint("user_id"), pos, id, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// ---------------------------------------------------------------- sekretaris

// GET /sekretaris/imunisasi/statistik : rekap imunisasi posyandu sekretaris.
func (h *ImunisasiHandler) Statistik(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.Statistik(pos)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}