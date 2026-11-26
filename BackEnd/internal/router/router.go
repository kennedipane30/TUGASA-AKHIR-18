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
	imunisasiRepo := repository.NewImunisasiRepository(db)
	rekapRepo := repository.NewRekapRepository(db)
	kbmRepo := repository.NewKbmRepository(db)
	balitaRepo := repository.NewBalitaRepository(db)
	skdnRepo := repository.NewSkdnRepository(db)
	logAktivitasRepo := repository.NewLogAktivitasRepository(db)
	laporanBulananRepo := repository.NewLaporanBulananRepository(db)
	balitaArsipRepo := repository.NewBalitaArsipRepository(db)
	kpspRepo := repository.NewKpspRepository(db)

	// service
	jadwalSvc := service.NewJadwalService(jadwalRepo, keluargaRepo)
	notifSvc := service.NewNotifikasiService(notifRepo, service.NewPushService())
	giziSvc := service.NewStatusGiziService(giziRepo)
	pelayananSvc := service.NewPelayananService(jadwalRepo, pelayananRepo, keluargaRepo)
	pelayananSvc.SetStatusGizi(giziSvc)
	imunisasiSvc := service.NewImunisasiService(imunisasiRepo)
	pelayananSvc.SetImunisasi(imunisasiSvc)
	kbmSvc := service.NewKbmService(kbmRepo)
	kbmSvc.SetNotifikasi(notifSvc)
	pelayananSvc.SetKbm(kbmSvc)
	// rencana & pengingat imunisasi, Vitamin A, dan obat cacing (ikut jadwal posyandu)
	notifSvc.SetImunisasi(imunisasiRepo)
	jadwalSvc.SetNotifikasi(notifSvc)
	pelayananSvc.SetNotifikasi(notifSvc) // "Rencana Hari Ini" di catatan bidan
	imunisasiSvc.SetNotifikasi(notifSvc) // laporan reaksi imunisasi (KIPI) ke bidan

	// master jenis imunisasi & jadwal imunisasi rutin Kemenkes (dibuat/diperbarui otomatis)
	imunisasiSvc.SiapkanMaster()

	// pengingat otomatis (24 jam sebelum mulai, check-in dibuka, kesehatan balita 07.00 WIB)
	go notifSvc.JalankanPengingat(context.Background())
	// hitung status gizi, lalu penilaian N/T (KBM), 2T, BGM untuk pengukuran lama
	go func() {
		giziSvc.HitungDataLama()
		kbmSvc.HitungDataLama()
	}()
	// arsip otomatis balita yang sudah berusia 60 bulan (lulus balita), dicek setiap hari
	balitaArsipSvc := service.NewBalitaArsipService(balitaArsipRepo)
	go balitaArsipSvc.JalankanLulusBalita(context.Background())

	// handler
	authH := handler.NewAuthHandler(service.NewAuthService(userRepo))
	pinH := handler.NewPinHandler(service.NewPinService(userRepo))
	keluargaH := handler.NewKeluargaHandler(service.NewKeluargaService(keluargaRepo))
	jadwalH := handler.NewJadwalHandler(jadwalSvc, notifSvc)
	pelayananH := handler.NewPelayananHandler(pelayananSvc)
	notifH := handler.NewNotifikasiHandler(notifSvc)
	imunisasiH := handler.NewImunisasiHandler(imunisasiSvc)
	kpspH := handler.NewKpspHandler(service.NewKpspService(kpspRepo))
	rekapH := handler.NewRekapHandler(service.NewRekapService(rekapRepo))
	balitaH := handler.NewBalitaHandler(service.NewBalitaService(balitaRepo, imunisasiRepo))
	skdnH := handler.NewSkdnHandler(service.NewSkdnService(rekapRepo, skdnRepo))
	// laporan bulanan posyandu (sekretaris & bidan)
	// rujukan balita (bidan membuat, orang tua melihat)
	rujukanSvc := service.NewRujukanService(repository.NewRujukanRepository(db))
	rujukanSvc.SetNotifikasi(notifSvc)
	rujukanH := handler.NewRujukanHandler(rujukanSvc)
	laporanBulananH := handler.NewLaporanBulananHandler(service.NewLaporanBulananService(
		rekapRepo, laporanBulananRepo, service.NewRekapService(rekapRepo), service.NewSkdnService(rekapRepo, skdnRepo)))
	kaderKeluargaH := handler.NewKaderKeluargaHandler(service.NewKaderKeluargaService(userRepo, keluargaRepo))
	balitaArsipH := handler.NewBalitaArsipHandler(balitaArsipSvc)
	logAktivitasH := handler.NewLogAktivitasHandler(logAktivitasRepo)
	// OTP WhatsApp: registrasi orang tua & lupa PIN
	otpH := handler.NewOtpHandler(service.NewOtpService(
		repository.NewOtpRepository(db), userRepo, service.NewAuthService(userRepo), service.NewWaService()))

	api := r.Group("/api/v1")
	// log aktivitas: mencatat aksi semua role (POST/PUT/PATCH/DELETE yang berhasil)
	api.Use(middleware.CatatLogAktivitas(logAktivitasRepo))
	api.GET("/posyandu", authH.ListPosyandu) // publik, untuk registrasi
	api.POST("/auth/register", authH.Register)
	api.POST("/auth/login", pinH.Login) // identitas + PIN 6 digit (semua role)
	// OTP WhatsApp (publik)
	api.POST("/auth/otp/kirim", otpH.Kirim)           // {no_hp, tujuan: registrasi | reset_pin}
	api.POST("/auth/otp/verifikasi", otpH.Verifikasi) // {no_hp, tujuan, kode} -> token_otp
	api.POST("/auth/register-otp", otpH.Register)     // registrasi + token_otp
	api.POST("/auth/lupa-pin", otpH.LupaPIN)          // {no_hp, pin_baru, token_otp}

	// semua role (sudah login); posyandu akun dimuat di middleware
	protected := api.Group("/", middleware.AuthRequired(), middleware.Posyandu(userRepo))
	protected.GET("/auth/me", authH.Me)
	protected.POST("/auth/ubah-pin", pinH.UbahPIN)
	protected.GET("/jadwal", jadwalH.List)
	protected.GET("/jadwal/terdekat", jadwalH.Terdekat)
	protected.GET("/imunisasi", pelayananH.ListJenisImunisasi)
	protected.GET("/imunisasi/jadwal", imunisasiH.JadwalMaster)
	protected.GET("/imunisasi/balita/:balita_id", imunisasiH.KartuBalita)
	protected.POST("/imunisasi/bukti", imunisasiH.UnggahBukti) // orang tua & bidan (dicek di handler)
	protected.GET("/imunisasi/bukti/:nama", imunisasiH.AmbilBukti)

	// notifikasi (semua role)
	protected.GET("/notifikasi", notifH.List)
	protected.GET("/notifikasi/jumlah-belum-dibaca", notifH.JumlahBelumDibaca)
	protected.POST("/notifikasi/baca-semua", notifH.BacaSemua)
	protected.PATCH("/notifikasi/:id/baca", notifH.Baca)
	protected.DELETE("/notifikasi/:id", notifH.Hapus)
	protected.POST("/notifikasi/hapus", notifH.HapusBanyak)      // hapus notifikasi terpilih
	protected.POST("/notifikasi/hapus-semua", notifH.HapusSemua) // ?sudah_dibaca=true: hanya yang sudah dibaca
	protected.POST("/perangkat/token", notifH.SimpanToken)
	protected.DELETE("/perangkat/token", notifH.HapusToken)

	// sekretaris (satu akun per desa, hanya mengelola desanya sendiri)
	sekretaris := protected.Group("/sekretaris", middleware.RoleRequired("sekretaris"))
	sekretaris.POST("/users", authH.CreateStaff)
	sekretaris.GET("/users", authH.ListStaff)
	sekretaris.PUT("/users/:id", authH.UpdateStaff)
	sekretaris.PATCH("/users/:id/aktif", authH.SetStaffActive)
	sekretaris.DELETE("/users/:id", authH.DeleteStaff)
	sekretaris.POST("/users/:id/reset-pin", pinH.ResetPIN)
	sekretaris.POST("/jadwal", jadwalH.Buat)
	sekretaris.GET("/jadwal/riwayat", jadwalH.Riwayat) // harus sebelum /jadwal/:id
	sekretaris.PUT("/jadwal/:id", jadwalH.Ubah)
	sekretaris.DELETE("/jadwal/:id", jadwalH.Hapus)
	sekretaris.POST("/jadwal/:id/batalkan", jadwalH.Batalkan)
	sekretaris.GET("/qr", jadwalH.QRPosyandu) // QR tetap, satu per posyandu
	sekretaris.GET("/jadwal/:id/qr", jadwalH.QRJadwal)
	// riwayat pemeriksaan: tanggal posyandu -> balita -> hasil pendataan
	sekretaris.GET("/riwayat/jadwal", pelayananH.SekretarisRiwayatJadwal)
	sekretaris.GET("/riwayat/jadwal/:id/balita", pelayananH.SekretarisRiwayatBalita)
	sekretaris.GET("/riwayat/pendaftaran/:id", pelayananH.SekretarisRiwayatDetail)
	sekretaris.GET("/imunisasi/statistik", imunisasiH.Statistik)
	// rekap posyandu: status gizi, Vitamin A & obat cacing, balita tidak hadir
	sekretaris.GET("/rekap/gizi", rekapH.Gizi)
	sekretaris.GET("/rekap/suplemen", rekapH.Suplemen)
	sekretaris.GET("/rekap/tidak-hadir", rekapH.TidakHadir)
	// semua balita posyandu
	sekretaris.GET("/balita", balitaH.Daftar)
	sekretaris.GET("/balita/:balita_id", balitaH.Detail)
	// ringkasan penimbangan (SKDN)
	sekretaris.GET("/skdn", skdnH.Hitung)
	sekretaris.GET("/laporan-bulanan", laporanBulananH.Laporan)
	// log aktivitas semua role di posyandu sekretaris
	sekretaris.GET("/log-aktivitas", logAktivitasH.Daftar)

	// orang tua (check-in dengan memindai QR tetap posyandu)
	ortu := protected.Group("/", middleware.RoleRequired("orang_tua"))
	ortu.GET("/keluarga/saya", keluargaH.Get)
	ortu.PUT("/keluarga/saya", keluargaH.SimpanProfil)
	ortu.POST("/keluarga/saya/balita", keluargaH.TambahBalita)
	ortu.PUT("/keluarga/saya/balita/:id", keluargaH.UbahBalita)
	ortu.DELETE("/keluarga/saya/balita/:id", keluargaH.HapusBalita)
	ortu.GET("/keluarga", keluargaH.Get)
	ortu.PUT("/keluarga", keluargaH.SimpanProfil)
	ortu.POST("/keluarga/balita", keluargaH.TambahBalita)
	ortu.PUT("/keluarga/balita/:id", keluargaH.UbahBalita)
	ortu.DELETE("/keluarga/balita/:id", keluargaH.HapusBalita)
	ortu.POST("/jadwal/:id/daftar", jadwalH.Daftar)
	ortu.POST("/jadwal/:id/batal", jadwalH.BatalDaftar)
	ortu.POST("/jadwal/:id/scan", jadwalH.Scan)
	ortu.GET("/jadwal/:id/kartu", jadwalH.Kartu)
	ortu.GET("/riwayat", pelayananH.Riwayat)
	// laporan reaksi setelah imunisasi (riwayat imunisasi awal dicatat bidan)
	ortu.POST("/imunisasi/riwayat/:id/kipi", imunisasiH.LaporKipi)
	// rujukan balita (lihat & unduh surat)
	ortu.GET("/rujukan", rujukanH.DaftarOrangTua)
	ortu.GET("/rujukan/:id", rujukanH.DetailOrangTua)

	// kader (menampilkan QR tetap posyandu, bukan memindai)
	kader := protected.Group("/kader", middleware.RoleRequired("kader"))
	kader.GET("/cari-balita", jadwalH.CariBalita)
	kader.POST("/users/:id/reset-pin", pinH.ResetPIN) // hanya akun orang tua
	kader.GET("/qr", jadwalH.QRPosyandu)              // QR tetap, satu per posyandu
	kader.GET("/jadwal/:id/qr", jadwalH.QRJadwal)
	kader.POST("/jadwal/:id/walkin", jadwalH.WalkIn)
	kader.POST("/pendaftaran/:id/checkin", jadwalH.CheckinManual)
	kader.GET("/jadwal/:id/antrean", pelayananH.AntreanKader)
	kader.GET("/pendaftaran/:id/pengukuran", pelayananH.PengukuranKader)
	kader.PUT("/pendaftaran/:id/pengukuran", pelayananH.CatatPengukuran)
	// riwayat pemeriksaan: tanggal posyandu -> balita -> hasil pendataan
	kader.GET("/riwayat/jadwal", pelayananH.KaderRiwayatJadwal)
	kader.GET("/riwayat/jadwal/:id/balita", pelayananH.KaderRiwayatBalita)
	kader.GET("/riwayat/pendaftaran/:id", pelayananH.KaderRiwayatDetail)
	kader.GET("/rekap/tidak-hadir", rekapH.TidakHadir)
	kader.GET("/balita", balitaH.Daftar)
	kader.GET("/balita/:balita_id", balitaH.Detail)
	kader.PUT("/balita/:balita_id/arsip", balitaArsipH.Arsipkan)    // pindah | meninggal | lainnya
	kader.PUT("/balita/:balita_id/aktifkan", balitaArsipH.Aktifkan) // batalkan arsip
	// Tambahkan Akun & Data Keluarga oleh kader (orang tua tanpa akun / tanpa HP)
	kader.GET("/cek-akun", kaderKeluargaH.CekAkun) // ?nik=&no_hp= : cek langsung saat diisi
	kader.GET("/keluarga", kaderKeluargaH.Cari)    // ?cari= nama ibu / NIK / No. HP / nama balita
	kader.POST("/keluarga", kaderKeluargaH.Tambah) // akun + data keluarga + satu/lebih balita
	kader.GET("/keluarga/:id", kaderKeluargaH.Detail)
	kader.PUT("/keluarga/:id", kaderKeluargaH.UbahProfil)
	kader.POST("/keluarga/:id/balita", kaderKeluargaH.TambahBalita)
	kader.PUT("/keluarga/:id/balita/:balita_id", kaderKeluargaH.UbahBalita)
	// Daftarkan balita ke sesi posyandu hari ini (walk-in)
	kader.GET("/daftar-balita", jadwalH.CariBalitaSesi) // ?cari= nama balita / nama orang tua
	kader.POST("/daftar-balita/:balita_id", jadwalH.DaftarkanBalita)

	// bidan
	bidan := protected.Group("/bidan", middleware.RoleRequired("bidan"))
	bidan.GET("/jadwal/:id/pengukuran", pelayananH.AntreanBidan)
	bidan.GET("/pendaftaran/:id", pelayananH.DetailBidan)
	bidan.PUT("/pendaftaran/:id/catatan", pelayananH.SimpanCatatan)
	// riwayat pemeriksaan: tanggal posyandu -> balita -> hasil pendataan
	bidan.GET("/riwayat/jadwal", pelayananH.BidanRiwayatJadwal)
	bidan.GET("/riwayat/jadwal/:id/balita", pelayananH.BidanRiwayatBalita)
	bidan.GET("/riwayat/pendaftaran/:id", pelayananH.BidanRiwayatDetail)
	// imunisasi susulan (diberikan di luar sesi posyandu)
	bidan.POST("/imunisasi/riwayat", imunisasiH.CatatRiwayat)
	bidan.DELETE("/imunisasi/riwayat/:id", imunisasiH.HapusRiwayat)
	bidan.PUT("/imunisasi/riwayat/:id/konfirmasi", imunisasiH.KonfirmasiRiwayat)
	bidan.PUT("/imunisasi/riwayat/:id/kipi", imunisasiH.TindakLanjutKipi)
	bidan.POST("/imunisasi/balita/:balita_id/konfirmasi-selesai", imunisasiH.SelesaiKonfirmasi)
	// riwayat imunisasi sebelum posyandu (kunjungan pertama) & imunisasi di luar program
	bidan.POST("/imunisasi/balita/:balita_id/riwayat-awal", imunisasiH.CatatRiwayatAwal)
	bidan.DELETE("/imunisasi/mandiri/:id", imunisasiH.HapusImunisasiMandiri)
	// KPSP (skrining perkembangan): ambil 10 pertanyaan sesuai umur balita.
	// Pengisiannya ikut tersimpan lewat PUT /bidan/pendaftaran/:id/catatan.
	bidan.GET("/kpsp/lembar", kpspH.Lembar)
	bidan.GET("/balita", balitaH.Daftar)
	bidan.GET("/balita-berisiko", balitaH.Berisiko)
	bidan.GET("/balita/:balita_id", balitaH.Detail)
	// ringkasan penimbangan (SKDN)
	bidan.GET("/skdn", skdnH.Hitung)
	bidan.GET("/laporan-bulanan", laporanBulananH.Laporan)
	// surat rujukan
	bidan.GET("/rujukan", rujukanH.DaftarBidan) // ?status=aktif|selesai
	bidan.POST("/rujukan", rujukanH.Buat)
	bidan.GET("/rujukan/:id", rujukanH.DetailBidan)
	bidan.PUT("/rujukan/:id", rujukanH.Ubah)
	bidan.DELETE("/rujukan/:id", rujukanH.Hapus)
	bidan.PUT("/rujukan/:id/balik", rujukanH.CatatBalik)
	bidan.POST("/rujukan/:id/batal", rujukanH.Batal)
	bidan.GET("/rujukan-balita", rujukanH.CariBalita)            // ?cari=nama/NIK
	bidan.GET("/rujukan-balita/:balita_id", rujukanH.DataBalita) // data balita otomatis
	// rekap posyandu: status gizi, Vitamin A & obat cacing, balita tidak hadir
	// (sama dengan sekretaris; data dibatasi ke posyandu akun bidan)
	bidan.GET("/rekap/gizi", rekapH.Gizi)
	bidan.GET("/rekap/suplemen", rekapH.Suplemen)
	bidan.GET("/rekap/tidak-hadir", rekapH.TidakHadir)

	return r
}