package repository

import (
	"posyandu-api/internal/models"

	"gorm.io/gorm"
)

type UserRepository struct{ db *gorm.DB }

func NewUserRepository(db *gorm.DB) *UserRepository { return &UserRepository{db} }

var namaPosyandu = map[string]string{
	"sitoluama": "Sitoluama",
	"silimbat":  "Silimbat",
	"aekbolon":  "Aek Bolon",
}

func (r *UserRepository) isiNama(u *models.User) {
	u.PosyanduNama = namaPosyandu[u.Posyandu]
}

func (r *UserRepository) Create(u *models.User) error { return r.db.Create(u).Error }

func (r *UserRepository) FindByID(id uint) (*models.User, error) {
	var u models.User
	err := r.db.First(&u, id).Error
	if err == nil {
		r.isiNama(&u)
	}
	return &u, err
}

// identifier bisa username, NIK, atau no HP
func (r *UserRepository) FindByIdentifier(idf string) (*models.User, error) {
	var u models.User
	err := r.db.Where("username = ? OR nik = ? OR no_hp = ?", idf, idf, idf).First(&u).Error
	if err == nil {
		r.isiNama(&u)
	}
	return &u, err
}

func (r *UserRepository) Exists(field, value string) bool {
	var n int64
	r.db.Model(&models.User{}).Where(field+" = ?", value).Count(&n)
	return n > 0
}

// Cek duplikat kolom pada user lain (untuk proses edit).
func (r *UserRepository) ExistsExcept(field, value string, exceptID uint) bool {
	var n int64
	r.db.Model(&models.User{}).Where(field+" = ? AND id <> ?", value, exceptID).Count(&n)
	return n > 0
}

// FindByRoles: akun dengan role tertentu pada satu posyandu.
func (r *UserRepository) FindByRoles(roles []string, posyandu string) ([]models.User, error) {
	var list []models.User
	err := r.db.Where("role IN ? AND posyandu = ?", roles, posyandu).
		Order("nama ASC").Find(&list).Error
	return list, err
}

func (r *UserRepository) Save(u *models.User) error { return r.db.Save(u).Error }

func (r *UserRepository) Delete(id uint) error {
	return r.db.Delete(&models.User{}, id).Error
}