package repository

import (
	"posyandu-api/internal/models"
	"gorm.io/gorm"
)

type UserRepository struct{ db *gorm.DB }

func NewUserRepository(db *gorm.DB) *UserRepository { return &UserRepository{db} }

func (r *UserRepository) Create(u *models.User) error { return r.db.Create(u).Error }

func (r *UserRepository) FindByID(id uint) (*models.User, error) {
	var u models.User
	return &u, r.db.First(&u, id).Error
}

// identifier bisa username, NIK, atau no HP
func (r *UserRepository) FindByIdentifier(idf string) (*models.User, error) {
	var u models.User
	err := r.db.Where("username = ? OR nik = ? OR no_hp = ?", idf, idf, idf).First(&u).Error
	return &u, err
}

func (r *UserRepository) Exists(field, value string) bool {
	var n int64
	r.db.Model(&models.User{}).Where(field+" = ?", value).Count(&n)
	return n > 0
}