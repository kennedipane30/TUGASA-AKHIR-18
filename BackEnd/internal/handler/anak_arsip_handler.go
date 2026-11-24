package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// AnakArsipHandler: kader mengarsipkan / mengaktifkan kembali data anak.
type AnakArsipHandler struct{ svc *service.AnakArsipService }

func NewAnakArsipHandler(s *service.AnakArsipService) *AnakArsipHandler {
	return &AnakArsipHandler{s}
}

// PUT /kader/balita/:anak_id/arsip
// Body: {alasan: pindah|meninggal|lainnya, tanggal: YYYY-MM-DD, keterangan}
func (h *AnakArsipHandler) Arsipkan(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	anakID, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	var in service.ArsipAnakInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "alasan dan tanggal wajib diisi"})
		return
	}
	a, err := h.svc.Arsipkan(pos, anakID, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "data anak diarsipkan", "data": a})
}

// PUT /kader/balita/:anak_id/aktifkan
func (h *AnakArsipHandler) Aktifkan(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	anakID, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	a, err := h.svc.Aktifkan(pos, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "data anak diaktifkan kembali", "data": a})
}