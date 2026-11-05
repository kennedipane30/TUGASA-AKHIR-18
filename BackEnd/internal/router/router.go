package router

import (
	"context"

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
	notifRepo := repository.NewNotifikasiRepository(db)
	giziRepo := repository.NewStatusGiziRepository(db)
	vaksinRepo := repository.NewVaksinRepository(db)
	rekapRepo := repository.NewRekapRepository(db)
	kbmRepo := repository.NewKbmRepository(db)
	balitaRepo := repository.NewBalitaRepository(db)

	// service
	jadwalSvc := service.NewJadwalService(jadwalRepo, keluargaRepo)
	notifSvc := service.NewNotifikasiService(notifRepo, service.NewPushService())
	giziSvc := service.NewStatusGiziService(giziRepo)
	pelayananSvc := service.NewPelayananService(jadwalRepo, pelayananRepo, keluargaRepo)
	pelayananSvc.SetStatusGizi(giziSvc)
	vaksinSvc := service.NewVaksinService(vaksinRepo)
	pelayananSvc.SetVaksin(vaksinSvc)
	kbmSvc := service.NewKbmService(kbmRepo)
	kbmSvc.SetNotifikasi(notifSvc)
	pelayananSvc.SetKbm(kbmSvc)

	// master jenis vaksin & jadwal imunisasi rutin Kemenkes (dibuat/diperbarui otomatis)
	vaksinSvc.SiapkanMaster()

	// pengingat otomatis (24 jam sebelum mulai & check-in dibuka)
	go notifSvc.JalankanPengingat(context.Background())
	// hitung status gizi, lalu penilaian N/T (KBM), 2T, BGM untuk pengukuran lama
	go func() {
		giziSvc.HitungDataLama()
		kbmSvc.HitungDataLama()
	}()

	// handler
	authH := handler.NewAuthHandler(service.NewAuthService(userRepo))
	keluargaH := handler.NewKeluargaHandler(service.NewKeluargaService(keluargaRepo))
	jadwalH := handler.NewJadwalHandler(jadwalSvc, notifSvc)
	pelayananH := handler.NewPelayananHandler(pelayananSvc)
	notifH := handler.NewNotifikasiHandler(notifSvc)
	vaksinH := handler.NewVaksinHandler(vaksinSvc)
	rekapH := handler.NewRekapHandler(service.NewRekapService(rekapRepo))
	balitaH := handler.NewBalitaHandler(service.NewBalitaService(balitaRepo, vaksinRepo))

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
	protected.GET("/vaksin/jadwal", vaksinH.JadwalMaster)
	protected.GET("/vaksin/anak/:anak_id", vaksinH.KartuAnak)

	// notifikasi (semua role)
	protected.GET("/notifikasi", notifH.List)
	protected.GET("/notifikasi/jumlah-belum-dibaca", notifH.JumlahBelumDibaca)
	protected.POST("/notifikasi/baca-semua", notifH.BacaSemua)
	protected.PATCH("/notifikasi/:id/baca", notifH.Baca)
	protected.DELETE("/notifikasi/:id", notifH.Hapus)
	protected.POST("/perangkat/token", notifH.SimpanToken)
	protected.DELETE("/perangkat/token", notifH.HapusToken)

	// sekretaris (satu akun per desa, hanya mengelola desanya sendiri)
	sekretaris := protected.Group("/sekretaris", middleware.RoleRequired("sekretaris"))
	sekretaris.POST("/users", authH.CreateStaff)
	sekretaris.GET("/users", authH.ListStaff)
	sekretaris.PUT("/users/:id", authH.UpdateStaff)
	sekretaris.PATCH("/users/:id/aktif", authH.SetStaffActive)
	sekretaris.DELETE("/users/:id", authH.DeleteStaff)
	sekretaris.POST("/jadwal", jadwalH.Buat)
	sekretaris.GET("/jadwal/riwayat", jadwalH.Riwayat) // harus sebelum /jadwal/:id
	sekretaris.PUT("/jadwal/:id", jadwalH.Ubah)
	sekretaris.DELETE("/jadwal/:id", jadwalH.Hapus)
	sekretaris.POST("/jadwal/:id/batalkan", jadwalH.Batalkan)
	sekretaris.GET("/qr", jadwalH.QRPosyandu) // QR tetap, satu per posyandu
	sekretaris.GET("/jadwal/:id/qr", jadwalH.QRJadwal)
	// riwayat pemeriksaan: tanggal posyandu -> anak -> hasil pendataan
	sekretaris.GET("/riwayat/jadwal", pelayananH.SekretarisRiwayatJadwal)
	sekretaris.GET("/riwayat/jadwal/:id/anak", pelayananH.SekretarisRiwayatAnak)
	sekretaris.GET("/riwayat/pendaftaran/:id", pelayananH.SekretarisRiwayatDetail)
	sekretaris.GET("/vaksin/statistik", vaksinH.Statistik)
	// rekap posyandu: status gizi, Vitamin A & obat cacing, balita tidak hadir
	sekretaris.GET("/rekap/gizi", rekapH.Gizi)
	sekretaris.GET("/rekap/suplemen", rekapH.Suplemen)
	sekretaris.GET("/rekap/tidak-hadir", rekapH.TidakHadir)
	// semua balita posyandu
	sekretaris.GET("/balita", balitaH.Daftar)
	sekretaris.GET("/balita/:anak_id", balitaH.Detail)

	// orang tua (check-in dengan memindai QR tetap posyandu)
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

	// kader (menampilkan QR tetap posyandu, bukan memindai)
	kader := protected.Group("/kader", middleware.RoleRequired("kader"))
	kader.GET("/anak", jadwalH.CariAnak)
	kader.GET("/qr", jadwalH.QRPosyandu) // QR tetap, satu per posyandu
	kader.GET("/jadwal/:id/qr", jadwalH.QRJadwal)
	kader.POST("/jadwal/:id/walkin", jadwalH.WalkIn)
	kader.POST("/pendaftaran/:id/checkin", jadwalH.CheckinManual)
	kader.GET("/jadwal/:id/antrean", pelayananH.AntreanKader)
	kader.GET("/pendaftaran/:id/pengukuran", pelayananH.PengukuranKader)
	kader.PUT("/pendaftaran/:id/pengukuran", pelayananH.CatatPengukuran)
	// riwayat pemeriksaan: tanggal posyandu -> anak -> hasil pendataan
	kader.GET("/riwayat/jadwal", pelayananH.KaderRiwayatJadwal)
	kader.GET("/riwayat/jadwal/:id/anak", pelayananH.KaderRiwayatAnak)
	kader.GET("/riwayat/pendaftaran/:id", pelayananH.KaderRiwayatDetail)
	kader.GET("/rekap/tidak-hadir", rekapH.TidakHadir)
	kader.GET("/balita", balitaH.Daftar)
	kader.GET("/balita/:anak_id", balitaH.Detail)

	// bidan
	bidan := protected.Group("/bidan", middleware.RoleRequired("bidan"))
	bidan.GET("/jadwal/:id/pengukuran", pelayananH.AntreanBidan)
	bidan.GET("/pendaftaran/:id", pelayananH.DetailBidan)
	bidan.PUT("/pendaftaran/:id/catatan", pelayananH.SimpanCatatan)
	// riwayat pemeriksaan: tanggal posyandu -> anak -> hasil pendataan
	bidan.GET("/riwayat/jadwal", pelayananH.BidanRiwayatJadwal)
	bidan.GET("/riwayat/jadwal/:id/anak", pelayananH.BidanRiwayatAnak)
	bidan.GET("/riwayat/pendaftaran/:id", pelayananH.BidanRiwayatDetail)
	// vaksin susulan (diberikan di luar sesi posyandu)
	bidan.POST("/vaksin/riwayat", vaksinH.CatatRiwayat)
	bidan.DELETE("/vaksin/riwayat/:id", vaksinH.HapusRiwayat)
	bidan.GET("/balita", balitaH.Daftar)
	bidan.GET("/balita/:anak_id", balitaH.Detail)

	return r
}
