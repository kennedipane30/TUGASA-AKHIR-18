package handler

import (
	"errors"
	"net/http"
	"strconv"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type KeluargaHandler struct{ svc *service.KeluargaService }

func NewKeluargaHandler(s *service.KeluargaService) *KeluargaHandler {
	return &KeluargaHandler{s}
}

// Ganti "user_id" jika middleware/auth.go memakai key lain pada c.Set(...)
func userID(c *gin.Context) (uint, bool) {
	v, ok := c.Get("user_id")
	if !ok {
		return 0, false
	}
	switch id := v.(type) {
	case uint:
		return id, true
	case int:
		return uint(id), true
	case int64:
		return uint(id), true
	case float64:
		return uint(id), true
	case string:
		n, err := strconv.ParseUint(id, 10, 64)
		return uint(n), err == nil
	}
	return 0, false
}

func respondErr(c *gin.Context, err error) {
	var ve *service.ValidationError
	if errors.As(err, &ve) {
		c.JSON(http.StatusBadRequest, gin.H{"error": ve.Msg})
		return
	}
	c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
}

func paramID(c *gin.Context) (uint, bool) {
	n, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id tidak valid"})
		return 0, false
	}
	return uint(n), true
}

// FUNGSI ListPosyandu SUDAH DIHAPUS DARI SINI

func (h *KeluargaHandler) Get(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "tidak terautentikasi"})
		return
	}
	res, err := h.svc.Get(uid)
	if err != nil {
		respondErr(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": res})
}

func (h *KeluargaHandler) SimpanProfil(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "tidak terautentikasi"})
		return
	}
	var in service.ProfilInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "body tidak valid"})
		return
	}
	res, err := h.svc.SimpanProfil(uid, in)
	if err != nil {
		respondErr(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": res})
}

func (h *KeluargaHandler) TambahAnak(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "tidak terautentikasi"})
		return
	}
	var in service.AnakInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "body tidak valid"})
		return
	}
	a, err := h.svc.TambahAnak(uid, in)
	if err != nil {
		respondErr(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": a})
}

func (h *KeluargaHandler) UbahAnak(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "tidak terautentikasi"})
		return
	}
	id, ok := paramID(c)
	if !ok {
		return
	}
	var in service.AnakInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "body tidak valid"})
		return
	}
	a, err := h.svc.UbahAnak(uid, id, in)
	if err != nil {
		respondErr(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": a})
}

func (h *KeluargaHandler) HapusAnak(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "tidak terautentikasi"})
		return
	}
	id, ok := paramID(c)
	if !ok {
		return
	}
	if err := h.svc.HapusAnak(uid, id); err != nil {
		respondErr(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "data anak dihapus"})
}	