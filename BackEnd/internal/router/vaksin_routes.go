package router

import (
	"posyandu-api/internal/handler"
	"posyandu-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

// RegisterVaksinRoutes: pasang pada group yang sudah memakai middleware AuthRequired.
func RegisterVaksinRoutes(api *gin.RouterGroup, h *handler.VaksinHandler) {
	g := api.Group("/vaksin", middleware.RoleRequired("bidan", "kader", "orang_tua"))

	// bidan: kelola rencana dan riwayat vaksin
	bidan := g.Group("", middleware.RoleRequired("bidan"))
	bidan.GET("/master", h.ListJadwalMaster)
	bidan.POST("/rencana", h.BuatRencana)
	bidan.PUT("/rencana/:id", h.UbahRencana)
	bidan.PATCH("/rencana/:id/batal", h.BatalkanRencana)
	bidan.POST("/riwayat", h.CatatRiwayat)

	// bidan, kader, orang tua: lihat rencana dan riwayat
	g.GET("/anak/:anak_id/rencana", h.ListRencanaAnak)
	g.GET("/anak/:anak_id/riwayat", h.ListRiwayatAnak)
}