package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// GET /kader/daftar-balita?cari=  (nama balita / nama orang tua)
func (h *JadwalHandler) CariBalitaSesi(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	res, err := h.svc.CariBalitaSesi(pos, c.Query("cari"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": res})
}

// POST /kader/daftar-balita/:balita_id  (daftarkan ke sesi hari ini + check-in)
func (h *JadwalHandler) DaftarkanBalita(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	balitaID, ok := idParam(c, "balita_id")
	if !ok {
		return
	}
	res, err := h.svc.DaftarkanBalita(c.GetUint("user_id"), pos, balitaID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": res})
}