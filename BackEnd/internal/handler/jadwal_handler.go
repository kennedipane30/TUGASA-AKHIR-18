package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type JadwalHandler struct{ svc *service.JadwalService }

func NewJadwalHandler(s *service.JadwalService) *JadwalHandler { return &JadwalHandler{s} }

func idParam(c *gin.Context, nama string) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param(nama))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": nama + " tidak valid"})
		return uuid.Nil, false
	}
	return id, true
}

type bodyAnak struct {
	AnakID string `json:"anak_id" binding:"required"`
}

func bacaAnakID(c *gin.Context) (uuid.UUID, bool) {
	var in bodyAnak
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return uuid.Nil, false
	}
	id, err := uuid.Parse(in.AnakID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "anak_id tidak valid"})
		return uuid.Nil, false
	}
	return id, true
}

// ---------------------------------------------------------------- sekretaris

// POST /sekretaris/jadwal
func (h *JadwalHandler) Buat(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	var in service.JadwalInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	j, err := h.svc.Buat(c.GetUint("user_id"), pos, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": j})
}

// PUT /sekretaris/jadwal/:id
func (h *JadwalHandler) Ubah(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.JadwalInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	j, err := h.svc.Ubah(id, pos, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": j})
}

// POST /sekretaris/jadwal/:id/batalkan
func (h *JadwalHandler) Batalkan(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in struct {
		Alasan string `json:"alasan"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	j, err := h.svc.Batalkan(id, pos, in.Alasan)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": j})
}

// GET /sekretaris/jadwal/riwayat
func (h *JadwalHandler) Riwayat(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	list, err := h.svc.Riwayat(pos)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// DELETE /sekretaris/jadwal/:id
func (h *JadwalHandler) Hapus(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	if err := h.svc.Hapus(id, pos); err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "jadwal dihapus"})
}

// GET /sekretaris/qr  dan  GET /kader/qr  (QR tetap, satu per posyandu)
func (h *JadwalHandler) QRPosyandu(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	kode, err := h.svc.QRPosyandu(pos)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"posyandu": pos, "kode_qr": kode}})
}

// GET /sekretaris/jadwal/:id/qr  dan  GET /kader/jadwal/:id/qr  (kompatibel, isi QR tetap sama)
func (h *JadwalHandler) QRJadwal(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	kode, err := h.svc.QRJadwal(id, pos)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"jadwal_id": id, "posyandu": pos, "kode_qr": kode}})
}

// ---------------------------------------------------------------- semua role

// GET /jadwal  (jadwal mendatang di posyandu akun)
func (h *JadwalHandler) List(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	list, err := h.svc.List(pos)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// GET /jadwal/terdekat
func (h *JadwalHandler) Terdekat(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	d, err := h.svc.Terdekat(c.GetUint("user_id"), c.GetString("role"), pos)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": d})
}

// ---------------------------------------------------------------- orang tua

func (h *JadwalHandler) Daftar(c *gin.Context) {
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	anakID, ok := bacaAnakID(c)
	if !ok {
		return
	}
	k, err := h.svc.Daftar(c.GetUint("user_id"), jadwalID, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": k})
}

func (h *JadwalHandler) BatalDaftar(c *gin.Context) {
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	anakID, ok := bacaAnakID(c)
	if !ok {
		return
	}
	k, err := h.svc.BatalDaftar(c.GetUint("user_id"), jadwalID, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": k})
}

func (h *JadwalHandler) Scan(c *gin.Context) {
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in struct {
		AnakID string `json:"anak_id" binding:"required"`
		KodeQR string `json:"kode_qr" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "anak_id dan kode_qr wajib diisi"})
		return
	}
	anakID, err := uuid.Parse(in.AnakID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "anak_id tidak valid"})
		return
	}
	k, err := h.svc.ScanCheckin(c.GetUint("user_id"), jadwalID, anakID, in.KodeQR)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": k})
}

func (h *JadwalHandler) Kartu(c *gin.Context) {
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	anakID, err := uuid.Parse(c.Query("anak_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "anak_id tidak valid"})
		return
	}
	k, err := h.svc.KartuAntrean(c.GetUint("user_id"), jadwalID, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": k})
}

// ---------------------------------------------------------------- kader

func (h *JadwalHandler) CariAnak(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	list, err := h.svc.CariAnak(c.Query("cari"), pos)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

func (h *JadwalHandler) WalkIn(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	anakID, ok := bacaAnakID(c)
	if !ok {
		return
	}
	p, err := h.svc.WalkIn(c.GetUint("user_id"), pos, jadwalID, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": p})
}

func (h *JadwalHandler) CheckinManual(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	p, err := h.svc.CheckinManual(c.GetUint("user_id"), pos, id)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": p})
}