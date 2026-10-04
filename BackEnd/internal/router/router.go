	package router

	import (
		"posyandu-api/internal/handler"
		"posyandu-api/internal/middleware"
		"posyandu-api/internal/repository"
		"posyandu-api/internal/service"

		"github.com/gin-gonic/gin"
		"gorm.io/gorm"
	)

	func Setup(db *gorm.DB) *gin.Engine {
		r := gin.Default()

		repo := repository.NewUserRepository(db)
		authH := handler.NewAuthHandler(service.NewAuthService(repo))

		keluargaRepo := repository.NewKeluargaRepository(db)
		keluargaH := handler.NewKeluargaHandler(service.NewKeluargaService(keluargaRepo))

		api := r.Group("/api/v1")
		api.POST("/auth/register", authH.Register)
		api.POST("/auth/login", authH.Login)

		protected := api.Group("/", middleware.AuthRequired())
		protected.GET("/auth/me", authH.Me)

		// Route "/posyandu" telah dihapus karena posyandu hanya ada 1 (Sitoluama) dan sudah di-handle otomatis

		// Data keluarga (orang tua)
		keluarga := protected.Group("/keluarga")
		keluarga.GET("", keluargaH.Get)
		keluarga.PUT("", keluargaH.SimpanProfil)
		keluarga.POST("/anak", keluargaH.TambahAnak)
		keluarga.PUT("/anak/:id", keluargaH.UbahAnak)
		keluarga.DELETE("/anak/:id", keluargaH.HapusAnak)

		admin := protected.Group("/admin", middleware.RoleRequired("admin"))
		admin.POST("/users", authH.CreateStaff)
		admin.GET("/users", authH.ListStaff)
		admin.PUT("/users/:id", authH.UpdateStaff)
		admin.PATCH("/users/:id/active", authH.SetStaffActive)
		admin.DELETE("/users/:id", authH.DeleteStaff)

		return r
	}