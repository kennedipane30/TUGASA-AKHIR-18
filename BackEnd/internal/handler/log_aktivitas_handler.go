package handler

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"posyandu-api/internal/repository"

	"github.com/gin-gonic/gin"
)

type LogAktivitasHandler struct {
	repo *repository.LogAktivitasRepository
}

func NewLogAktivitasHandler(r *repository.LogAktivitasRepository) *LogAktivitasHandler {
	return &LogAktivitasHandler{repo: r}
}

var roleLogAktivitas = map[string]bool{
	"sekretaris": true,
	"bidan":      true,
	"kader":      true,
	"orang_tua":  true,
}

// GET /sekretaris/log-aktivitas?role=&tanggal=YYYY-MM-DD&halaman=1&per_halaman=30
// Hanya log posyandu milik sekretaris yang login.
func (h *LogAktivitasHandler) Daftar(c *gin.Context) {
	pos, ok := posyanduCtx(c)
	if !ok {
		return
	}

	role := c.Query("role")
	if role != "" && !roleLogAktivitas[role] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "role tidak dikenal"})
		return
	}

	halaman, _ := strconv.Atoi(c.DefaultQuery("halaman", "1"))
	if halaman < 1 {
		halaman = 1
	}
	per, _ := strconv.Atoi(c.DefaultQuery("per_halaman", "30"))
	if per < 1 || per > 100 {
		per = 30
	}

	f := repository.FilterLogAktivitas{
		Posyandu: fmt.Sprint(pos),
		Role:     role,
		Limit:    per,
		Offset:   (halaman - 1) * per,
	}
	if t := c.Query("tanggal"); t != "" {
		d, err := time.ParseInLocation("2006-01-02", t, time.Local)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "format tanggal harus YYYY-MM-DD"})
			return
		}
		akhir := d.AddDate(0, 0, 1)
		f.Dari = &d
		f.Sampai = &akhir
	}

	list, total, err := h.repo.Daftar(f)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "gagal memuat log aktivitas"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data":        list,
		"total":       total,
		"halaman":     halaman,
		"per_halaman": per,
	})
}