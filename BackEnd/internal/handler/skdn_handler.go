package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type SkdnHandler struct{ svc *service.SkdnService }

func NewSkdnHandler(svc *service.SkdnService) *SkdnHandler { return &SkdnHandler{svc} }

// GET /sekretaris/skdn?bulan=YYYY-MM  dan  GET /bidan/skdn?bulan=YYYY-MM
func (h *SkdnHandler) Hitung(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.Hitung(pos, c.Query("bulan"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}