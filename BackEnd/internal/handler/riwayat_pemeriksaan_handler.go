package handler

// Endpoint riwayat kunjungan anak untuk orang tua.

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// GET /riwayat?anak_id=...   (hanya kunjungan yang sudah diberi catatan bidan)
func (h *PelayananHandler) Riwayat(c *gin.Context) {
	var anakID *uuid.UUID
	if s := c.Query("anak_id"); s != "" {
		id, err := uuid.Parse(s)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "anak_id tidak valid"})
			return
		}
		anakID = &id
	}
	list, err := h.svc.Riwayat(c.GetUint("user_id"), anakID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}