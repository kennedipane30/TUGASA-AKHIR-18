package models

import "strings"

const (
	PosyanduSilimbat  = "silimbat"
	PosyanduSitoluama = "sitoluama"
	PosyanduAekBolon  = "aekbolon"
)

type PilihanPosyandu struct {
	Kode string `json:"kode"`
	Nama string `json:"nama"`
}

var DaftarPosyandu = []PilihanPosyandu{
	{Kode: PosyanduSilimbat, Nama: "Silimbat"},
	{Kode: PosyanduSitoluama, Nama: "Sitoluama"},
	{Kode: PosyanduAekBolon, Nama: "Aek Bolon"},
}

// NormalisasiPosyandu mengubah input (misalnya "Aek Bolon", "aek_bolon") menjadi kode baku.
func NormalisasiPosyandu(s string) (string, bool) {
	s = strings.ToLower(strings.TrimSpace(s))
	s = strings.NewReplacer(" ", "", "_", "", "-", "").Replace(s)
	switch s {
	case PosyanduSilimbat, PosyanduSitoluama, PosyanduAekBolon:
		return s, true
	}
	return "", false
}