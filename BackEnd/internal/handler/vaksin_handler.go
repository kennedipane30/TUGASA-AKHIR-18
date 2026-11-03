package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
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

// ---------------------------------------------------------------- bidan

// POST /bidan/vaksin/riwayat : catat vaksin yang diberikan di luar sesi posyandu.
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

// DELETE /bidan/vaksin/riwayat/:id : hapus riwayat susulan yang salah input.
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