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

func (h *VaksinStatistikHandler) Statistik(c *gin.Context) {
	data, err := h.svc.Statistik()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "terjadi kesalahan pada server"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}