package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type KaderScanHandler struct{ svc *service.JadwalService }

func NewKaderScanHandler(s *service.JadwalService) *KaderScanHandler {
	return &KaderScanHandler{s}
}

func (h *KaderScanHandler) Scan(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "tidak terautentikasi"})
		return
	}
	jid, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id jadwal tidak valid"})
		return
	}
	var in struct {
		KodeQR string `json:"kode_qr" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "kode_qr wajib diisi"})
		return
	}
	p, err := h.svc.ScanQR(uid, jid, in.KodeQR)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": p})
}