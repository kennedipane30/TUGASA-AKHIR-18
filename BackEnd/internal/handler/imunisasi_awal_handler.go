package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// POST /bidan/imunisasi/anak/:anak_id/riwayat-awal
// Bidan mencatat riwayat imunisasi anak sebelum posyandu (kunjungan pertama).
// Body: {status: sudah|belum_pernah, items: [...], mandiri: [...]}
func (h *ImunisasiHandler) CatatRiwayatAwal(c *gin.Context) {
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
		c.JSON(http.StatusBadRequest, gin.H{"error": "data riwayat imunisasi belum lengkap"})
		return
	}
	data, err := h.svc.CatatRiwayatAwal(c.GetUint("user_id"), pos, anakID, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// DELETE /bidan/imunisasi/mandiri/:id : hapus catatan imunisasi di luar program yang salah.
func (h *ImunisasiHandler) HapusImunisasiMandiri(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	if err := h.svc.HapusImunisasiMandiri(c.GetUint("user_id"), pos, id); err != nil {
		if errors.Is(err, service.ErrImunisasiMandiriTidakAda) {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "catatan imunisasi mandiri dihapus"})
}