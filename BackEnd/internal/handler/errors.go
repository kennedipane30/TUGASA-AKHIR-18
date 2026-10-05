package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

func tulisError(c *gin.Context, err error) {
	var ev service.ErrValidasi
	var ek service.ErrKonflik
	var et service.ErrTerlarang

	switch {
	case errors.As(err, &ev):
		c.JSON(http.StatusBadRequest, gin.H{"error": ev.Pesan})
	case errors.As(err, &ek):
		c.JSON(http.StatusConflict, gin.H{"error": ek.Pesan})
	case errors.As(err, &et):
		c.JSON(http.StatusForbidden, gin.H{"error": et.Pesan})
	case errors.Is(err, service.ErrJadwalTidakAda),
		errors.Is(err, service.ErrPendaftaranTidakAda),
		errors.Is(err, service.ErrAnakTidakAda):
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
	}
}