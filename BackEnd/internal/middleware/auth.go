package middleware

import (
	"net/http"
	"strings"

	"posyandu-api/internal/repository"
	"posyandu-api/internal/utils"

	"github.com/gin-gonic/gin"
)

func AuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		if !strings.HasPrefix(h, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token tidak ada"})
			return
		}
		claims, err := utils.ParseToken(strings.TrimPrefix(h, "Bearer "))
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "token tidak valid"})
			return
		}
		c.Set("user_id", claims.UserID)
		c.Set("role", claims.Role)
		c.Next()
	}
}

// Posyandu memuat posyandu akun dari database (bukan dari token).
// Semua role wajib punya posyandu; tidak ada akun yang melihat lintas posyandu.
func Posyandu(users *repository.UserRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		u, err := users.FindByID(c.GetUint("user_id"))
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "akun tidak ditemukan"})
			return
		}
		if !u.IsActive {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "akun tidak aktif, hubungi sekretaris"})
			return
		}
		if u.Posyandu == "" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "akun belum terhubung ke posyandu"})
			return
		}
		c.Set("posyandu", u.Posyandu)
		c.Next()
	}
}

func RoleRequired(roles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("role")
		for _, r := range roles {
			if r == role {
				c.Next()
				return
			}
		}
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "akses ditolak"})
	}
}