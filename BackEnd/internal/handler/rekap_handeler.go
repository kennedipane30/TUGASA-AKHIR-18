package handler

import (
	"net/http"
	"strconv"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type RekapHandler struct{ svc *service.RekapService }

func NewRekapHandler(svc *service.RekapService) *RekapHandler { return &RekapHandler{svc} }

// GET /sekretaris/rekap/gizi?bulan=YYYY-MM
func (h *RekapHandler) Gizi(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.RekapGizi(pos, c.Query("bulan"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /sekretaris/rekap/suplemen?tahun=2026&periode=1|2
func (h *RekapHandler) Suplemen(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	tahun, _ := strconv.Atoi(c.Query("tahun"))
	periode, _ := strconv.Atoi(c.Query("periode"))
	data, err := h.svc.RekapSuplemen(pos, tahun, periode)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /sekretaris/rekap/tidak-hadir?bulan=YYYY-MM  dan  GET /kader/rekap/tidak-hadir?bulan=YYYY-MM
func (h *RekapHandler) TidakHadir(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.TidakHadir(pos, c.Query("bulan"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}