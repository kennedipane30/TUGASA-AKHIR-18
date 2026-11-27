package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type AnakHandler struct{ svc *service.AnakService }

func NewAnakHandler(svc *service.AnakService) *AnakHandler { return &AnakHandler{svc} }

// GET /{sekretaris|kader|bidan}/semua-anak?cari=&semua=1
// Anak arsip tidak ditampilkan di sini; anak arsip dilihat orang tua di Data Anak.
func (h *AnakHandler) Daftar(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.Daftar(pos, c.Query("cari"), c.Query("semua") == "1")
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /{sekretaris|kader|bidan}/semua-anak/:anak_id
func (h *AnakHandler) Detail(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	data, err := h.svc.Detail(pos, id)
	if errors.Is(err, service.ErrAnakTidakAda) {
		c.JSON(http.StatusNotFound, gin.H{"error": "anak tidak ditemukan"})
		return
	}
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /bidan/anak-berisiko : daftar anak berisiko (deteksi dini) di posyandu bidan.
func (h *AnakHandler) Berisiko(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.Berisiko(pos)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}