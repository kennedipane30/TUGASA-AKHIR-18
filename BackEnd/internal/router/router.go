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

	// BARU: jadwal, pendaftaran, pengukuran, catatan bidan, riwayat
	jadwalRepo := repository.NewJadwalRepository(db)
	pelayananRepo := repository.NewPelayananRepository(db)
	jadwalH := handler.NewJadwalHandler(service.NewJadwalService(jadwalRepo, keluargaRepo))
	pelayananH := handler.NewPelayananHandler(service.NewPelayananService(jadwalRepo, pelayananRepo, keluargaRepo))

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

	// BARU: dapat diakses semua role yang sudah login
	protected.GET("/jadwal", jadwalH.List)
	protected.GET("/jadwal/terdekat", jadwalH.Terdekat)
	protected.GET("/vaksin", pelayananH.ListVaksin)

	admin := protected.Group("/admin", middleware.RoleRequired("admin"))
	admin.POST("/users", authH.CreateStaff)
	admin.GET("/users", authH.ListStaff)
	admin.PUT("/users/:id", authH.UpdateStaff)
	admin.PATCH("/users/:id/active", authH.SetStaffActive)
	admin.DELETE("/users/:id", authH.DeleteStaff)
	// BARU: admin mengelola jadwal
	admin.POST("/jadwal", jadwalH.Buat)
	admin.PUT("/jadwal/:id", jadwalH.Ubah)
	admin.POST("/jadwal/:id/batalkan", jadwalH.Batalkan)

	// BARU: orang tua mendaftar, check-in, dan melihat riwayat
	ortu := protected.Group("/", middleware.RoleRequired("orang_tua"))
	ortu.POST("/jadwal/:id/daftar", jadwalH.Daftar)
	ortu.POST("/jadwal/:id/batal", jadwalH.BatalDaftar)
	ortu.POST("/jadwal/:id/checkin", jadwalH.Checkin)
	ortu.GET("/riwayat", pelayananH.Riwayat)

	// BARU: kader mencatat pengukuran
	kader := protected.Group("/kader", middleware.RoleRequired("kader"))
	kader.GET("/anak", jadwalH.CariAnak)
	kader.POST("/jadwal/:id/walkin", jadwalH.WalkIn)
	kader.POST("/pendaftaran/:id/checkin", jadwalH.CheckinManual)
	kader.GET("/jadwal/:id/antrean", pelayananH.AntreanKader)
	kader.PUT("/pendaftaran/:id/pengukuran", pelayananH.CatatPengukuran)

	// BARU: bidan melihat pengukuran dan menambah catatan
	bidan := protected.Group("/bidan", middleware.RoleRequired("bidan"))
	bidan.GET("/jadwal/:id/pengukuran", pelayananH.AntreanBidan)
	bidan.GET("/pendaftaran/:id", pelayananH.DetailBidan)
	bidan.PUT("/pendaftaran/:id/catatan", pelayananH.SimpanCatatan)

	return r
}