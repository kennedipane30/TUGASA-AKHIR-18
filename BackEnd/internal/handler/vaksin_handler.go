package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type VaksinHandler struct{ svc *service.VaksinService }

func NewVaksinHandler(svc *service.VaksinService) *VaksinHandler { return &VaksinHandler{svc} }

type buatRencanaReq struct {
	AnakID            uuid.UUID `json:"anak_id" binding:"required"`
	JadwalImunisasiID uuid.UUID `json:"jadwal_imunisasi_id" binding:"required"`
	PerkiraanTanggal  string    `json:"perkiraan_tanggal" binding:"required"`
	Alasan            string    `json:"alasan" binding:"required"`
}

type ubahRencanaReq struct {
	PerkiraanTanggal string `json:"perkiraan_tanggal" binding:"required"`
	Alasan           string `json:"alasan" binding:"required"`
}

type batalRencanaReq struct {
	Alasan string `json:"alasan"`
}

type catatRiwayatReq struct {
	AnakID           uuid.UUID `json:"anak_id" binding:"required"`
	JenisVaksinID    uuid.UUID `json:"jenis_vaksin_id" binding:"required"`
	DosisKe          int16     `json:"dosis_ke" binding:"required"`
	TanggalPemberian string    `json:"tanggal_pemberian" binding:"required"`
	KondisiAnak      string    `json:"kondisi_anak"`
	Catatan          string    `json:"catatan"`
}

// ---------------------------------------------------------------- helper

func vaksinActor(c *gin.Context) (uint, string, bool) {
	v, ok := c.Get("user_id")
	if !ok {
		return 0, "", false
	}
	var uid uint
	switch t := v.(type) {
	case uint:
		uid = t
	case int:
		uid = uint(t)
	case int64:
		uid = uint(t)
	case float64:
		uid = uint(t)
	default:
		return 0, "", false
	}
	return uid, c.GetString("role"), true
}

func vaksinBidan(c *gin.Context) (uint, bool) {
	uid, role, ok := vaksinActor(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "sesi tidak valid"})
		return 0, false
	}
	if role != "bidan" {
		c.JSON(http.StatusForbidden, gin.H{"error": "hanya bidan yang dapat melakukan aksi ini"})
		return 0, false
	}
	return uid, true
}

func vaksinError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrVaksinAnakTidakDitemukan),
		errors.Is(err, service.ErrVaksinJadwalTidakDitemukan),
		errors.Is(err, service.ErrVaksinRencanaTidakDitemukan),
		errors.Is(err, gorm.ErrRecordNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
	case errors.Is(err, service.ErrVaksinAksesDitolak):
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
	case errors.Is(err, service.ErrVaksinRencanaDuplikat),
		errors.Is(err, service.ErrVaksinSudahDiberikan),
		errors.Is(err, service.ErrVaksinRencanaTidakBisaDiubah):
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	case errors.Is(err, service.ErrVaksinTanggalTidakValid),
		errors.Is(err, service.ErrVaksinTanggalLampau),
		errors.Is(err, service.ErrVaksinTanggalMasaDepan),
		errors.Is(err, service.ErrVaksinTanggalSebelumLahir),
		errors.Is(err, service.ErrVaksinAlasanWajib),
		errors.Is(err, service.ErrVaksinDosisTidakValid):
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": "terjadi kesalahan pada server"})
	}
}

func vaksinParamUUID(c *gin.Context, name string) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param(name))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "id tidak valid"})
		return uuid.Nil, false
	}
	return id, true
}

// ---------------------------------------------------------------- bidan

func (h *VaksinHandler) ListJadwalMaster(c *gin.Context) {
	if _, ok := vaksinBidan(c); !ok {
		return
	}
	data, err := h.svc.ListJadwalMaster()
	if err != nil {
		vaksinError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

func (h *VaksinHandler) BuatRencana(c *gin.Context) {
	uid, ok := vaksinBidan(c)
	if !ok {
		return
	}
	var req buatRencanaReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data tidak lengkap atau tidak valid"})
		return
	}
	data, err := h.svc.BuatRencana(uid, service.BuatRencanaInput{
		AnakID:            req.AnakID,
		JadwalImunisasiID: req.JadwalImunisasiID,
		PerkiraanTanggal:  req.PerkiraanTanggal,
		Alasan:            req.Alasan,
	})
	if err != nil {
		vaksinError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": data})
}

func (h *VaksinHandler) UbahRencana(c *gin.Context) {
	uid, ok := vaksinBidan(c)
	if !ok {
		return
	}
	id, ok := vaksinParamUUID(c, "id")
	if !ok {
		return
	}
	var req ubahRencanaReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data tidak lengkap atau tidak valid"})
		return
	}
	data, err := h.svc.UbahRencana(uid, id, service.UbahRencanaInput{
		PerkiraanTanggal: req.PerkiraanTanggal,
		Alasan:           req.Alasan,
	})
	if err != nil {
		vaksinError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

func (h *VaksinHandler) BatalkanRencana(c *gin.Context) {
	uid, ok := vaksinBidan(c)
	if !ok {
		return
	}
	id, ok := vaksinParamUUID(c, "id")
	if !ok {
		return
	}
	var req batalRencanaReq
	_ = c.ShouldBindJSON(&req)
	data, err := h.svc.BatalkanRencana(uid, id, req.Alasan)
	if err != nil {
		vaksinError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

func (h *VaksinHandler) CatatRiwayat(c *gin.Context) {
	uid, ok := vaksinBidan(c)
	if !ok {
		return
	}
	var req catatRiwayatReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data tidak lengkap atau tidak valid"})
		return
	}
	data, err := h.svc.CatatRiwayat(uid, service.CatatRiwayatInput{
		AnakID:           req.AnakID,
		JenisVaksinID:    req.JenisVaksinID,
		DosisKe:          req.DosisKe,
		TanggalPemberian: req.TanggalPemberian,
		KondisiAnak:      req.KondisiAnak,
		Catatan:          req.Catatan,
	})
	if err != nil {
		vaksinError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"data": data})
}

// ---------------------------------------------------------------- bidan, kader, orang tua

func (h *VaksinHandler) ListRencanaAnak(c *gin.Context) {
	uid, role, ok := vaksinActor(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "sesi tidak valid"})
		return
	}
	anakID, ok := vaksinParamUUID(c, "anak_id")
	if !ok {
		return
	}
	data, err := h.svc.ListRencana(anakID, uid, role)
	if err != nil {
		vaksinError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}

func (h *VaksinHandler) ListRiwayatAnak(c *gin.Context) {
	uid, role, ok := vaksinActor(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "sesi tidak valid"})
		return
	}
	anakID, ok := vaksinParamUUID(c, "anak_id")
	if !ok {
		return
	}
	data, err := h.svc.ListRiwayat(anakID, uid, role)
	if err != nil {
		vaksinError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": data})
}