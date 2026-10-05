package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type PelayananHandler struct{ svc *service.PelayananService }

func NewPelayananHandler(s *service.PelayananService) *PelayananHandler { return &PelayananHandler{s} }

// ---------------------------------------------------------------- kader

// GET /kader/jadwal/:id/antrean
func (h *PelayananHandler) AntreanKader(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	list, err := h.svc.AntreanKader(id)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// PUT /kader/pendaftaran/:id/pengukuran
func (h *PelayananHandler) CatatPengukuran(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.PengukuranInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	m, err := h.svc.CatatPengukuran(c.GetUint("user_id"), id, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": m})
}

// ---------------------------------------------------------------- bidan

// GET /bidan/jadwal/:id/pengukuran
func (h *PelayananHandler) AntreanBidan(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	list, err := h.svc.AntreanBidan(id)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// GET /bidan/pendaftaran/:id
func (h *PelayananHandler) DetailBidan(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	d, err := h.svc.DetailBidan(id)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": d})
}

// PUT /bidan/pendaftaran/:id/catatan
func (h *PelayananHandler) SimpanCatatan(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.CatatanBidanInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	d, err := h.svc.SimpanCatatan(c.GetUint("user_id"), id, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": d})
}

// GET /vaksin  (daftar jenis vaksin untuk pilihan bidan)
func (h *PelayananHandler) ListVaksin(c *gin.Context) {
	list, err := h.svc.ListVaksin()
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// ---------------------------------------------------------------- orang tua

// GET /riwayat?anak_id=...   (hanya kunjungan yang sudah diberi catatan bidan)
func (h *PelayananHandler) Riwayat(c *gin.Context) {
	var anakID *uuid.UUID
	if s := c.Query("anak_id"); s != "" {
		id, err := uuid.Parse(s)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "anak_id tidak valid"})
			return
		}
		anakID = &id
	}
	list, err := h.svc.Riwayat(c.GetUint("user_id"), anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}
