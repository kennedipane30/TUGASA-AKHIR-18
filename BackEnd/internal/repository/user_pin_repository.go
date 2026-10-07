package repository

import "posyandu-api/internal/models"

// SimpanStatusLogin menyimpan jumlah gagal login dan waktu kunci akun.
func (r *UserRepository) SimpanStatusLogin(u *models.User) error {
	return r.db.Model(u).Select("GagalLogin", "TerkunciSampai").Updates(u).Error
}

// SimpanSandi menyimpan PIN/kata sandi baru dan membuka kunci akun.
func (r *UserRepository) SimpanSandi(u *models.User) error {
	return r.db.Model(u).
		Select("Password", "MustChangePassword", "GagalLogin", "TerkunciSampai").
		Updates(u).Error
}