package handler

import (
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// KaderKeluargaHandler: fitur Tambahkan Akun & Data Keluarga di aplikasi kader.
type KaderKeluargaHandler struct{ svc *service.KaderKeluargaService }

func NewKaderKeluargaHandler(s *service.KaderKeluargaService) *KaderKeluargaHandler {
	return &KaderKeluargaHandler{s}
}

// GET /kader/cek-akun?nik=&no_hp=
func (h *KaderKeluargaHandler) CekAkun(c *gin.Context) {
	if _, ok := posyanduCtx(c); !ok {
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": h.svc.CekAkun(c.Query("nik"), c.Query("no_hp"))})
}

// GET /kader/keluarga?cari=
func (h *KaderKeluargaHandler) Cari(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	list, err := h.svc.Cari(pos, c.Query("cari"))
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": list})
}

// POST /kader/keluarga
func (h *KaderKeluargaHandler) Tambah(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	var in service.TambahKeluargaInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "body tidak valid"})
		return
	}
	res, err := h.svc.Tambah(pos, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": res})
}

// GET /kader/keluarga/:id
func (h *KaderKeluargaHandler) Detail(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	res, err := h.svc.Detail(pos, id)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": res})
}

// PUT /kader/keluarga/:id
func (h *KaderKeluargaHandler) UbahProfil(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.ProfilInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "body tidak valid"})
		return
	}
	res, err := h.svc.UbahProfil(pos, id, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": res})
}

// POST /kader/keluarga/:id/balita
func (h *KaderKeluargaHandler) TambahBalita(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	var in service.BalitaInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "body tidak valid"})
		return
	}
	a, err := h.svc.TambahBalita(pos, id, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": a})
}

// PUT /kader/keluarga/:id/balita/:balita_id
func (h *KaderKeluargaHandler) UbahBalita(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}
	id, ok := idParam(c, "id")
	if !ok {
		return
	}
	balitaID, ok := idParam(c, "balita_id")
	if !ok {
		return
	}
	var in service.BalitaInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "body tidak valid"})
		return
	}
	a, err := h.svc.UbahBalita(pos, id, balitaID, in)
	if err != nil {
		tulisError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": a})
}