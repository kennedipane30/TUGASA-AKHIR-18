package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// GET /sekretaris/riwayat/jadwal
func (h *PelayananHandler) SekretarisRiwayatJadwal(c *gin.Context) {
	list, err := h.svc.RiwayatJadwal(c.GetString("posyandu"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// GET /sekretaris/riwayat/jadwal/:id/anak
func (h *PelayananHandler) SekretarisRiwayatAnak(c *gin.Context) {
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

// GET /sekretaris/riwayat/pendaftaran/:id
func (h *PelayananHandler) SekretarisRiwayatDetail(c *gin.Context) {
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