package main

import (
	"log"

	"posyandu-api/internal/database"

	"github.com/joho/godotenv"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Fatal("gagal membaca .env, jalankan dari folder BackEnd: ", err)
	}

	db, err := database.Connect()
	if err != nil {
		log.Fatal("gagal konek database: ", err)
	}

	seedSekretaris(db) // satu sekretaris per desa
}