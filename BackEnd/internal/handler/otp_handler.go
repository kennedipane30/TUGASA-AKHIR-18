package handler

import (
	"errors"
	"net/http"

	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
)

// OtpHandler: kode OTP WhatsApp untuk registrasi orang tua dan lupa PIN.
// Semua endpoint di sini publik (belum login).
type OtpHandler struct{ svc *service.OtpService }

func NewOtpHandler(s *service.OtpService) *OtpHandler { return &OtpHandler{s} }

func tulisErrorOtp(c *gin.Context, err error) {
	var tunggu service.ErrOtpTunggu
	var pin service.ErrPin
	switch {
	case errors.As(err, &tunggu):
		c.JSON(http.StatusTooManyRequests, gin.H{"error": tunggu.Pesan})
	case errors.Is(err, service.ErrWaGagal):
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
	case errors.As(err, &pin):
		c.JSON(http.StatusBadRequest, gin.H{"error": pin.Pesan})
	case errors.Is(err, service.ErrDuplicate):
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	case errors.Is(err, service.ErrPosyandu):
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	default:
		// ErrValidasi (400), ErrKonflik (409), ErrTerlarang (403), lainnya (500)
		tulisError(c, err)
	}
}

// POST /auth/otp/kirim  {no_hp, tujuan}   tujuan: registrasi | reset_pin
func (h *OtpHandler) Kirim(c *gin.Context) {
	var in struct {
		NoHP   string `json:"no_hp" binding:"required"`
		Tujuan string `json:"tujuan" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No. WhatsApp wajib diisi"})
		return
	}
	hasil, err := h.svc.Kirim(in.NoHP, in.Tujuan, c.ClientIP())
	if err != nil {
		tulisErrorOtp(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": hasil})
}

// POST /auth/otp/verifikasi  {no_hp, tujuan, kode}  -> {data: {token_otp, berlaku_detik}}
func (h *OtpHandler) Verifikasi(c *gin.Context) {
	var in struct {
		NoHP   string `json:"no_hp" binding:"required"`
		Tujuan string `json:"tujuan" binding:"required"`
		Kode   string `json:"kode" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "kode verifikasi wajib diisi"})
		return
	}
	hasil, err := h.svc.Verifikasi(in.NoHP, in.Tujuan, in.Kode)
	if err != nil {
		tulisErrorOtp(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": hasil})
}

// POST /auth/register-otp  {nama, nik, no_hp, pin, posyandu, token_otp}
func (h *OtpHandler) Register(c *gin.Context) {
	var in service.RegisterOTPInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "data belum lengkap: NIK 16 digit, No. WhatsApp, PIN 6 digit, dan verifikasi WhatsApp wajib diisi"})
		return
	}
	u, err := h.svc.RegisterDenganOTP(in)
	if err != nil {
		tulisErrorOtp(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"user": u})
}

// POST /auth/lupa-pin  {no_hp, pin_baru, token_otp}
func (h *OtpHandler) LupaPIN(c *gin.Context) {
	var in struct {
		NoHP     string `json:"no_hp" binding:"required"`
		PinBaru  string `json:"pin_baru" binding:"required"`
		TokenOTP string `json:"token_otp" binding:"required"`
	}
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No. WhatsApp, PIN baru, dan verifikasi WhatsApp wajib diisi"})
		return
	}
	if err := h.svc.ResetPINDenganOTP(in.NoHP, in.TokenOTP, in.PinBaru); err != nil {
		tulisErrorOtp(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": gin.H{"pesan": "PIN berhasil diatur ulang. Silakan masuk dengan PIN baru."}})
}