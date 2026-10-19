package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type JadwalHandler struct{ svc *service.JadwalService }

func NewJadwalHandler(s *service.JadwalService) *JadwalHandler { return &JadwalHandler{s} }

// idParam membaca parameter UUID dari URL.
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

// POST /sekretaris/jadwal  (jadwal otomatis milik posyandu sekretaris)
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

// GET /sekretaris/jadwal/:id/qr  dan  GET /kader/jadwal/:id/qr
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
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"jadwal_id": id, "kode_qr": kode}})
}

// ---------------------------------------------------------------- semua role

// GET /jadwal  (hanya jadwal di posyandu akun)
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

// GET /jadwal/terdekat  (data bernilai null jika belum ada jadwal di posyandu akun)
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

// POST /jadwal/:id/daftar   body: {"anak_id": "..."}   -> kartu antrean
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

// POST /jadwal/:id/batal   body: {"anak_id": "..."}   -> kartu antrean
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

// POST /jadwal/:id/scan   body: {"anak_id": "...", "kode_qr": "..."}   -> check-in oleh orang tua
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

// GET /jadwal/:id/kartu?anak_id=...
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

// ---------------------------------------------------------------- kader (cadangan)

// GET /kader/anak?cari=...   (hanya anak di posyandu kader)
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

// POST /kader/jadwal/:id/walkin   body: {"anak_id": "..."}
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

// POST /kader/pendaftaran/:id/checkin
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