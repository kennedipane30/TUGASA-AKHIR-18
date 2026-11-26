package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

type RujukanHandler struct{ svc *service.RujukanService }

func NewRujukanHandler(svc *service.RujukanService) *RujukanHandler { return &RujukanHandler{svc} }

func (h *RujukanHandler) gagal(c *gin.Context, err error) {
	if errors.Is(err, service.ErrRujukanTidakAda) {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	tulisError(c, err)
}

// ---------------------------------------------------------------- bidan

// GET /bidan/rujukan?status=aktif|selesai
func (h *RujukanHandler) DaftarBidan(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.DaftarBidan(pos, c.Query("status"))
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /bidan/rujukan-anak?cari=nama/NIK
func (h *RujukanHandler) CariAnak(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	data, err := h.svc.CariAnak(pos, c.Query("cari"))
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /bidan/rujukan-anak/:anak_id : data anak otomatis untuk form rujukan.
func (h *RujukanHandler) DataAnak(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	anakID, ok := idParam(c, "anak_id")
	if !ok {
		return
	}
	data, err := h.svc.DataAnak(pos, anakID)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// POST /bidan/rujukan
func (h *RujukanHandler) Buat(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	var in service.BuatRujukanInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data rujukan belum lengkap atau tidak valid"})
		return
	}
	data, err := h.svc.Buat(c.GetUint("user_id"), pos, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": data})
}

// GET /bidan/rujukan/:id
func (h *RujukanHandler) DetailBidan(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	data, err := h.svc.DetailBidan(pos, id)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// PUT /bidan/rujukan/:id : ubah isian rujukan yang masih aktif.
func (h *RujukanHandler) Ubah(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.UbahRujukanInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data rujukan belum lengkap atau tidak valid"})
		return
	}
	data, err := h.svc.Ubah(c.GetUint("user_id"), pos, id, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// DELETE /bidan/rujukan/:id
func (h *RujukanHandler) Hapus(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	if err := h.svc.Hapus(c.GetUint("user_id"), pos, id); err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "rujukan dihapus"})
}

// PUT /bidan/rujukan/:id/balik : catat hasil dari faskes tujuan.
func (h *RujukanHandler) CatatBalik(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.RujukanBalikInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data rujukan balik belum lengkap atau tidak valid"})
		return
	}
	data, err := h.svc.CatatBalik(c.GetUint("user_id"), pos, id, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// POST /bidan/rujukan/:id/batal
func (h *RujukanHandler) Batal(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.BatalRujukanInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "alasan pembatalan wajib diisi"})
		return
	}
	data, err := h.svc.Batal(c.GetUint("user_id"), pos, id, in)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// ---------------------------------------------------------------- orang tua

// GET /rujukan : rujukan semua anak milik orang tua.
func (h *RujukanHandler) DaftarOrangTua(c *gin.Context) {
	data, err := h.svc.DaftarOrangTua(c.GetUint("user_id"))
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

// GET /rujukan/:id
func (h *RujukanHandler) DetailOrangTua(c *gin.Context) {
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	data, err := h.svc.DetailOrangTua(c.GetUint("user_id"), id)
	if err != nil {
		h.gagal(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}