package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// BalitaArsipHandler: kader mengarsipkan / mengaktifkan kembali data balita.
type BalitaArsipHandler struct{ svc *service.BalitaArsipService }

func NewBalitaArsipHandler(s *service.BalitaArsipService) *BalitaArsipHandler {
	return &BalitaArsipHandler{s}
}

// PUT /kader/balita/:balita_id/arsip
// Body: {alasan: pindah|meninggal|lainnya, tanggal: YYYY-MM-DD, keterangan}
func (h *BalitaArsipHandler) Arsipkan(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	balitaID, ok := idParam(c, "balita_id")
	if !ok {
		return
	}
	var in service.ArsipBalitaInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "alasan dan tanggal wajib diisi"})
		return
	}
	a, err := h.svc.Arsipkan(pos, balitaID, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "data balita diarsipkan", "data": a})
}

// PUT /kader/balita/:balita_id/aktifkan
func (h *BalitaArsipHandler) Aktifkan(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	balitaID, ok := idParam(c, "balita_id")
	if !ok {
		return
	}
	a, err := h.svc.Aktifkan(pos, balitaID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "data balita diaktifkan kembali", "data": a})
}