package handler

// Endpoint riwayat kunjungan balita untuk orang tua.

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// GET /riwayat?balita_id=...   (hanya kunjungan yang sudah diberi catatan bidan)
func (h *PelayananHandler) Riwayat(c *gin.Context) {
	var balitaID *uuid.UUID
	if s := c.Query("balita_id"); s != "" {
		id, err := uuid.Parse(s)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "balita_id tidak valid"})
			return
		}
		balitaID = &id
	}
	list, err := h.svc.Riwayat(c.GetUint("user_id"), balitaID)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}