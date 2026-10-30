package repository

import (
	"errors"
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type NotifikasiRepository struct{ db *gorm.DB }

func NewNotifikasiRepository(db *gorm.DB) *NotifikasiRepository { return &NotifikasiRepository{db} }

// ---------------------------------------------------------------- jadwal

func (r *NotifikasiRepository) GetJadwal(id uuid.UUID) (*models.JadwalPosyandu, error) {
	var j models.JadwalPosyandu
	err := r.db.First(&j, "id = ?", id).Error
	return &j, err
}

// JadwalRentang: jadwal berstatus terjadwal pada rentang tanggal (YYYY-MM-DD).
func (r *NotifikasiRepository) JadwalRentang(dari, sampai string) ([]models.JadwalPosyandu, error) {
	list := []models.JadwalPosyandu{}
	err := r.db.Where("status = ? AND tanggal BETWEEN ? AND ?", "terjadwal", dari, sampai).
		Order("tanggal ASC, jam_mulai ASC").Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- penerima

// Penerima: akun aktif pada satu posyandu dengan role tertentu.
func (r *NotifikasiRepository) Penerima(posyandu string, roles []string) ([]models.User, error) {
	list := []models.User{}
	if posyandu == "" || len(roles) == 0 {
		return list, nil
	}
	err := r.db.Where("posyandu = ? AND role IN ? AND is_active = ?", posyandu, roles, true).
		Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- notifikasi

// KunciSudahAda: notifikasi dengan kunci ini sudah pernah dibuat untuk minimal satu pengguna.
func (r *NotifikasiRepository) KunciSudahAda(kunci string) bool {
	var n int64
	r.db.Unscoped().Model(&models.Notifikasi{}).Where("kunci = ?", kunci).Limit(1).Count(&n)
	return n > 0
}

// SimpanJikaBaru: simpan notifikasi; bernilai false bila (user_id, kunci) sudah ada.
func (r *NotifikasiRepository) SimpanJikaBaru(n *models.Notifikasi) (bool, error) {
	res := r.db.Clauses(clause.OnConflict{DoNothing: true}).Create(n)
	if res.Error != nil {
		return false, res.Error
	}
	return res.RowsAffected > 0, nil
}

func (r *NotifikasiRepository) dasarList(userID uint, hanyaBelumDibaca bool) *gorm.DB {
	q := r.db.Model(&models.Notifikasi{}).Where("user_id = ?", userID)
	if hanyaBelumDibaca {
		q = q.Where("sudah_dibaca = ?", false)
	}
	return q
}

func (r *NotifikasiRepository) List(userID uint, hanyaBelumDibaca bool, limit, offset int) ([]models.Notifikasi, int64, error) {
	list := []models.Notifikasi{}
	var total int64
	if err := r.dasarList(userID, hanyaBelumDibaca).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	err := r.dasarList(userID, hanyaBelumDibaca).
		Order("created_at DESC").Limit(limit).Offset(offset).Find(&list).Error
	return list, total, err
}

func (r *NotifikasiRepository) JumlahBelumDibaca(userID uint) (int64, error) {
	var n int64
	err := r.dasarList(userID, true).Count(&n).Error
	return n, err
}

func (r *NotifikasiRepository) GetMilik(userID uint, id uuid.UUID) (*models.Notifikasi, error) {
	var n models.Notifikasi
	err := r.db.Where("id = ? AND user_id = ?", id, userID).First(&n).Error
	return &n, err
}

func (r *NotifikasiRepository) TandaiDibaca(userID uint, id uuid.UUID) (bool, error) {
	res := r.db.Model(&models.Notifikasi{}).
		Where("id = ? AND user_id = ?", id, userID).
		Updates(map[string]any{
			"sudah_dibaca": true,
			"dibaca_pada":  gorm.Expr("COALESCE(dibaca_pada, ?)", time.Now()),
			"version":      gorm.Expr("version + 1"),
		})
	return res.RowsAffected > 0, res.Error
}

func (r *NotifikasiRepository) TandaiSemuaDibaca(userID uint) (int64, error) {
	res := r.db.Model(&models.Notifikasi{}).
		Where("user_id = ? AND sudah_dibaca = ?", userID, false).
		Updates(map[string]any{
			"sudah_dibaca": true,
			"dibaca_pada":  time.Now(),
			"version":      gorm.Expr("version + 1"),
		})
	return res.RowsAffected, res.Error
}

func (r *NotifikasiRepository) Hapus(userID uint, id uuid.UUID) (bool, error) {
	res := r.db.Where("id = ? AND user_id = ?", id, userID).Delete(&models.Notifikasi{})
	return res.RowsAffected > 0, res.Error
}

// ---------------------------------------------------------------- token perangkat

func (r *NotifikasiRepository) TokenPerangkat(userIDs []uint) ([]models.Perangkat, error) {
	list := []models.Perangkat{}
	if len(userIDs) == 0 {
		return list, nil
	}
	err := r.db.Where("user_id IN ? AND token_fcm <> ''", userIDs).Find(&list).Error
	return list, err
}

// SimpanToken: satu token hanya boleh dimiliki satu akun (akun terakhir yang login di perangkat itu).
func (r *NotifikasiRepository) SimpanToken(userID uint, token, platform, nama, versi string) (*models.Perangkat, error) {
	var p models.Perangkat
	err := r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&models.Perangkat{}).
			Where("token_fcm = ? AND user_id <> ?", token, userID).
			Update("token_fcm", "").Error; err != nil {
			return err
		}
		now := time.Now()
		err := tx.Where("user_id = ? AND token_fcm = ?", userID, token).First(&p).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			p = models.Perangkat{
				UserID:          userID,
				TokenFCM:        token,
				Platform:        platform,
				NamaPerangkat:   nama,
				VersiAplikasi:   versi,
				TokenDiperbarui: &now,
			}
			return tx.Create(&p).Error
		}
		if err != nil {
			return err
		}
		if platform != "" {
			p.Platform = platform
		}
		if nama != "" {
			p.NamaPerangkat = nama
		}
		if versi != "" {
			p.VersiAplikasi = versi
		}
		p.TokenDiperbarui = &now
		return tx.Save(&p).Error
	})
	return &p, err
}

func (r *NotifikasiRepository) HapusToken(userID uint, token string) error {
	return r.db.Model(&models.Perangkat{}).
		Where("user_id = ? AND token_fcm = ?", userID, token).
		Update("token_fcm", "").Error
}

func (r *NotifikasiRepository) KosongkanToken(token string) error {
	return r.db.Model(&models.Perangkat{}).
		Where("token_fcm = ?", token).
		Update("token_fcm", "").Error
}