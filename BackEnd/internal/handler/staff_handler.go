package handler

import (
	"net/http"
	"strconv"

	"posyandu-api/internal/models"
	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type staffResponse struct {
	ID       uint   `json:"id"`
	Nama     string `json:"nama"`
	Username string `json:"username"`
	Role     string `json:"role"`
	IsActive bool   `json:"is_active"`
}

func toStaff(u *models.User) staffResponse {
	username := ""
	if u.Username != nil {
		username = *u.Username
	}
	return staffResponse{
		ID:       u.ID,
		Nama:     u.Nama,
		Username: username,
		Role:     string(u.Role),
		IsActive: u.IsActive,
	}
}

func staffError(c *gin.Context, err error) {
	code := http.StatusBadRequest
	switch err {
	case service.ErrNotFound:
		code = http.StatusNotFound
	case service.ErrDuplicate:
		code = http.StatusConflict
	case service.ErrNotStaff:
		code = http.StatusForbidden
	}
	c.JSON(code, gin.H{"error": err.Error()})
}

func staffIDParam(c *gin.Context) (uint, bool) {
	n, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id tidak valid"})
		return 0, false
	}
	return uint(n), true
}

func (h *AuthHandler) ListStaff(c *gin.Context) {
	list, err := h.svc.ListStaff(c.Query("role"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]staffResponse, 0, len(list))
	for i := range list {
		out = append(out, toStaff(&list[i]))
	}
	c.JSON(http.StatusOK, gin.H{"users": out})
}

func (h *AuthHandler) UpdateStaff(c *gin.Context) {
	id, ok := staffIDParam(c)
	if !ok {
		return
	}
	var in service.UpdateStaffInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	u, err := h.svc.UpdateStaff(id, in)
	if err != nil {
		staffError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": toStaff(u)})
}

func (h *AuthHandler) SetStaffActive(c *gin.Context) {
	id, ok := staffIDParam(c)
	if !ok {
		return
	}
	var in struct {
		IsActive *bool `json:"is_active" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	u, err := h.svc.SetStaffActive(id, *in.IsActive)
	if err != nil {
		staffError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": toStaff(u)})
}

func (h *AuthHandler) DeleteStaff(c *gin.Context) {
	id, ok := staffIDParam(c)
	if !ok {
		return
	}
	if err := h.svc.DeleteStaff(id); err != nil {
		staffError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "akun dihapus"})
}