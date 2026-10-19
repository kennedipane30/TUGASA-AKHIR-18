package handler

import (
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

func (h *AuthHandler) Register(c *gin.Context) {
	var in service.RegisterInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	u, err := h.svc.RegisterOrangTua(in)
	if err != nil {
		code := http.StatusInternalServerError
		switch err {
		case service.ErrDuplicate:
			code = http.StatusConflict
		case service.ErrPosyandu:
			code = http.StatusBadRequest
		default:
			if _, ok := err.(service.ErrPin); ok {
				code = http.StatusBadRequest
			}
		}
		c.JSON(code, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": u})
}

func (h *AuthHandler) Login(c *gin.Context) {
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
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"token": token, "user": u})
}

func (h *AuthHandler) Me(c *gin.Context) {
	u, err := h.svc.Me(c.GetUint("user_id"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user tidak ditemukan"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": u})
}

// khusus sekretaris: akun dibuat pada posyandu milik sekretaris
func (h *AuthHandler) CreateStaff(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	var in service.CreateStaffInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	u, err := h.svc.CreateStaff(pos, in)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": u})
}