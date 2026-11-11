package handler

import (
	"errors"
	"net/http"
	"strconv"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type NotifikasiHandler struct{ svc *service.NotifikasiService }

func NewNotifikasiHandler(s *service.NotifikasiService) *NotifikasiHandler {
	return &NotifikasiHandler{s}
}

func tulisErrorNotif(c *gin.Context, err error) {
	if errors.Is(err, service.ErrNotifikasiTidakAda) {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	tulisError(c, err)
}

func angkaQuery(c *gin.Context, nama string, bawaan, min, maks int) int {
	n, err := strconv.Atoi(c.Query(nama))
	if err != nil {
		return bawaan
	}
	if n < min {
		return min
	}
	if n > maks {
		return maks
	}
	return n
}

// GET /notifikasi?belum_dibaca=true&limit=20&offset=0
func (h *NotifikasiHandler) List(c *gin.Context) {
	limit := angkaQuery(c, "limit", 20, 1, 100)
	offset := angkaQuery(c, "offset", 0, 0, 1_000_000)
	belum := c.Query("belum_dibaca") == "true" || c.Query("belum_dibaca") == "1"

	d, err := h.svc.List(c.GetUint("user_id"), belum, limit, offset)
	if err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"data":         d.Data,
		"total":        d.Total,
		"belum_dibaca": d.BelumDibaca,
		"limit":        limit,
		"offset":       offset,
	})
}

// GET /notifikasi/jumlah-belum-dibaca
func (h *NotifikasiHandler) JumlahBelumDibaca(c *gin.Context) {
	n, err := h.svc.JumlahBelumDibaca(c.GetUint("user_id"))
	if err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"belum_dibaca": n}})
}

// PATCH /notifikasi/:id/baca
func (h *NotifikasiHandler) Baca(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	n, err := h.svc.Baca(c.GetUint("user_id"), id)
	if err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": n})
}

// POST /notifikasi/baca-semua
func (h *NotifikasiHandler) BacaSemua(c *gin.Context) {
	n, err := h.svc.BacaSemua(c.GetUint("user_id"))
	if err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"diperbarui": n}})
}

// DELETE /notifikasi/:id
func (h *NotifikasiHandler) Hapus(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	if err := h.svc.Hapus(c.GetUint("user_id"), id); err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "notifikasi dihapus"})
}

// POST /notifikasi/hapus   body: {"ids": ["uuid", "uuid", ...]}
func (h *NotifikasiHandler) HapusBanyak(c *gin.Context) {
	var in service.HapusNotifikasiInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "daftar notifikasi wajib diisi"})
		return
	}
	n, err := h.svc.HapusBanyak(c.GetUint("user_id"), in.IDs)
	if err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"message": "notifikasi dihapus",
		"data":    gin.H{"dihapus": n},
	})
}

// POST /notifikasi/hapus-semua?sudah_dibaca=true
// tanpa query: hapus semua notifikasi; sudah_dibaca=true: hanya yang sudah dibaca.
func (h *NotifikasiHandler) HapusSemua(c *gin.Context) {
	dibaca := c.Query("sudah_dibaca") == "true" || c.Query("sudah_dibaca") == "1"
	n, err := h.svc.HapusSemua(c.GetUint("user_id"), dibaca)
	if err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"message": "notifikasi dihapus",
		"data":    gin.H{"dihapus": n},
	})
}

// POST /perangkat/token
func (h *NotifikasiHandler) SimpanToken(c *gin.Context) {
	var in service.TokenPerangkatInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token wajib diisi"})
		return
	}
	p, err := h.svc.SimpanToken(c.GetUint("user_id"), in)
	if err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": p})
}

// DELETE /perangkat/token
func (h *NotifikasiHandler) HapusToken(c *gin.Context) {
	var in struct {
		Token string `json:"token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token wajib diisi"})
		return
	}
	if err := h.svc.HapusToken(c.GetUint("user_id"), in.Token); err != nil {
		tulisErrorNotif(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "token perangkat dihapus"})
}