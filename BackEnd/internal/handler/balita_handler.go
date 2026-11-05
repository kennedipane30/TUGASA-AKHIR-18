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
func (h *BalitaHandler) Daftar(c *gin.Context) {
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
