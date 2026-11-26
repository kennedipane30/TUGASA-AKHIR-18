package handler

// Endpoint pendataan kader: antrean balita yang sudah check-in, serta pencatatan
// dan pembacaan pengukuran balita.

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// GET /kader/jadwal/:id/antrean
func (h *PelayananHandler) AntreanKader(c *gin.Context) {
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
	m, err := h.svc.CatatPengukuran(c.GetUint("user_id"), c.GetString("posyandu"), id, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": m})
}

// GET /kader/pendaftaran/:id/pengukuran
func (h *PelayananHandler) PengukuranKader(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	m, err := h.svc.PengukuranKader(c.GetString("posyandu"), id)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": m})
}