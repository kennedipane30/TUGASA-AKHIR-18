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

// ---------------------------------------------------------------- admin

// POST /admin/jadwal
func (h *JadwalHandler) Buat(c *gin.Context) {
	var in service.JadwalInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	j, err := h.svc.Buat(c.GetUint("user_id"), in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": j})
}

// PUT /admin/jadwal/:id
func (h *JadwalHandler) Ubah(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.JadwalInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	j, err := h.svc.Ubah(id, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": j})
}

// POST /admin/jadwal/:id/batalkan
func (h *JadwalHandler) Batalkan(c *gin.Context) {
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
	j, err := h.svc.Batalkan(id, in.Alasan)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": j})
}

// ---------------------------------------------------------------- semua role

// GET /jadwal
func (h *JadwalHandler) List(c *gin.Context) {
	list, err := h.svc.List()
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// GET /jadwal/terdekat  (data bernilai null jika belum ada jadwal)
func (h *JadwalHandler) Terdekat(c *gin.Context) {
	d, err := h.svc.Terdekat(c.GetUint("user_id"), c.GetString("role"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": d})
}

// ---------------------------------------------------------------- orang tua

// POST /jadwal/:id/daftar   body: {"anak_id": "..."}
func (h *JadwalHandler) Daftar(c *gin.Context) {
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	anakID, ok := bacaAnakID(c)
	if !ok {
		return
	}
	p, err := h.svc.Daftar(c.GetUint("user_id"), jadwalID, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": p})
}

// POST /jadwal/:id/batal   body: {"anak_id": "..."}
func (h *JadwalHandler) BatalDaftar(c *gin.Context) {
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	anakID, ok := bacaAnakID(c)
	if !ok {
		return
	}
	p, err := h.svc.BatalDaftar(c.GetUint("user_id"), jadwalID, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": p})
}

// POST /jadwal/:id/checkin   body: {"anak_id": "..."}
func (h *JadwalHandler) Checkin(c *gin.Context) {
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	anakID, ok := bacaAnakID(c)
	if !ok {
		return
	}
	p, err := h.svc.Checkin(c.GetUint("user_id"), jadwalID, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": p})
}

// ---------------------------------------------------------------- kader

// GET /kader/anak?cari=...
func (h *JadwalHandler) CariAnak(c *gin.Context) {
	list, err := h.svc.CariAnak(c.Query("cari"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// POST /kader/jadwal/:id/walkin   body: {"anak_id": "..."}
func (h *JadwalHandler) WalkIn(c *gin.Context) {
	jadwalID, ok := idParam(c, "id")
	if !ok {
		return
	}
	anakID, ok := bacaAnakID(c)
	if !ok {
		return
	}
	p, err := h.svc.WalkIn(c.GetUint("user_id"), jadwalID, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": p})
}

// POST /kader/pendaftaran/:id/checkin
func (h *JadwalHandler) CheckinManual(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	p, err := h.svc.CheckinManual(c.GetUint("user_id"), id)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": p})
}
