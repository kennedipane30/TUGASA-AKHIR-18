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

type VaksinHandler struct{ svc *service.VaksinService }

func NewVaksinHandler(svc *service.VaksinService) *VaksinHandler { return &VaksinHandler{svc} }

func (h *VaksinHandler) gagal(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrAnakTidakAda):
		c.JSON(http.StatusNotFound, gin.H{"error": "anak tidak ditemukan"})
	case errors.Is(err, service.ErrRiwayatVaksinTidakAda):
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
	default:
		tulisError(c, err)
	}
}

// ---------------------------------------------------------------- semua role

// GET /vaksin/jadwal : jadwal imunisasi rutin (master, berlaku untuk semua anak).
func (h *VaksinHandler) JadwalMaster(c *gin.Context) {
	data, err := h.svc.ListJadwalMaster()
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /vaksin/anak/:anak_id : kartu vaksin anak (jadwal + status, riwayat vaksin, suplemen).
// Bidan, kader, sekretaris: anak di posyandunya. Orang tua: anak di keluarganya.
func (h *VaksinHandler) KartuAnak(c *gin.Context) {
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

// ---------------------------------------------------------------- foto bukti vaksin

const maksUkuranBukti = 3 << 20 // 3 MB

// POST /vaksin/bukti (multipart, field "file") : unggah foto bukti vaksin dari luar (orang tua, bidan).
func (h *VaksinHandler) UnggahBukti(c *gin.Context) {
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

// GET /vaksin/bukti/:nama : tampilkan foto bukti (hanya pengguna yang login).
func (h *VaksinHandler) AmbilBukti(c *gin.Context) {
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

// POST /vaksin/anak/:anak_id/riwayat-awal : riwayat vaksin anak sebelum ke posyandu.
func (h *VaksinHandler) LaporRiwayatAwal(c *gin.Context) {
	anakID, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	var in service.RiwayatAwalInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data riwayat vaksin belum lengkap"})
		return
	}
	data, err := h.svc.LaporRiwayatAwal(c.GetUint("user_id"), anakID, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// POST /vaksin/riwayat/:id/kipi : orang tua melaporkan reaksi setelah imunisasi.
func (h *VaksinHandler) LaporKipi(c *gin.Context) {
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

// POST /bidan/vaksin/riwayat : catat vaksin yang diberikan di luar posyandu.
func (h *VaksinHandler) CatatRiwayat(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	var in service.CatatRiwayatInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data vaksin belum lengkap atau tidak valid"})
		return
	}
	data, err := h.svc.CatatRiwayat(c.GetUint("user_id"), pos, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": data})
}

// DELETE /bidan/vaksin/riwayat/:id : batalkan catatan vaksin dari luar / laporan orang tua.
func (h *VaksinHandler) HapusRiwayat(c *gin.Context) {
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
	c.JSON(http.StatusOK, gin.H{"message": "riwayat vaksin dihapus"})
}

// PUT /bidan/vaksin/riwayat/:id/konfirmasi : benarkan (dan perbaiki) laporan vaksin orang tua.
func (h *VaksinHandler) KonfirmasiRiwayat(c *gin.Context) {
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

// POST /bidan/vaksin/anak/:anak_id/konfirmasi-selesai : riwayat vaksin anak sudah benar.
func (h *VaksinHandler) SelesaiKonfirmasi(c *gin.Context) {
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

// PUT /bidan/vaksin/riwayat/:id/kipi : catat tindak lanjut reaksi setelah imunisasi.
func (h *VaksinHandler) TindakLanjutKipi(c *gin.Context) {
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

// GET /sekretaris/vaksin/statistik : rekap imunisasi posyandu sekretaris.
func (h *VaksinHandler) Statistik(c *gin.Context) {
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