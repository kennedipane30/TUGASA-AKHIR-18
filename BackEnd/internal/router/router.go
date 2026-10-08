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

	// repository
	userRepo := repository.NewUserRepository(db)
	keluargaRepo := repository.NewKeluargaRepository(db)
	jadwalRepo := repository.NewJadwalRepository(db)
	pelayananRepo := repository.NewPelayananRepository(db)
	vaksinRepo := repository.NewVaksinRepository(db)

	// service
	jadwalSvc := service.NewJadwalService(jadwalRepo, keluargaRepo)
	vaksinSvc := service.NewVaksinService(vaksinRepo)

	// handler
	authH := handler.NewAuthHandler(service.NewAuthService(userRepo))
	pinH := handler.NewPinHandler(service.NewPinService(userRepo)) // BARU: login PIN
	keluargaH := handler.NewKeluargaHandler(service.NewKeluargaService(keluargaRepo))
	jadwalH := handler.NewJadwalHandler(jadwalSvc)
	scanH := handler.NewKaderScanHandler(jadwalSvc)
	pelayananH := handler.NewPelayananHandler(service.NewPelayananService(jadwalRepo, pelayananRepo, keluargaRepo))
	vaksinH := handler.NewVaksinHandler(vaksinSvc)

	api := r.Group("/api/v1")
	api.POST("/auth/register", authH.Register)
	api.POST("/auth/login", pinH.Login) // BARU: sebelumnya authH.Login

	// semua role (sudah login)
	protected := api.Group("/", middleware.AuthRequired())
	protected.GET("/auth/me", authH.Me)
	protected.POST("/auth/ubah-sandi", pinH.UbahSandi)                                              // BARU
	protected.POST("/users/:id/reset-pin", middleware.RoleRequired("admin", "kader"), pinH.ResetPIN) // BARU
	protected.GET("/jadwal", jadwalH.List)
	protected.GET("/jadwal/terdekat", jadwalH.Terdekat)
	protected.GET("/vaksin", pelayananH.ListVaksin)

	// fitur vaksin (bidan: kelola; bidan, kader, orang tua: lihat rencana & riwayat)
	vaksin := protected.Group("/vaksin", middleware.RoleRequired("bidan", "kader", "orang_tua"))
	vaksin.GET("/master", middleware.RoleRequired("bidan"), vaksinH.ListJadwalMaster)
	vaksin.POST("/rencana", middleware.RoleRequired("bidan"), vaksinH.BuatRencana)
	vaksin.PUT("/rencana/:id", middleware.RoleRequired("bidan"), vaksinH.UbahRencana)
	vaksin.PATCH("/rencana/:id/batal", middleware.RoleRequired("bidan"), vaksinH.BatalkanRencana)
	vaksin.POST("/riwayat", middleware.RoleRequired("bidan"), vaksinH.CatatRiwayat)
	vaksin.GET("/anak/:anak_id/rencana", vaksinH.ListRencanaAnak)
	vaksin.GET("/anak/:anak_id/riwayat", vaksinH.ListRiwayatAnak)

	// admin
	admin := protected.Group("/admin", middleware.RoleRequired("admin"))
	admin.POST("/users", authH.CreateStaff)
	admin.GET("/users", authH.ListStaff)
	admin.PUT("/users/:id", authH.UpdateStaff)
	admin.PATCH("/users/:id/aktif", authH.SetStaffActive)
	admin.DELETE("/users/:id", authH.DeleteStaff)
	admin.POST("/jadwal", jadwalH.Buat)
	admin.PUT("/jadwal/:id", jadwalH.Ubah)
	admin.POST("/jadwal/:id/batalkan", jadwalH.Batalkan)
	vaksinStatRepo := repository.NewVaksinStatistikRepository(db)
	vaksinStatH := handler.NewVaksinStatistikHandler(service.NewVaksinStatistikService(vaksinStatRepo))

	// orang tua
	ortu := protected.Group("/", middleware.RoleRequired("orang_tua"))
	ortu.GET("/keluarga/saya", keluargaH.Get)
	ortu.PUT("/keluarga/saya", keluargaH.SimpanProfil)
	ortu.POST("/keluarga/saya/anak", keluargaH.TambahAnak)
	ortu.PUT("/keluarga/saya/anak/:id", keluargaH.UbahAnak)
	ortu.DELETE("/keluarga/saya/anak/:id", keluargaH.HapusAnak)
	ortu.GET("/keluarga", keluargaH.Get)
	ortu.PUT("/keluarga", keluargaH.SimpanProfil)
	ortu.POST("/keluarga/anak", keluargaH.TambahAnak)
	ortu.PUT("/keluarga/anak/:id", keluargaH.UbahAnak)
	ortu.DELETE("/keluarga/anak/:id", keluargaH.HapusAnak)
	ortu.POST("/jadwal/:id/daftar", jadwalH.Daftar)
	ortu.POST("/jadwal/:id/batal", jadwalH.BatalDaftar)
	ortu.POST("/jadwal/:id/checkin", jadwalH.Checkin)
	ortu.GET("/riwayat", pelayananH.Riwayat)

	// kader
	kader := protected.Group("/kader", middleware.RoleRequired("kader"))
	kader.GET("/anak", jadwalH.CariAnak)
	kader.POST("/jadwal/:id/walkin", jadwalH.WalkIn)
	kader.POST("/jadwal/:id/scan", scanH.Scan)
	kader.POST("/pendaftaran/:id/checkin", jadwalH.CheckinManual)
	kader.GET("/jadwal/:id/antrean", pelayananH.AntreanKader)
	kader.PUT("/pendaftaran/:id/pengukuran", pelayananH.CatatPengukuran)

	// bidan
	bidan := protected.Group("/bidan", middleware.RoleRequired("bidan"))
	bidan.GET("/jadwal/:id/pengukuran", pelayananH.AntreanBidan)
	bidan.GET("/pendaftaran/:id", pelayananH.DetailBidan)
	bidan.PUT("/pendaftaran/:id/catatan", pelayananH.SimpanCatatan)

	return r
}