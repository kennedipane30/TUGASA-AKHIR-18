package service

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

var ErrWaGagal = errors.New("pesan WhatsApp gagal dikirim, coba lagi beberapa saat")

// WaService mengirim pesan WhatsApp lewat gateway Fonnte (https://fonnte.com).
//
// Pengaturan di .env:
//
//	WA_API_TOKEN=token-device-dari-dashboard-fonnte
//	WA_API_URL=https://api.fonnte.com/send   (opsional, ini nilai bawaannya)
//
// Bila WA_API_TOKEN kosong, WaService berjalan dalam MODE UJI: pesan tidak
// dikirim, hanya ditulis ke log server (kode OTP terlihat di terminal).
// Mode uji hanya untuk pengembangan; isi token sebelum aplikasi dipakai warga.
type WaService struct {
	url    string
	token  string
	client *http.Client
}

func NewWaService() *WaService {
	u := strings.TrimSpace(os.Getenv("WA_API_URL"))
	if u == "" {
		u = "https://api.fonnte.com/send"
	}
	t := strings.TrimSpace(os.Getenv("WA_API_TOKEN"))
	if t == "" {
		log.Println("wa: WA_API_TOKEN kosong, WhatsApp berjalan dalam MODE UJI (pesan hanya ditulis ke log)")
	} else {
		log.Println("wa: gateway WhatsApp aktif")
	}
	return &WaService{url: u, token: t, client: &http.Client{Timeout: 15 * time.Second}}
}

func (w *WaService) Aktif() bool { return w != nil && w.token != "" }

// Kirim mengirim satu pesan teks ke nomor WhatsApp (format 08xx / 62xx).
func (w *WaService) Kirim(noHP, pesan string) error {
	if !w.Aktif() {
		log.Printf("wa: [MODE UJI] ke %s:\n%s", noHP, pesan)
		return nil
	}

	form := url.Values{}
	form.Set("target", noHP)
	form.Set("message", pesan)
	form.Set("countryCode", "62")

	req, err := http.NewRequest(http.MethodPost, w.url, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", w.token) // Fonnte: token langsung, tanpa "Bearer"
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	res, err := w.client.Do(req)
	if err != nil {
		log.Printf("wa: gagal menghubungi gateway: %v", err)
		return ErrWaGagal
	}
	defer res.Body.Close()
	isi, _ := io.ReadAll(io.LimitReader(res.Body, 4096))

	var jawab struct {
		Status bool   `json:"status"`
		Reason string `json:"reason"`
		Detail string `json:"detail"`
	}
	_ = json.Unmarshal(isi, &jawab)
	if res.StatusCode >= 300 || !jawab.Status {
		log.Printf("wa: gateway menolak (HTTP %d): %s", res.StatusCode, strings.TrimSpace(fmt.Sprint(jawab.Reason, " ", jawab.Detail)))
		return ErrWaGagal
	}
	return nil
}