package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// GET /kader/riwayat/jadwal
func (h *PelayananHandler) KaderRiwayatJadwal(c *gin.Context) {
	list, err := h.svc.RiwayatJadwal(c.GetString("posyandu"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// GET /kader/riwayat/jadwal/:id/anak
func (h *PelayananHandler) KaderRiwayatAnak(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	list, err := h.svc.AntreanKader(id, c.GetString("posyandu"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// GET /kader/riwayat/pendaftaran/:id
func (h *PelayananHandler) KaderRiwayatDetail(c *gin.Context) {
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