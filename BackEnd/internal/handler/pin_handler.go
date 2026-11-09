package handler

import (
	"errors"
	"net/http"
	"strconv"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type PinHandler struct{ svc *service.PinService }

func NewPinHandler(s *service.PinService) *PinHandler { return &PinHandler{s} }

func tulisErrorPin(c *gin.Context, err error) {
	var salah service.ErrLoginSalah
	var kunci service.ErrLoginTerkunci
	var pin service.ErrPin
	switch {
	case errors.As(err, &salah):
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
	case errors.As(err, &kunci):
		c.JSON(http.StatusTooManyRequests, gin.H{"error": err.Error()})
	case errors.Is(err, service.ErrLoginNonaktif):
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
	case errors.As(err, &pin):
		c.JSON(http.StatusBadRequest, gin.H{"error": pin.Pesan})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": "terjadi kesalahan pada server"})
	}
}

// POST /auth/login  {identifier, pin}
// Semua role masuk dengan No. HP / NIK / username + PIN 6 digit.
func (h *PinHandler) Login(c *gin.Context) {
	var in struct {
		Identifier string `json:"identifier" binding:"required"`
		Pin        string `json:"pin" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No. HP/username dan PIN wajib diisi"})
		return
	}
	token, u, err := h.svc.Login(in.Identifier, in.Pin)
	if err != nil {
		tulisErrorPin(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"token": token, "user": u})
}

// POST /auth/ubah-pin  {pin_lama, pin_baru}  (semua role)
func (h *PinHandler) UbahPIN(c *gin.Context) {
	var in struct {
		PinLama string `json:"pin_lama" binding:"required"`
		PinBaru string `json:"pin_baru" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "PIN lama dan PIN baru wajib diisi"})
		return
	}
	if err := h.svc.UbahPIN(c.GetUint("user_id"), in.PinLama, in.PinBaru); err != nil {
		tulisErrorPin(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"pesan": "PIN berhasil diubah"}})
}

// POST /sekretaris/users/:id/reset-pin  (orang tua, kader, bidan di posyandunya)
// POST /kader/users/:id/reset-pin       (hanya orang tua di posyandunya)
func (h *PinHandler) ResetPIN(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id tidak valid"})
		return
	}
	pin, err := h.svc.ResetPIN(uint(id), c.GetString("posyandu"), c.GetString("role"))
	if err != nil {
		tulisErrorPin(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{
		"pin_sementara": pin,
		"pesan":         "Sampaikan PIN ini kepada pemilik akun. PIN hanya ditampilkan sekali dan wajib diganti saat masuk.",
	}})
}