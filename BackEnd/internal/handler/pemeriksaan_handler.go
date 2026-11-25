package handler

// Endpoint pemeriksaan bidan: antrean, detail satu kunjungan, penyimpanan
// catatan pemeriksaan, dan daftar jenis imunisasi untuk pilihan bidan.

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// GET /bidan/jadwal/:id/pengukuran
func (h *PelayananHandler) AntreanBidan(c *gin.Context) {
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

// GET /bidan/pendaftaran/:id
func (h *PelayananHandler) DetailBidan(c *gin.Context) {
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
	d, err := h.svc.SimpanCatatan(c.GetUint("user_id"), c.GetString("posyandu"), id, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": d})
}

// GET /imunisasi  (daftar jenis imunisasi untuk pilihan bidan)
func (h *PelayananHandler) ListJenisImunisasi(c *gin.Context) {
	list, err := h.svc.ListJenisImunisasi()
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}