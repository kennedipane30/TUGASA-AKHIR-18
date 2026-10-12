package handler

import (
	"net/http"
	"strings"

	"posyandu-api/internal/models"

	"github.com/gin-gonic/gin"
)

func modelsDaftarPosyandu() []models.PilihanPosyandu { return models.DaftarPosyandu }

// scopePosyandu menentukan batas data posyandu untuk satu permintaan.
// Non-admin: selalu posyandu akun sendiri. Admin: semua, atau satu posyandu lewat ?posyandu=.
func scopePosyandu(c *gin.Context) (string, bool) {
	if c.GetString("role") != "admin" {
		return c.GetString("posyandu"), true
	}
	q := strings.TrimSpace(c.Query("posyandu"))
	if q == "" {
		return "", true
	}
	p, ok := models.NormalisasiPosyandu(q)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "posyandu harus silimbat, sitoluama, atau aekbolon"})
		return "", false
	}
	return p, true
}