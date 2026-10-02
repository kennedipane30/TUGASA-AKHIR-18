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

	api := r.Group("/api/v1")
	api.POST("/auth/register", authH.Register)
	api.POST("/auth/login", authH.Login)

	protected := api.Group("/", middleware.AuthRequired())
	protected.GET("/auth/me", authH.Me)

	admin := protected.Group("/admin", middleware.RoleRequired("admin"))
	admin.POST("/users", authH.CreateStaff)

	// contoh untuk fitur berikutnya:
	// kader := protected.Group("/kader", middleware.RoleRequired("kader"))
	// verifikasi := protected.Group("/verifikasi", middleware.RoleRequired("bidan"))

	return r
}