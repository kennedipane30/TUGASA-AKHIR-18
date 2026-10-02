package handler

import (
	"net/http"

	"posyandu-api/internal/service"
	"github.com/gin-gonic/gin"
)

type AuthHandler struct{ svc *service.AuthService }

func NewAuthHandler(s *service.AuthService) *AuthHandler { return &AuthHandler{s} }

func (h *AuthHandler) Register(c *gin.Context) {
	var in service.RegisterInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	u, err := h.svc.RegisterOrangTua(in)
	if err != nil {
		code := http.StatusInternalServerError
		if err == service.ErrDuplicate {
			code = http.StatusConflict
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

// khusus admin
func (h *AuthHandler) CreateStaff(c *gin.Context) {
	var in service.CreateStaffInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	u, err := h.svc.CreateStaff(in)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": u})
}