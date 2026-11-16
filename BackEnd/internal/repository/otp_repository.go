package repository

import (
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// OtpRepository: penyimpanan kode OTP WhatsApp (tabel kode_otp).
type OtpRepository struct{ db *gorm.DB }

func NewOtpRepository(db *gorm.DB) *OtpRepository { return &OtpRepository{db} }

func (r *OtpRepository) Simpan(k *models.KodeOTP) error { return r.db.Create(k).Error }

// Terakhir: kode terbaru untuk nomor + tujuan (dipakai untuk jeda kirim ulang).
func (r *OtpRepository) Terakhir(noHP, tujuan string) (*models.KodeOTP, error) {
	var k models.KodeOTP
	err := r.db.Where("no_hp = ? AND tujuan = ?", noHP, tujuan).
		Order("created_at DESC").First(&k).Error
	return &k, err
}

// JumlahKirimSejak: banyaknya kode yang dikirim ke nomor ini sejak waktu tertentu.
func (r *OtpRepository) JumlahKirimSejak(noHP string, sejak time.Time) int64 {
	var n int64
	r.db.Model(&models.KodeOTP{}).Where("no_hp = ? AND created_at >= ?", noHP, sejak).Count(&n)
	return n
}

// HanguskanYangAktif: kode lama yang belum diverifikasi langsung kedaluwarsa
// saat kode baru dikirim, sehingga hanya kode terakhir yang berlaku.
func (r *OtpRepository) HanguskanYangAktif(noHP, tujuan string, sekarang time.Time) error {
	return r.db.Model(&models.KodeOTP{}).
		Where("no_hp = ? AND tujuan = ? AND diverifikasi_pada IS NULL AND kedaluwarsa_pada > ?", noHP, tujuan, sekarang).
		Update("kedaluwarsa_pada", sekarang).Error
}

// KodeAktif: kode terbaru yang belum diverifikasi dan belum kedaluwarsa.
func (r *OtpRepository) KodeAktif(noHP, tujuan string, sekarang time.Time) (*models.KodeOTP, error) {
	var k models.KodeOTP
	err := r.db.Where("no_hp = ? AND tujuan = ? AND diverifikasi_pada IS NULL AND kedaluwarsa_pada > ?", noHP, tujuan, sekarang).
		Order("created_at DESC").First(&k).Error
	return &k, err
}

// TambahPercobaan: catat satu kali salah ketik kode.
func (r *OtpRepository) TambahPercobaan(id uuid.UUID) error {
	return r.db.Model(&models.KodeOTP{}).Where("id = ?", id).
		Update("percobaan", gorm.Expr("percobaan + 1")).Error
}

// Hanguskan: kode tidak bisa dipakai lagi (mis. salah terlalu banyak).
func (r *OtpRepository) Hanguskan(id uuid.UUID, sekarang time.Time) error {
	return r.db.Model(&models.KodeOTP{}).Where("id = ?", id).
		Update("kedaluwarsa_pada", sekarang).Error
}

// TandaiTerverifikasi: kode cocok, simpan hash token verifikasi dan masa berlakunya.
func (r *OtpRepository) TandaiTerverifikasi(id uuid.UUID, tokenHash string, sekarang, berlakuSampai time.Time) error {
	return r.db.Model(&models.KodeOTP{}).Where("id = ?", id).Updates(map[string]any{
		"diverifikasi_pada":    sekarang,
		"token_hash":           tokenHash,
		"token_berlaku_sampai": berlakuSampai,
	}).Error
}

// CariToken: token verifikasi yang masih berlaku dan belum dipakai.
func (r *OtpRepository) CariToken(tokenHash, noHP, tujuan string, sekarang time.Time) (*models.KodeOTP, error) {
	var k models.KodeOTP
	err := r.db.Where(
		"token_hash = ? AND no_hp = ? AND tujuan = ? AND token_dipakai_pada IS NULL AND token_berlaku_sampai > ?",
		tokenHash, noHP, tujuan, sekarang,
	).First(&k).Error
	return &k, err
}

// PakaiToken: tandai token sudah dipakai. Mengembalikan false bila token
// sudah dipakai permintaan lain (mencegah satu token dipakai dua kali).
func (r *OtpRepository) PakaiToken(id uuid.UUID, sekarang time.Time) (bool, error) {
	res := r.db.Model(&models.KodeOTP{}).
		Where("id = ? AND token_dipakai_pada IS NULL", id).
		Update("token_dipakai_pada", sekarang)
	return res.RowsAffected == 1, res.Error
}

// BatalPakaiToken: kembalikan token bila proses setelahnya gagal
// (mis. NIK ternyata sudah terdaftar), agar pengguna tidak perlu minta kode baru.
func (r *OtpRepository) BatalPakaiToken(id uuid.UUID) error {
	return r.db.Model(&models.KodeOTP{}).Where("id = ?", id).
		Update("token_dipakai_pada", nil).Error
}

// CariUserByNoHP: akun pemilik nomor WhatsApp (akun yang diarsipkan tidak ikut).
func (r *OtpRepository) CariUserByNoHP(noHP string) (*models.User, error) {
	var u models.User
	err := r.db.Where("no_hp = ? AND diarsipkan_pada IS NULL", noHP).First(&u).Error
	return &u, err
}

// NoHPTerdaftar: true bila nomor sudah dipakai akun lain.
func (r *OtpRepository) NoHPTerdaftar(noHP string) bool {
	var n int64
	r.db.Model(&models.User{}).Where("no_hp = ?", noHP).Count(&n)
	return n > 0
}