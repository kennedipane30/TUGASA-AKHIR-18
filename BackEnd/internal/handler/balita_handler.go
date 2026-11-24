package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type BalitaHandler struct{ svc *service.BalitaService }

func NewBalitaHandler(svc *service.BalitaService) *BalitaHandler { return &BalitaHandler{svc} }

// GET /{sekretaris|kader|bidan}/balita?cari=&semua=1
// GET /{sekretaris|kader|bidan}/balita?arsip=1 : hanya anak yang diarsipkan
func (h *BalitaHandler) Daftar(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	if c.Query("arsip") == "1" {
		data, err := h.svc.DaftarArsip(pos, c.Query("cari"))
		if err != nil {
			tulisError(c, err)
			return
		}
		c.JSON(http.StatusOK, gin.H{"data": data})
		return
	}
	data, err := h.svc.Daftar(pos, c.Query("cari"), c.Query("semua") == "1")
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /{sekretaris|kader|bidan}/balita/:anak_id
func (h *BalitaHandler) Detail(c *gin.Context) {
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

// GET /bidan/balita-berisiko : daftar anak berisiko (deteksi dini) di posyandu bidan.
func (h *BalitaHandler) Berisiko(c *gin.Context) {
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