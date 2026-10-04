package models

type Posyandu struct {
	ID   uint   `gorm:"primaryKey" json:"id"`
	Nama string `gorm:"size:100;not null;uniqueIndex" json:"nama"`
}

func (Posyandu) TableName() string { return "posyandu" }