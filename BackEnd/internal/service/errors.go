package service

import (
	"errors"
	"fmt"
)

var (
	ErrJadwalTidakAda      = errors.New("jadwal tidak ditemukan")
	ErrPendaftaranTidakAda = errors.New("pendaftaran tidak ditemukan")
)

// ErrKonflik: aturan alur tidak terpenuhi (dijawab dengan kode 409).
type ErrKonflik struct{ Pesan string }

func (e ErrKonflik) Error() string { return e.Pesan }

// ErrTerlarang: pengguna tidak berhak atas data tersebut (kode 403).
type ErrTerlarang struct{ Pesan string }

func (e ErrTerlarang) Error() string { return e.Pesan }

func konflik(format string, a ...any) error   { return ErrKonflik{fmt.Sprintf(format, a...)} }
func terlarang(format string, a ...any) error { return ErrTerlarang{fmt.Sprintf(format, a...)} }
