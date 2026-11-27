package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// AnakArsipHandler: orang tua mengarsipkan / mengaktifkan kembali data anaknya
// dari Data Keluarga > Data Anak.
type AnakArsipHandler struct{ svc *service.AnakArsipService }

func NewAnakArsipHandler(s *service.AnakArsipService) *AnakArsipHandler {
	return &AnakArsipHandler{s}
}

// PUT /keluarga/anak/:id/arsip
// Body: {alasan: pindah|meninggal|lainnya, tanggal: YYYY-MM-DD, keterangan}
func (h *AnakArsipHandler) Arsipkan(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "tidak terautentikasi"})
		return
	}
	anakID, ok := paramID(c)
	if !ok {
		return
	}
	var in service.ArsipAnakInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "alasan dan tanggal wajib diisi"})
		return
	}
	a, err := h.svc.Arsipkan(uid, anakID, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "data anak diarsipkan", "data": a})
}

// PUT /keluarga/anak/:id/aktifkan
func (h *AnakArsipHandler) Aktifkan(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "tidak terautentikasi"})
		return
	}
	anakID, ok := paramID(c)
	if !ok {
		return
	}
	a, err := h.svc.Aktifkan(uid, anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "data anak diaktifkan kembali", "data": a})
}