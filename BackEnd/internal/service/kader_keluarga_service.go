package service

import (
	"errors"
	"fmt"
	"strings"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"
	"posyandu-api/internal/utils"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ============================================================================
// TAMBAHKAN AKUN & DATA KELUARGA OLEH KADER
//
// Untuk orang tua yang belum punya akun (termasuk yang tidak punya HP).
// Aturan validasi memakai fungsi yang sama dengan alur orang tua:
//   - akun   : sama dengan Register (NIK 16 digit, No. HP, PIN 6 digit)
//   - profil : profilData()  (sama dengan halaman Data Orang Tua)
//   - anak   : buatAnak()    (sama dengan halaman Data Anak)
// PIN disebutkan orang tua; tidak wajib diganti saat login pertama.
// ============================================================================

type KaderKeluargaService struct {
	users *repository.UserRepository
	kel   *repository.KeluargaRepository
	klg   *KeluargaService
}

func NewKaderKeluargaService(u *repository.UserRepository, k *repository.KeluargaRepository) *KaderKeluargaService {
	return &KaderKeluargaService{users: u, kel: k, klg: NewKeluargaService(k)}
}

// posKader: posyandu akun kader (wajib ada dan valid).
func posKader(pos string) (string, error) {
	if err := wajibPosyandu(pos); err != nil {
		return "", err
	}
	p, ok := models.NormalisasiPosyandu(pos)
	if !ok {
		return "", terlarang("posyandu akun tidak valid")
	}
	return p, nil
}

// keAnak: beri keterangan "Anak ke-n" pada pesan validasi data anak.
func keAnak(i int, err error) error {
	var ve *ValidationError
	if errors.As(err, &ve) {
		return invalid(fmt.Sprintf("Anak ke-%d: %s", i+1, ve.Msg))
	}
	return err
}

// cekUsiaBalita: kader hanya mendaftarkan balita (0-59 bulan).
func cekUsiaBalita(a *models.Anak) error {
	if usiaBulan(a.TanggalLahir, hariIni()) > batasUsiaBalita {
		return invalid("usia anak lebih dari 59 bulan (bukan balita)")
	}
	return nil
}

// ---------------------------------------------------------------- cek NIK & No. HP

type CekAkunResp struct {
	NIKTerpakai  bool `json:"nik_terpakai"`
	NoHPTerpakai bool `json:"no_hp_terpakai"`
}

func (s *KaderKeluargaService) nikTerpakai(nik string) bool {
	return nik != "" && (s.users.Exists("nik", nik) || s.kel.NIKOrangTuaAda(nik))
}

func (s *KaderKeluargaService) hpTerpakai(hp string) bool {
	return hp != "" && s.users.Exists("no_hp", hp)
}

// CekAkun: dipanggil langsung saat NIK / No. HP diisi di form Tambahkan Akun.
func (s *KaderKeluargaService) CekAkun(nik, hp string) CekAkunResp {
	return CekAkunResp{
		NIKTerpakai:  s.nikTerpakai(strings.TrimSpace(nik)),
		NoHPTerpakai: s.hpTerpakai(strings.TrimSpace(hp)),
	}
}

// ---------------------------------------------------------------- tambahkan akun

type TambahKeluargaInput struct {
	Nama   string      `json:"nama"`
	NIK    string      `json:"nik"`
	NoHP   string      `json:"no_hp"`
	Pin    string      `json:"pin"`
	Profil ProfilInput `json:"profil"`
	Anak   []AnakInput `json:"anak"`
}

func (s *KaderKeluargaService) Tambah(pos string, in TambahKeluargaInput) (*KeluargaResponse, error) {
	pos, err := posKader(pos)
	if err != nil {
		return nil, err
	}

	// 1. akun (aturan sama dengan Register)
	nama := strings.TrimSpace(in.Nama)
	nik := strings.TrimSpace(in.NIK)
	hp := strings.TrimSpace(in.NoHP)
	if nama == "" {
		return nil, invalid("nama ibu / wali wajib diisi")
	}
	if len(nik) != 16 || !reAngka.MatchString(nik) {
		return nil, invalid("NIK harus 16 digit angka")
	}
	if len(hp) < 10 || len(hp) > 15 || !reAngka.MatchString(hp) {
		return nil, invalid("No. HP harus 10-15 digit angka")
	}
	if len(in.Pin) != 6 || !reAngka.MatchString(in.Pin) {
		return nil, invalid("PIN harus 6 digit angka")
	}
	if err := pinMudah(in.Pin); err != nil {
		return nil, err
	}
	if s.nikTerpakai(nik) {
		return nil, konflik("NIK telah digunakan")
	}
	if s.hpTerpakai(hp) {
		return nil, konflik("No. HP telah digunakan")
	}

	// 2. data keluarga (aturan sama dengan Data Orang Tua)
	profil, err := profilData(in.Profil)
	if err != nil {
		return nil, err
	}
	if profil.Ayah != nil && profil.Ayah.NIK != nil {
		an := *profil.Ayah.NIK
		if an == nik {
			return nil, invalid("NIK suami / ayah tidak boleh sama dengan NIK ibu")
		}
		if s.nikTerpakai(an) {
			return nil, konflik("NIK suami / ayah telah digunakan")
		}
	}

	// 3. data anak (aturan sama dengan Data Anak), minimal satu
	if len(in.Anak) == 0 {
		return nil, invalid("tambahkan minimal satu data anak")
	}
	anak := make([]*models.Anak, 0, len(in.Anak))
	nikAnak := map[string]bool{}
	kunci := map[string]bool{}
	for i, ai := range in.Anak {
		a, err := buatAnak(ai)
		if err != nil {
			return nil, keAnak(i, err)
		}
		if err := cekUsiaBalita(a); err != nil {
			return nil, keAnak(i, err)
		}
		if a.NIK != nil {
			if nikAnak[*a.NIK] || s.kel.NIKAnakSudahAda(*a.NIK, uuid.Nil) {
				return nil, konflik("Anak ke-%d: NIK anak telah digunakan", i+1)
			}
			nikAnak[*a.NIK] = true
		}
		k := strings.ToLower(a.Nama) + "|" + a.TanggalLahir.Format("2006-01-02")
		if kunci[k] {
			return nil, invalid(fmt.Sprintf("Anak ke-%d: nama dan tanggal lahir sama dengan anak lain", i+1))
		}
		kunci[k] = true
		anak = append(anak, a)
	}

	// 4. simpan semua dalam satu transaksi
	hash, err := utils.HashPIN(in.Pin)
	if err != nil {
		return nil, err
	}
	u := &models.User{
		Nama:          nama,
		NIK:           &nik,
		NoHP:          &hp,
		PinHash:       hash,
		Role:          models.RoleOrangTua,
		Posyandu:      pos,
		IsActive:      true,
		WajibGantiPIN: false,
	}
	if _, err := s.kel.BuatKeluargaLengkap(u, profil, anak); err != nil {
		return nil, err
	}
	return s.klg.Get(u.ID)
}

// ---------------------------------------------------------------- daftar & edit keluarga

func (s *KaderKeluargaService) Cari(pos, kata string) ([]repository.RingkasKeluarga, error) {
	pos, err := posKader(pos)
	if err != nil {
		return nil, err
	}
	return s.kel.CariKeluarga(pos, kata)
}

// uidKeluarga: akun ibu pemilik keluarga. Keluarga harus berada di posyandu kader.
func (s *KaderKeluargaService) uidKeluarga(pos string, kid uuid.UUID) (uint, error) {
	pos, err := posKader(pos)
	if err != nil {
		return 0, err
	}
	k, err := s.kel.GetKeluarga(kid)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return 0, invalid("data keluarga tidak ditemukan")
	}
	if err != nil {
		return 0, err
	}
	if kp, _ := models.NormalisasiPosyandu(k.Posyandu); kp != pos {
		return 0, terlarang("keluarga ini bukan dari posyandu Anda")
	}
	ibu, err := s.kel.IbuKeluarga(kid)
	if errors.Is(err, gorm.ErrRecordNotFound) || (err == nil && ibu.UserID == nil) {
		return 0, invalid("keluarga ini belum memiliki akun orang tua")
	}
	if err != nil {
		return 0, err
	}
	return *ibu.UserID, nil
}

