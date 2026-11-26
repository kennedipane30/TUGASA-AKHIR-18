package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// GET /kader/daftar-anak?cari=  (nama anak / nama orang tua)
func (h *JadwalHandler) CariAnakSesi(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	res, err := h.svc.CariAnakSesi(pos, c.Query("cari"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": res})
}

// POST /kader/daftar-anak/:anak_id  (daftarkan ke sesi hari ini + check-in)
func (h *JadwalHandler) DaftarkanAnak(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	anakID, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	res, err := h.svc.DaftarkanAnak(c.GetUint("user_id"), pos, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": res})
}