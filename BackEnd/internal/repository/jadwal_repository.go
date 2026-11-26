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
func pilihPosyandu(p []string) string {
	if len(p) > 0 {
		return strings.TrimSpace(p[0])
	}
	return ""
}

func subKeluargaPosyandu(db *gorm.DB, posyandu string) *gorm.DB {
	return db.Model(&models.Keluarga{}).Select("id").Where("posyandu = ?", posyandu)
}

func subBalitaPosyandu(db *gorm.DB, posyandu string) *gorm.DB {
	return db.Model(&models.Balita{}).Select("id").
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

func (r *JadwalRepository) DeleteJadwal(id uuid.UUID) error {
	return r.db.Delete(&models.JadwalPosyandu{}, "id = ?", id).Error
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

// JadwalMendatang: jadwal terjadwal mulai hari ini, berurutan.
// Penyaringan jadwal yang sudah lewat jam selesai dilakukan di service.
func (r *JadwalRepository) JadwalMendatang(hariIni string, posyandu ...string) ([]models.JadwalPosyandu, error) {
	list := []models.JadwalPosyandu{}
	q := r.db.Where("status = ? AND tanggal >= ?", "terjadwal", hariIni)
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("posyandu = ?", p)
	}
	err := q.Order("tanggal ASC, jam_mulai ASC").Find(&list).Error
	return list, err
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

type RingkasanKehadiran struct {
	Terdaftar  int
	Checkin    int
	Batal      int
	TidakHadir int
}

// RingkasanPendaftaran: jumlah pendaftaran per status untuk beberapa jadwal.
func (r *JadwalRepository) RingkasanPendaftaran(ids []uuid.UUID) (map[uuid.UUID]RingkasanKehadiran, error) {
	out := map[uuid.UUID]RingkasanKehadiran{}
	if len(ids) == 0 {
		return out, nil
	}
	type baris struct {
		JadwalID uuid.UUID
		Status   string
		N        int
	}
	var rows []baris
	err := r.db.Model(&models.Pendaftaran{}).
		Select("jadwal_id, status_kehadiran AS status, COUNT(*) AS n").
		Where("jadwal_id IN ?", ids).
		Group("jadwal_id, status_kehadiran").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	for _, b := range rows {
		x := out[b.JadwalID]
		switch b.Status {
		case "terdaftar":
			x.Terdaftar += b.N
		case "sudah_checkin":
			x.Checkin += b.N
		case "batal":
			x.Batal += b.N
		case "tidak_hadir":
			x.TidakHadir += b.N
		}
		out[b.JadwalID] = x
	}
	return out, nil
}

// ---------------------------------------------------------------- pendaftaran

func (r *JadwalRepository) CreatePendaftaran(p *models.Pendaftaran) error {
	return r.db.Create(p).Error
}
func (r *JadwalRepository) SavePendaftaran(p *models.Pendaftaran) error { return r.db.Save(p).Error }

func (r *JadwalRepository) FindPendaftaran(jadwalID, balitaID uuid.UUID) (*models.Pendaftaran, error) {
	var p models.Pendaftaran
	err := r.db.Where("jadwal_id = ? AND balita_id = ?", jadwalID, balitaID).First(&p).Error
	return &p, err
}

func (r *JadwalRepository) GetPendaftaran(id uuid.UUID) (*models.Pendaftaran, error) {
	var p models.Pendaftaran
	err := r.db.Preload("Balita").Preload("Jadwal").First(&p, "id = ?", id).Error
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
	q := r.db.Preload("Balita").Where("jadwal_id = ?", jadwalID)
	if len(status) > 0 {
		q = q.Where("status_kehadiran IN ?", status)
	}
	err := q.Order("nomor_antrean ASC").Find(&list).Error
	return list, err
}

// PendaftaranDiukur: pendaftaran yang datanya sudah diukur kader.
func (r *JadwalRepository) PendaftaranDiukur(ids []uuid.UUID) (map[uuid.UUID]bool, error) {
	return r.petaPendaftaran(&models.Pengukuran{}, ids)
}

// PendaftaranDicatatBidan: pendaftaran yang catatan pemeriksaannya sudah disimpan bidan.
func (r *JadwalRepository) PendaftaranDicatatBidan(ids []uuid.UUID) (map[uuid.UUID]bool, error) {
	return r.petaPendaftaran(&models.PemeriksaanBidan{}, ids)
}

// petaPendaftaran: id pendaftaran (dari [ids]) yang memiliki baris pada tabel [model].
func (r *JadwalRepository) petaPendaftaran(model any, ids []uuid.UUID) (map[uuid.UUID]bool, error) {
	hasil := map[uuid.UUID]bool{}
	if len(ids) == 0 {
		return hasil, nil
	}
	var kolom []string
	if err := r.db.Model(model).Where("pendaftaran_id IN ?", ids).
		Pluck("pendaftaran_id::text", &kolom).Error; err != nil {
		return nil, err
	}
	for _, k := range kolom {
		if id, err := uuid.Parse(k); err == nil {
			hasil[id] = true
		}
	}
	return hasil, nil
}

func (r *JadwalRepository) ListPendaftaranBalita(balitaIDs []uuid.UUID, jadwalID uuid.UUID) ([]models.Pendaftaran, error) {
	list := []models.Pendaftaran{}
	if len(balitaIDs) == 0 {
		return list, nil
	}
	err := r.db.Where("jadwal_id = ? AND balita_id IN ?", jadwalID, balitaIDs).Find(&list).Error
	return list, err
}

// ---------------------------------------------------------------- balita

func (r *JadwalRepository) GetBalita(id uuid.UUID) (*models.Balita, error) {
	var a models.Balita
	err := r.db.First(&a, "id = ?", id).Error
	return &a, err
}

// PosyanduBalita: kode posyandu tempat balita terdaftar (melalui keluarga).
func (r *JadwalRepository) PosyanduBalita(balitaID uuid.UUID) (string, error) {
	var pos string
	err := r.db.Model(&models.Keluarga{}).
		Select("posyandu").
		Where("id IN (?)", r.db.Model(&models.Balita{}).Select("keluarga_id").Where("id = ?", balitaID)).
		Scan(&pos).Error
	return pos, err
}

func (r *JadwalRepository) BalitaKeluarga(keluargaID uuid.UUID) ([]models.Balita, error) {
	list := []models.Balita{}
	err := r.db.Where("keluarga_id = ? AND status = ?", keluargaID, "aktif").
		Order("tanggal_lahir DESC").Find(&list).Error
	return list, err
}

func (r *JadwalRepository) CariBalita(kata string, posyandu ...string) ([]models.Balita, error) {
	list := []models.Balita{}
	like := "%" + strings.ToLower(kata) + "%"
	q := r.db.Where("status = ? AND (LOWER(nama) LIKE ? OR nik = ?)", "aktif", like, kata)
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, p))
	}
	err := q.Order("nama").Limit(20).Find(&list).Error
	return list, err
}

func (r *JadwalRepository) GetBalitaByKode(kode string, posyandu ...string) (*models.Balita, error) {
	var a models.Balita
	q := r.db.Where("kode_qr = ? AND status = ?", kode, "aktif")
	if p := pilihPosyandu(posyandu); p != "" {
		q = q.Where("keluarga_id IN (?)", subKeluargaPosyandu(r.db, p))
	}
	err := q.First(&a).Error
	return &a, err
}