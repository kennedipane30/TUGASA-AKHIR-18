package handler

// PelayananHandler melayani endpoint satu sesi pelayanan posyandu, dari
// pendataan kader sampai pemeriksaan bidan.
//
// Berkas ini berisi rangka handler-nya saja. Endpoint tiap fitur ada di berkas
// tersendiri, bersesuaian satu-satu dengan service dan repository-nya:
//
//	pengukuran_handler.go           pendataan kader
//	pemeriksaan_handler.go          pemeriksaan bidan
//	kpsp_handler.go                 skrining perkembangan (KPSP)
//	riwayat_pemeriksaan_handler.go  riwayat kunjungan untuk orang tua

import (
	"posyandu-api/internal/service"
)

type PelayananHandler struct{ svc *service.PelayananService }

func NewPelayananHandler(s *service.PelayananService) *PelayananHandler { return &PelayananHandler{s} }