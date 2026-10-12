package repository

import (
	"strings"
	"time"

	"posyandu-api/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type JadwalRepository struct{ db *gorm.DB }

func NewJadwalRepository(db *gorm.DB) *JadwalRepository { return &JadwalRepository{db} }

func (r *JadwalRepository) Tx(fn func(tx *JadwalRepository) error) error {
	return r.db.Transaction(func(tx *gorm.DB) error { return fn(&JadwalRepository{tx}) })
}

// pilihPosyandu mengambil kode posyandu opsional dari parameter variadic.
// Kosong berarti tanpa penyaringan (hanya untuk admin).
func pilihPosyandu(p []string) string {
	if len(p) > 0 {
		return strings.TrimSpace(p[0])
	}
	return ""
}

// subKeluargaPosyandu: subquery id keluarga pada satu posyandu.
func subKeluargaPosyandu(db *gorm.DB, posyandu string) *gorm.DB {
	return db.Model(&models.Keluarga{}).Select("id").Where("posyandu = ?", posyandu)
}

// subAnakPosyandu: subquery id anak pada satu posyandu.
func subAnakPosyandu(db *gorm.DB, posyandu string) *gorm.DB {
	return db.Model(&models.Anak{}).Select("id").
		Where("keluarga_id IN (?)", subKeluargaPosyandu(db, posyandu))
}

// ---------------------------------------------------------------- jadwal

func (r *JadwalRepository) CreateJadwal(j *models.JadwalPosyandu) error { return r.db.Create(j).Error }
func (r *JadwalRepository) SaveJadwal(j *models.JadwalPosyandu) error   { return r.db.Save(j).Error }

func (r *JadwalRepository) GetJadwal(id uuid.UUID) (*models.JadwalPosyandu, error) {
	var j models.JadwalPosyandu
	err := r.db.First(&j, "id = ?", id).Error
	return &j, err
}

// ListJadwal: jadwal yang tidak dibatalkan; posyandu opsional.
func (r *JadwalRepository) ListJadwal(posyandu ...string) ([]models.JadwalPosyandu, error) {
	list := []models.JadwalPosyandu{}
	q := r.db.Where("status <> ?", "dibatalkan")
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("posyandu = ?", p)
	}
	err := q.Order("tanggal DESC, jam_mulai DESC").Find(&list).Error
	return list, err
}

// JadwalTerdekat: jadwal berstatus terjadwal pada hari ini atau setelahnya (hariIni = YYYY-MM-DD).
func (r *JadwalRepository) JadwalTerdekat(hariIni string, posyandu ...string) (*models.JadwalPosyandu, error) {
	var j models.JadwalPosyandu
	q := r.db.Where("status = ? AND tanggal >= ?", "terjadwal", hariIni)
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("posyandu = ?", p)
	}
	err := q.Order("tanggal ASC, jam_mulai ASC").First(&j).Error
	return &j, err
}

// JadwalPadaTanggal: satu posyandu hanya boleh punya satu jadwal per tanggal.
func (r *JadwalRepository) JadwalPadaTanggal(tgl time.Time, kecuali uuid.UUID, posyandu ...string) bool {
	var n int64
	q := r.db.Model(&models.JadwalPosyandu{}).
		Where("tanggal = ? AND status <> ?", tgl.Format("2006-01-02"), "dibatalkan")
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("posyandu = ?", p)
	}
	if kecuali != uuid.Nil {
		q = q.Where("id <> ?", kecuali)
	}
	q.Count(&n)
	return n > 0
}

// ---------------------------------------------------------------- pendaftaran

func (r *JadwalRepository) CreatePendaftaran(p *models.Pendaftaran) error { return r.db.Create(p).Error }
func (r *JadwalRepository) SavePendaftaran(p *models.Pendaftaran) error   { return r.db.Save(p).Error }

func (r *JadwalRepository) FindPendaftaran(jadwalID, anakID uuid.UUID) (*models.Pendaftaran, error) {
	var p models.Pendaftaran
	err := r.db.Where("jadwal_id = ? AND anak_id = ?", jadwalID, anakID).First(&p).Error
	return &p, err
}

func (r *JadwalRepository) GetPendaftaran(id uuid.UUID) (*models.Pendaftaran, error) {
	var p models.Pendaftaran
	err := r.db.Preload("Anak").Preload("Jadwal").First(&p, "id = ?", id).Error
	return &p, err
}

func (r *JadwalRepository) NomorAntreanBerikut(jadwalID uuid.UUID) int16 {
	var maks int
	r.db.Model(&models.Pendaftaran{}).
		Where("jadwal_id = ?", jadwalID).
		Select("COALESCE(MAX(nomor_antrean), 0)").Scan(&maks)
	return int16(maks + 1)
}

func (r *JadwalRepository) ListPendaftaranJadwal(jadwalID uuid.UUID, status ...string) ([]models.Pendaftaran, error) {
	list := []models.Pendaftaran{}
	q := r.db.Preload("Anak").Where("jadwal_id = ?", jadwalID)
	if len(status) > 0 {
		q = q.Where("status_kehadiran IN ?", status)
	}
	err := q.Order("nomor_antrean ASC").Find(&list).Error
	return list, err
}

func (r *JadwalRepository) ListPendaftaranAnak(anakIDs []uuid.UUID, jadwalID uuid.UUID) ([]models.Pendaftaran, error) {
	list := []models.Pendaftaran{}
	if len(anakIDs) == 0 {
		return list, nil
	}
	err := r.db.Where("jadwal_id = ? AND anak_id IN ?", jadwalID, anakIDs).Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- anak

func (r *JadwalRepository) GetAnak(id uuid.UUID) (*models.Anak, error) {
	var a models.Anak
	err := r.db.First(&a, "id = ?", id).Error
	return &a, err
}

// PosyanduAnak: kode posyandu tempat anak terdaftar (melalui keluarga).
func (r *JadwalRepository) PosyanduAnak(anakID uuid.UUID) (string, error) {
	var pos string
	err := r.db.Model(&models.Keluarga{}).
		Select("posyandu").
		Where("id IN (?)", r.db.Model(&models.Anak{}).Select("keluarga_id").Where("id = ?", anakID)).
		Scan(&pos).Error
	return pos, err
}

func (r *JadwalRepository) AnakKeluarga(keluargaID uuid.UUID) ([]models.Anak, error) {
	list := []models.Anak{}
	err := r.db.Where("keluarga_id = ? AND status = ?", keluargaID, "aktif").
		Order("tanggal_lahir DESC").Find(&list).Error
	return list, err
}

// CariAnak: posyandu opsional; jika diisi, hanya anak dari posyandu tersebut.
func (r *JadwalRepository) CariAnak(kata string, posyandu ...string) ([]models.Anak, error) {
	list := []models.Anak{}
	like := "%" + strings.ToLower(kata) + "%"
	q := r.db.Where("status = ? AND (LOWER(nama) LIKE ? OR nik = ?)", "aktif", like, kata)
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, p))
	}
	err := q.Order("nama").Limit(20).Find(&list).Error
	return list, err
}

func (r *JadwalRepository) GetAnakByKode(kode string, posyandu ...string) (*models.Anak, error) {
	var a models.Anak
	q := r.db.Where("kode_qr = ? AND status = ?", kode, "aktif")
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, p))
	}
	err := q.First(&a).Error
	return &a, err
}