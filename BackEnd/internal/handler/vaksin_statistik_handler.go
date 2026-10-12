package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type VaksinStatistikHandler struct{ svc *service.VaksinStatistikService }

func NewVaksinStatistikHandler(svc *service.VaksinStatistikService) *VaksinStatistikHandler {
	return &VaksinStatistikHandler{svc}
}

// GET /admin/vaksin/statistik?posyandu=   (kosong = semua posyandu)
func (h *VaksinStatistikHandler) Statistik(c *gin.Context) {
	pos, ok := scopePosyandu(c)
	if !ok {
		return
	}
	data, err := h.svc.Statistik(pos)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "terjadi kesalahan pada server"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}