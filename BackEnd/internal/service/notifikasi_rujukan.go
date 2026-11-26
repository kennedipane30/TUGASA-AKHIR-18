package service

import (
	"fmt"
	"strings"

	"posyandu-api/internal/models"
)

// ============================================================================
// NOTIFIKASI RUJUKAN KE ORANG TUA
// (file terpisah; tidak mengubah notifikasi_service.go)
// ============================================================================

const NotifRujukan = "rujukan"

func (s *NotifikasiService) kirimRujukanOrtu(m *models.Rujukan, tahap string, pengirim uint, judul, isi string) {
	kunci := fmt.Sprintf("%s:%s:%s", NotifRujukan, m.ID, tahap)
	if s.repo.KunciSudahAda(kunci) {
		return
	}
	ortu, err := s.repo.OrangTuaBalita(m.BalitaID)
	if err != nil || len(ortu) == 0 {
		return
	}
	id := m.ID
	s.kirimKeUser(ortu, NotifRujukan, kunci, "rujukan", &id, &pengirim,
		func(models.Role) (string, string) { return judul, isi })
}

// RujukanDibuat: orang tua diberi tahu balitanya dirujuk.
func (s *NotifikasiService) RujukanDibuat(balita *models.Balita, m *models.Rujukan, pengirim uint) {
	defer s.pulih("rujukan dibuat")
	if m == nil {
		return
	}
	nama := strings.TrimSpace(m.NamaBalita)
	if balita != nil && strings.TrimSpace(balita.Nama) != "" {
		nama = strings.TrimSpace(balita.Nama)
	}
	isi := fmt.Sprintf("%s dirujuk ke %s. Diagnosis: %s. Buka menu Rujukan Balita untuk melihat dan mengunduh surat rujukan (No. %s), lalu bawa surat ke fasilitas kesehatan tujuan.",
		nama, m.Tujuan, m.Diagnosis, m.Nomor)
	s.kirimRujukanOrtu(m, "dibuat", pengirim, "Surat Rujukan: "+nama, isi)
}

// RujukanDiubah: isi surat rujukan diperbarui bidan.
func (s *NotifikasiService) RujukanDiubah(m *models.Rujukan, pengirim uint) {
	defer s.pulih("rujukan diubah")
	if m == nil {
		return
	}
	nama := strings.TrimSpace(m.NamaBalita)
	isi := fmt.Sprintf("Surat rujukan %s (No. %s) diperbarui bidan. Tujuan: %s. Silakan unduh ulang surat rujukan terbaru di menu Rujukan Balita.",
		nama, m.Nomor, m.Tujuan)
	s.kirimRujukanOrtu(m, fmt.Sprintf("ubah-v%d", m.Version), pengirim, "Rujukan Diperbarui: "+nama, isi)
}

// RujukanDihapus: rujukan dihapus bidan (tanpa tautan ke rujukan).
func (s *NotifikasiService) RujukanDihapus(m *models.Rujukan, pengirim uint) {
	defer s.pulih("rujukan dihapus")
	if m == nil {
		return
	}
	kunci := fmt.Sprintf("%s:%s:hapus", NotifRujukan, m.ID)
	if s.repo.KunciSudahAda(kunci) {
		return
	}
	ortu, err := s.repo.OrangTuaBalita(m.BalitaID)
	if err != nil || len(ortu) == 0 {
		return
	}
	nama := strings.TrimSpace(m.NamaBalita)
	isi := fmt.Sprintf("Surat rujukan %s (No. %s) telah dihapus oleh bidan dan tidak berlaku lagi.", nama, m.Nomor)
	s.kirimKeUser(ortu, NotifRujukan, kunci, "", nil, &pengirim,
		func(models.Role) (string, string) { return "Rujukan Dihapus: " + nama, isi })
}

// RujukanSelesai: hasil pemeriksaan dari faskes (rujukan balik) sudah dicatat bidan.
func (s *NotifikasiService) RujukanSelesai(m *models.Rujukan, pengirim uint) {
	defer s.pulih("rujukan selesai")
	if m == nil {
		return
	}
	nama := strings.TrimSpace(m.NamaBalita)
	isi := fmt.Sprintf("Hasil pemeriksaan rujukan %s dari %s sudah dicatat bidan. Buka menu Rujukan Balita untuk melihat hasil dan tindak lanjutnya.",
		nama, m.Tujuan)
	s.kirimRujukanOrtu(m, "selesai", pengirim, "Hasil Rujukan: "+nama, isi)
}

// RujukanDibatalkan: rujukan dibatalkan bidan.
func (s *NotifikasiService) RujukanDibatalkan(m *models.Rujukan, pengirim uint) {
	defer s.pulih("rujukan dibatalkan")
	if m == nil {
		return
	}
	nama := strings.TrimSpace(m.NamaBalita)
	isi := fmt.Sprintf("Rujukan %s (No. %s) dibatalkan bidan. Alasan: %s.", nama, m.Nomor, m.AlasanBatal)
	s.kirimRujukanOrtu(m, "batal", pengirim, "Rujukan Dibatalkan: "+nama, isi)
}