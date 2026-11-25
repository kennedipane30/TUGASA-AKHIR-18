package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// POST /bidan/vaksin/anak/:anak_id/riwayat-awal
// Bidan mencatat riwayat vaksin anak sebelum posyandu (kunjungan pertama).
// Body: {status: sudah|belum_pernah, items: [...], mandiri: [...]}
func (h *VaksinHandler) CatatRiwayatAwal(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	anakID, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	var in service.RiwayatAwalBidanInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data riwayat vaksin belum lengkap"})
		return
	}
	data, err := h.svc.CatatRiwayatAwal(c.GetUint("user_id"), pos, anakID, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// DELETE /bidan/vaksin/mandiri/:id : hapus catatan vaksin di luar program yang salah.
func (h *VaksinHandler) HapusVaksinMandiri(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	if err := h.svc.HapusVaksinMandiri(c.GetUint("user_id"), pos, id); err != nil {
		if errors.Is(err, service.ErrVaksinMandiriTidakAda) {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "catatan vaksin mandiri dihapus"})
}