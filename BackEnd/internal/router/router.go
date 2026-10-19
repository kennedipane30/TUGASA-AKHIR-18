package router

import (
	"posyandu-api/internal/handler"
	"posyandu-api/internal/middleware"
	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"
	"posyandu-api/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func Setup(db *gorm.DB) *gin.Engine {
	r := gin.Default()

	_ = db.AutoMigrate(&models.MateriPanduan{})

	// repository
	userRepo := repository.NewUserRepository(db)
	keluargaRepo := repository.NewKeluargaRepository(db)
	jadwalRepo := repository.NewJadwalRepository(db)
	pelayananRepo := repository.NewPelayananRepository(db)

	// pembatasan data per posyandu
	akses := handler.NewAkses(jadwalRepo)

	// service
	jadwalSvc := service.NewJadwalService(jadwalRepo, keluargaRepo)

	// handler
	authH := handler.NewAuthHandler(service.NewAuthService(userRepo))
	keluargaH := handler.NewKeluargaHandler(service.NewKeluargaService(keluargaRepo))
	jadwalH := handler.NewJadwalHandler(jadwalSvc)
	pelayananH := handler.NewPelayananHandler(
		service.NewPelayananService(jadwalRepo, pelayananRepo, keluargaRepo), akses)
	panduanH := handler.NewPanduanHandler(repository.NewPanduanRepository(db))

	api := r.Group("/api/v1")
	api.GET("/posyandu", authH.ListPosyandu) // publik, untuk registrasi
	api.POST("/auth/register", authH.Register)
	api.POST("/auth/login", authH.Login)

	// semua role (sudah login); posyandu akun dimuat di middleware
	protected := api.Group("/", middleware.AuthRequired(), middleware.Posyandu(userRepo))
	protected.GET("/auth/me", authH.Me)
	protected.GET("/jadwal", jadwalH.List)
	protected.GET("/jadwal/terdekat", jadwalH.Terdekat)
	protected.GET("/vaksin", pelayananH.ListVaksin)
	protected.GET("/panduan", panduanH.List)

	// sekretaris (satu akun per desa, hanya mengelola desanya sendiri)
	sekretaris := protected.Group("/sekretaris", middleware.RoleRequired("sekretaris"))
	sekretaris.POST("/users", authH.CreateStaff)
	sekretaris.GET("/users", authH.ListStaff)
	sekretaris.PUT("/users/:id", authH.UpdateStaff)
	sekretaris.PATCH("/users/:id/aktif", authH.SetStaffActive)
	sekretaris.DELETE("/users/:id", authH.DeleteStaff)
	sekretaris.POST("/jadwal", jadwalH.Buat)
	sekretaris.PUT("/jadwal/:id", jadwalH.Ubah)
	sekretaris.POST("/jadwal/:id/batalkan", jadwalH.Batalkan)
	sekretaris.GET("/jadwal/:id/qr", jadwalH.QRJadwal)
	sekretaris.GET("/panduan", panduanH.ListAdmin)
	sekretaris.POST("/panduan", panduanH.Create)
	sekretaris.PUT("/panduan/:id", panduanH.Update)
	sekretaris.DELETE("/panduan/:id", panduanH.Delete)

	// orang tua (check-in dengan memindai QR jadwal)
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
	ortu.POST("/jadwal/:id/scan", jadwalH.Scan)
	ortu.GET("/jadwal/:id/kartu", jadwalH.Kartu)
	ortu.GET("/riwayat", pelayananH.Riwayat)

	// kader (menampilkan QR jadwal, bukan memindai)
	kader := protected.Group("/kader", middleware.RoleRequired("kader"))
	kader.GET("/anak", jadwalH.CariAnak)
	kader.GET("/jadwal/:id/qr", jadwalH.QRJadwal)
	kader.POST("/jadwal/:id/walkin", jadwalH.WalkIn)
	kader.POST("/pendaftaran/:id/checkin", jadwalH.CheckinManual)
	kader.GET("/jadwal/:id/antrean", pelayananH.AntreanKader)
	kader.GET("/pendaftaran/:id/pengukuran", pelayananH.PengukuranKader)
	kader.PUT("/pendaftaran/:id/pengukuran", pelayananH.CatatPengukuran)

	// bidan
	bidan := protected.Group("/bidan", middleware.RoleRequired("bidan"))
	bidan.GET("/jadwal/:id/pengukuran", pelayananH.AntreanBidan)
	bidan.GET("/pendaftaran/:id", pelayananH.DetailBidan)
	bidan.PUT("/pendaftaran/:id/catatan", pelayananH.SimpanCatatan)

	return r
}