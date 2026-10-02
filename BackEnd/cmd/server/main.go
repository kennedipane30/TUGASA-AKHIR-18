package main

import (
	"log"
	"os"

	"posyandu-api/internal/database"
	"posyandu-api/internal/router"

	"github.com/joho/godotenv"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("peringatan: .env tidak terbaca, memakai environment sistem")
	}

	db, err := database.Connect()
	if err != nil {
		log.Fatal("gagal konek database: ", err)
	}

	port := os.Getenv("APP_PORT")
	if port == "" {
		port = "8080"
	}
	log.Println("server berjalan di port", port)
	log.Fatal(router.Setup(db).Run(":" + port))
}