package utils

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"regexp"

	"golang.org/x/crypto/bcrypt"
)

var rePIN = regexp.MustCompile(`^[0-9]{6}$`)

var pinUmum = map[string]bool{
	"112233": true, "123321": true, "159753": true, "147258": true,
	"258369": true, "102030": true, "696969": true, "121314": true,
}

// HashPIN membuat hash bcrypt dari PIN (PIN asli tidak pernah disimpan).
func HashPIN(pin string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(pin), bcrypt.DefaultCost)
	return string(b), err
}

// CekPIN membandingkan PIN yang diketik dengan hash tersimpan.
func CekPIN(hash, pin string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(pin)) == nil
}

// FormatPIN: PIN tepat 6 digit angka (dipakai saat login).
func FormatPIN(pin string) bool { return rePIN.MatchString(pin) }

// ValidasiPIN memastikan PIN tepat 6 digit angka dan tidak terlalu mudah ditebak:
// tidak kembar (111111), tidak berurutan naik/turun (123456, 654321),
// tidak berulang (123123, 121212), dan bukan PIN umum.
func ValidasiPIN(pin string) error {
	if !rePIN.MatchString(pin) {
		return errors.New("PIN harus 6 digit angka")
	}
	mudah := errors.New("PIN terlalu mudah ditebak, hindari angka kembar, berurutan, atau berulang")

	sama, naik, turun := true, true, true
	for i := 1; i < 6; i++ {
		if pin[i] != pin[i-1] {
			sama = false
		}
		if pin[i] != pin[i-1]+1 {
			naik = false
		}
		if pin[i] != pin[i-1]-1 {
			turun = false
		}
	}
	if sama || naik || turun {
		return mudah
	}
	if pin[:3] == pin[3:] || (pin[:2] == pin[2:4] && pin[2:4] == pin[4:]) {
		return mudah
	}
	if pinUmum[pin] {
		return mudah
	}
	return nil
}

// PINAcak membuat PIN sementara 6 digit yang lolos ValidasiPIN.
func PINAcak() string {
	for {
		n, err := rand.Int(rand.Reader, big.NewInt(1000000))
		if err != nil {
			continue
		}
		pin := fmt.Sprintf("%06d", n.Int64())
		if ValidasiPIN(pin) == nil {
			return pin
		}
	}
}