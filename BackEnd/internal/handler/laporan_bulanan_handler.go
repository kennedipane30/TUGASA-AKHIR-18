package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type LaporanBulananHandler struct{ svc *service.LaporanBulananService }

func NewLaporanBulananHandler(svc *service.LaporanBulananService) *LaporanBulananHandler {
	return &LaporanBulananHandler{svc}
}

// GET /sekretaris/laporan-bulanan?bulan=YYYY-MM
// GET /bidan/laporan-bulanan?bulan=YYYY-MM
func (h *LaporanBulananHandler) Laporan(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.Laporan(pos, c.Query("bulan"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}