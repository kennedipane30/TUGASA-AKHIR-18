package handler

import (
	"net/http"
	"strconv"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type KpspHandler struct{ svc *service.KpspService }

func NewKpspHandler(svc *service.KpspService) *KpspHandler { return &KpspHandler{svc} }

// GET /bidan/kpsp/lembar?usia_bulan=18
// Mengambil 10 pertanyaan KPSP yang sesuai untuk balita berumur usia_bulan.
// Kelompok umurnya ditentukan server, aplikasi cukup mengirim umur balita.
//
// Balasan berisi berlaku=false bila balita di luar jangkauan KPSP (3-72 bulan);
// pada keadaan itu aplikasi menyembunyikan kartu KPSP.
func (h *KpspHandler) Lembar(c *gin.Context) {
	usia, err := strconv.Atoi(c.Query("usia_bulan"))
	if err != nil || usia < 0 || usia > 300 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "usia_bulan tidak valid"})
		return
	}
	data, err := h.svc.Lembar(usia)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "gagal mengambil lembar KPSP"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}