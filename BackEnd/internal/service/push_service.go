package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

var ErrTokenPushTidakValid = errors.New("token perangkat tidak valid")

const fcmScope = "https://www.googleapis.com/auth/firebase.messaging"

type PushService struct {
	projectID string
	client    *http.Client
}

func NewPushService() *PushService {
	path := strings.TrimSpace(os.Getenv("FCM_CREDENTIALS_FILE"))
	if path == "" {
		log.Println("push: FCM_CREDENTIALS_FILE kosong, notifikasi push dinonaktifkan")
		return &PushService{}
	}
	b, err := os.ReadFile(path)
	if err != nil {
		log.Printf("push: gagal membaca %s: %v", path, err)
		return &PushService{}
	}
	ctx := context.Background()
	creds, err := google.CredentialsFromJSON(ctx, b, fcmScope)
	if err != nil {
		log.Printf("push: kredensial FCM tidak valid: %v", err)
		return &PushService{}
	}
	pid := strings.TrimSpace(os.Getenv("FCM_PROJECT_ID"))
	if pid == "" {
		pid = creds.ProjectID
	}
	if pid == "" {
		log.Println("push: FCM_PROJECT_ID tidak ditemukan, notifikasi push dinonaktifkan")
		return &PushService{}
	}
	c := oauth2.NewClient(ctx, creds.TokenSource)
	c.Timeout = 15 * time.Second
	log.Println("push: FCM aktif untuk project", pid)
	return &PushService{projectID: pid, client: c}
}

func (p *PushService) Aktif() bool { return p != nil && p.client != nil }

func (p *PushService) Kirim(token, judul, isi string, data map[string]string) error {
	if !p.Aktif() {
		return nil
	}
	if data == nil {
		data = map[string]string{}
	}
	pesan := map[string]any{
		"message": map[string]any{
			"token": token,
			"notification": map[string]string{
				"title": judul,
				"body":  isi,
			},
			"data": data,
			"android": map[string]any{
				"priority": "HIGH",
				"notification": map[string]any{
					"channel_id":              "jadwal_posyandu",
					"sound":                   "default",
					"default_vibrate_timings": true,
				},
			},
			"apns": map[string]any{
				"headers": map[string]string{"apns-priority": "10"},
				"payload": map[string]any{
					"aps": map[string]any{"sound": "default"},
				},
			},
		},
	}
	body, err := json.Marshal(pesan)
	if err != nil {
		return err
	}
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", p.projectID)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := p.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		_, _ = io.Copy(io.Discard, resp.Body)
		return nil
	}
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	teks := string(raw)
	if resp.StatusCode == http.StatusNotFound ||
		strings.Contains(teks, "UNREGISTERED") ||
		(resp.StatusCode == http.StatusBadRequest && strings.Contains(strings.ToLower(teks), "registration token")) {
		return ErrTokenPushTidakValid
	}
	return fmt.Errorf("fcm %d: %s", resp.StatusCode, teks)
}