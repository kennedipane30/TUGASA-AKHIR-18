package utils

import (
	"os"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	UserID   uint   `json:"uid"`
	Role     string `json:"role"`
	Posyandu string `json:"pos,omitempty"`
	jwt.RegisteredClaims
}

// GenerateToken: posyandu bersifat opsional (kosong untuk admin).
func GenerateToken(userID uint, role string, posyandu ...string) (string, error) {
	hours, _ := strconv.Atoi(os.Getenv("JWT_EXPIRE_HOURS"))
	if hours == 0 {
		hours = 72
	}
	pos := ""
	if len(posyandu) > 0 {
		pos = posyandu[0]
	}
	claims := Claims{
		UserID:   userID,
		Role:     role,
		Posyandu: pos,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(hours) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).
		SignedString([]byte(os.Getenv("JWT_SECRET")))
}

func ParseToken(tok string) (*Claims, error) {
	t, err := jwt.ParseWithClaims(tok, &Claims{}, func(*jwt.Token) (any, error) {
		return []byte(os.Getenv("JWT_SECRET")), nil
	})
	if err != nil {
		return nil, err
	}
	return t.Claims.(*Claims), nil
}