package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct{ svc *service.AuthService }

func NewAuthHandler(s *service.AuthService) *AuthHandler { return &AuthHandler{s} }

// GET /posyandu  (publik, dipakai halaman registrasi)
func (h *AuthHandler) ListPosyandu(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"data": h.svc.ListPosyandu()})
}

// POST /auth/register  {nama, nik, no_hp, pin, posyandu}
func (h *AuthHandler) Register(c *gin.Context) {
	var in service.RegisterInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data belum lengkap: NIK 16 digit, No. HP, dan PIN 6 digit wajib diisi"})
		return
	}
	u, err := h.svc.RegisterOrangTua(in)
	if err != nil {
		var pin service.ErrPin
		code := http.StatusInternalServerError
		switch {
		case errors.Is(err, service.ErrDuplicate):
			code = http.StatusConflict
		case errors.Is(err, service.ErrPosyandu), errors.As(err, &pin):
			code = http.StatusBadRequest
		}
		c.JSON(code, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": u})
}

// GET /auth/me
func (h *AuthHandler) Me(c *gin.Context) {
	u, err := h.svc.Me(c.GetUint("user_id"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user tidak ditemukan"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": u})
}

// POST /sekretaris/users  {nama, username, no_hp, pin, role}
// Akun dibuat pada posyandu milik sekretaris.
func (h *AuthHandler) CreateStaff(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	var in service.CreateStaffInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "nama, username (min. 4 karakter), No. HP (10-15 digit angka), dan PIN 6 digit wajib diisi"})
		return
	}
	u, err := h.svc.CreateStaff(pos, in)
	if err != nil {
		code := http.StatusBadRequest
		if errors.Is(err, service.ErrDuplicate) {
			code = http.StatusConflict
		}
		c.JSON(code, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": u})
}