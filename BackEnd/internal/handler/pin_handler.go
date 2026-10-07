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

// POST /auth/login  (menggantikan AuthHandler.Login)
func (h *PinHandler) Login(c *gin.Context) {
	var in struct {
		Identifier string `json:"identifier" binding:"required"`
		Password   string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	token, u, err := h.svc.Login(in.Identifier, in.Password)
	if err != nil {
		tulisErrorPin(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"token": token, "user": u})
}

// POST /auth/ubah-sandi
func (h *PinHandler) UbahSandi(c *gin.Context) {
	var in struct {
		SandiLama string `json:"sandi_lama" binding:"required"`
		SandiBaru string `json:"sandi_baru" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.svc.UbahSandi(c.GetUint("user_id"), in.SandiLama, in.SandiBaru); err != nil {
		tulisErrorPin(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"pesan": "PIN/kata sandi berhasil diubah"}})
}

// POST /users/:id/reset-pin  (admin dan kader; hanya untuk akun orang tua)
func (h *PinHandler) ResetPIN(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id tidak valid"})
		return
	}
	pin, err := h.svc.ResetPIN(uint(id))
	if err != nil {
		tulisErrorPin(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{
		"pin_sementara": pin,
		"pesan":         "Sampaikan PIN ini kepada orang tua. PIN hanya ditampilkan sekali dan wajib diganti saat masuk.",
	}})
}