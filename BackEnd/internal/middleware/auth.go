package middleware

import (
	"net/http"
	"strings"

	"posyandu-api/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
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
		c.Set("posyandu", claims.Posyandu)
		c.Next()
	}
}

// LoadPosyandu: posyandu selalu dibaca dari database (bukan dari token), sehingga
// perubahan posyandu akun oleh admin langsung berlaku dan akun nonaktif langsung ditolak.
func LoadPosyandu(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var u struct {
			Posyandu string
			IsActive bool
		}
		err := db.Table("users").Select("posyandu, is_active").
			Where("id = ?", c.GetUint("user_id")).Take(&u).Error
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "akun tidak ditemukan"})
			return
		}
		if !u.IsActive {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "akun tidak aktif, hubungi admin"})
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

// PosyanduRequired: kader, bidan, dan orang tua wajib punya posyandu.
// Admin dikecualikan (admin melihat semua posyandu).
func PosyanduRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.GetString("role") == "admin" {
			c.Next()
			return
		}
		if c.GetString("posyandu") == "" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "akun belum memiliki posyandu, hubungi admin"})
			return
		}
		c.Next()
	}
}