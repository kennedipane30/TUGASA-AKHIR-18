package service

import (
	"sort"

	"posyandu-api/internal/models"
	"posyandu-api/internal/repository"

	"github.com/google/uuid"
)

type VaksinStatistikService struct{ repo *repository.VaksinStatistikRepository }

func NewVaksinStatistikService(repo *repository.VaksinStatistikRepository) *VaksinStatistikService {
	return &VaksinStatistikService{repo}
}

type VaksinStatistikItem struct {
	JenisVaksin     *models.JenisVaksin `json:"jenis_vaksin"`
	JumlahDiberikan int64               `json:"jumlah_diberikan"`
	JumlahAnak      int64               `json:"jumlah_anak"`
}

type VaksinStatistikResp struct {
	TotalDiberikan   int64                 `json:"total_diberikan"`
	TotalAnakDivaksin int64                `json:"total_anak_divaksin"`
	RencanaAktif     int64                 `json:"rencana_aktif"`
	JumlahJenis      int                   `json:"jumlah_jenis"`
	Jenis            []VaksinStatistikItem `json:"jenis"`
}

func (s *VaksinStatistikService) Statistik() (*VaksinStatistikResp, error) {
	total, err := s.repo.TotalDiberikan()
	if err != nil {
		return nil, err
	}
	anak, err := s.repo.TotalAnakDivaksin()
	if err != nil {
		return nil, err
	}
	rencana, err := s.repo.TotalRencanaAktif()
	if err != nil {
		return nil, err
	}
	agregat, err := s.repo.JumlahPerVaksin()
	if err != nil {
		return nil, err
	}
	jenis, err := s.repo.ListJenisVaksin()
	if err != nil {
		return nil, err
	}

	peta := make(map[uuid.UUID]repository.JumlahPerVaksin, len(agregat))
	for _, a := range agregat {
		peta[a.JenisVaksinID] = a
	}

	items := make([]VaksinStatistikItem, 0, len(jenis))
	for i := range jenis {
		a := peta[jenis[i].ID]
		items = append(items, VaksinStatistikItem{
			JenisVaksin:     &jenis[i],
			JumlahDiberikan: a.Jumlah,
			JumlahAnak:      a.Anak,
		})
	}
	sort.SliceStable(items, func(i, j int) bool {
		return items[i].JumlahDiberikan > items[j].JumlahDiberikan
	})

	return &VaksinStatistikResp{
		TotalDiberikan:    total,
		TotalAnakDivaksin: anak,
		RencanaAktif:      rencana,
		JumlahJenis:       len(items),
		Jenis:             items,
	}, nil
}