func (s *KaderKeluargaService) Detail(pos string, kid uuid.UUID) (*KeluargaResponse, error) {
	uid, err := s.uidKeluarga(pos, kid)
	if err != nil {
		return nil, err
	}
	return s.klg.Get(uid)
}

func (s *KaderKeluargaService) UbahProfil(pos string, kid uuid.UUID, in ProfilInput) (*KeluargaResponse, error) {
	uid, err := s.uidKeluarga(pos, kid)
	if err != nil {
		return nil, err
	}
	return s.klg.SimpanProfil(uid, in)
}

func (s *KaderKeluargaService) TambahAnak(pos string, kid uuid.UUID, in AnakInput) (*models.Anak, error) {
	uid, err := s.uidKeluarga(pos, kid)
	if err != nil {
		return nil, err
	}
	a, err := buatAnak(in)
	if err != nil {
		return nil, err
	}
	if err := cekUsiaBalita(a); err != nil {
		return nil, err
	}
	return s.klg.TambahAnak(uid, in)
}

func (s *KaderKeluargaService) UbahAnak(pos string, kid, anakID uuid.UUID, in AnakInput) (*models.Anak, error) {
	uid, err := s.uidKeluarga(pos, kid)
	if err != nil {
		return nil, err
	}
	return s.klg.UbahAnak(uid, anakID, in)
}