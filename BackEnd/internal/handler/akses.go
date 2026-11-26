package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/repository"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// posyanduCtx membaca posyandu akun yang sedang login (diisi middleware).
func posyanduCtx(c *gin.Context) (string, bool) {
	p := c.GetString("posyandu")
	if p == "" {
		c.JSON(http.StatusForbidden, gin.H{"error": "akun belum terhubung ke posyandu"})
		return "", false
	}
	return p, true
}

// Akses membatasi data per posyandu untuk semua role.
type Akses struct{ repo *repository.JadwalRepository }

func NewAkses(r *repository.JadwalRepository) *Akses { return &Akses{r} }

func (a *Akses) cek(c *gin.Context, asal string, err error, pesan string) bool {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusNotFound, gin.H{"error": "data tidak ditemukan"})
		return false
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return false
	}
	mine, ok := posyanduCtx(c)
	if !ok {
		return false
	}
	if mine != asal {
		c.JSON(http.StatusForbidden, gin.H{"error": pesan})
		return false
	}
	return true
}

func (a *Akses) Jadwal(c *gin.Context, id uuid.UUID) bool {
	j, err := a.repo.GetJadwal(id)
	return a.cek(c, j.Posyandu, err, "jadwal milik posyandu lain")
}

func (a *Akses) Pendaftaran(c *gin.Context, id uuid.UUID) bool {
	p, err := a.repo.GetPendaftaran(id)
	asal := ""
	if err == nil && p.Jadwal != nil {
		asal = p.Jadwal.Posyandu
	}
	return a.cek(c, asal, err, "data milik posyandu lain")
}

func (a *Akses) Anak(c *gin.Context, id uuid.UUID) bool {
	asal, err := a.repo.PosyanduAnak(id)
	return a.cek(c, asal, err, "anak terdaftar di posyandu lain")
}