package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// GET /bidan/riwayat/jadwal
func (h *PelayananHandler) BidanRiwayatJadwal(c *gin.Context) {
	list, err := h.svc.RiwayatJadwal(c.GetString("posyandu"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// GET /bidan/riwayat/jadwal/:id/anak
func (h *PelayananHandler) BidanRiwayatAnak(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	list, err := h.svc.AntreanBidan(id, c.GetString("posyandu"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// GET /bidan/riwayat/pendaftaran/:id
func (h *PelayananHandler) BidanRiwayatDetail(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	d, err := h.svc.DetailBidan(c.GetString("posyandu"), id)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": d})
}