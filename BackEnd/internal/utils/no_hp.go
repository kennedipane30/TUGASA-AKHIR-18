package utils

import "strings"

// ============================================================================
// FORMAT BAKU NOMOR HP (Indonesia)
//
// Semua No. HP disimpan dalam format internasional E.164: +62 lalu 9-12 digit
// yang diawali 8, contoh "+6281234567890". No. HP juga satu-satunya identitas
// login (bersama PIN 6 digit) untuk semua role.
//
// Isian "081234567890", "6281234567890", "+62 812-3456-7890", atau
// "81234567890" otomatis diubah ke "+6281234567890".
// ============================================================================

// PesanNoHP: pesan kesalahan bila No. HP tidak sesuai format.
const PesanNoHP = "No. HP tidak valid. Isi setelah +62 diawali angka 8, 9-12 digit (contoh: +62 812-3456-7890)"

// NormalisasiNoHP mengubah No. HP ke format baku "+628...".
// ok=false bila bukan No. HP Indonesia yang valid.
func NormalisasiNoHP(s string) (string, bool) {
	s = strings.NewReplacer(" ", "", "-", "", "+", "", "(", "", ")", "", ".", "").Replace(strings.TrimSpace(s))
	switch {
	case strings.HasPrefix(s, "62"):
		s = s[2:]
	case strings.HasPrefix(s, "0"):
		s = s[1:]
	}
	// s sekarang nomor tanpa kode negara, harus 8xxxxxxxx (9-12 digit)
	if !strings.HasPrefix(s, "8") || len(s) < 9 || len(s) > 12 {
		return "", false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return "", false
		}
	}
	return "+62" + s, true
}

// NoHPTanpaPlus: "+6281234567890" -> "6281234567890" (untuk gateway WhatsApp).
func NoHPTanpaPlus(hp string) string { return strings.TrimPrefix(hp, "+") }

// SamarkanNoHP: "+6281234567890" -> "+62 812****7890" (untuk ditampilkan).
func SamarkanNoHP(hp string) string {
	inti := strings.TrimPrefix(hp, "+62")
	if len(inti) < 7 {
		return hp
	}
	return "+62 " + inti[:3] + strings.Repeat("*", len(inti)-7) + inti[len(inti)-4:]
}