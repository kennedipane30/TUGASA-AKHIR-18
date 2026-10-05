# Uji alur satu sesi posyandu secara online.
# Jalankan server lebih dulu (go run ./cmd/server), lalu dari folder BackEnd:
#   powershell -ExecutionPolicy Bypass -File .\scripts\uji_alur.ps1
param(
  [string]$Url        = "http://localhost:8080/api/v1",
  [string]$AdminHp    = "082235805348",
  [string]$AdminSandi = "Admin12345"
)

function Api($metode, $path, $token, $body) {
  $h = @{}
  if ($token) { $h["Authorization"] = "Bearer $token" }
  try {
    if ($null -ne $body) {
      return Invoke-RestMethod -Method $metode -Uri "$Url$path" -Headers $h `
        -ContentType "application/json" -Body ($body | ConvertTo-Json -Depth 8)
    }
    return Invoke-RestMethod -Method $metode -Uri "$Url$path" -Headers $h
  } catch {
    $pesan = $_.ErrorDetails.Message
    if (-not $pesan) { $pesan = $_.Exception.Message }
    Write-Host "   [GAGAL] $metode $path -> $pesan" -ForegroundColor Yellow
    return $null
  }
}
function Judul($t) { Write-Host "`n== $t" -ForegroundColor Cyan }

# ------------------------------------------------------------ 1. admin
Judul "1. Login admin"
$admin = Api Post "/auth/login" $null @{ identifier = $AdminHp; password = $AdminSandi }
$tAdmin = $admin.token

Judul "2. Admin membuat akun kader dan bidan (abaikan GAGAL jika sudah ada)"
Api Post "/admin/users" $tAdmin @{ nama = "Kader Satu"; username = "kader01"; password = "kader123"; role = "kader" } | Out-Null
Api Post "/admin/users" $tAdmin @{ nama = "Bidan Satu"; username = "bidan01"; password = "bidan123"; role = "bidan" } | Out-Null
$tKader = (Api Post "/auth/login" $null @{ identifier = "kader01"; password = "kader123" }).token
$tBidan = (Api Post "/auth/login" $null @{ identifier = "bidan01"; password = "bidan123" }).token

# ------------------------------------------------------------ 2. orang tua
Judul "3. Orang tua mendaftar akun dan melengkapi data keluarga"
$nik = "3201000000000001"
Api Post "/auth/register" $null @{ nama = "Siti Rahmawati"; nik = $nik; no_hp = "081200000001"; password = "123456" } | Out-Null
$tOrtu = (Api Post "/auth/login" $null @{ identifier = $nik; password = "123456" }).token

Api Put "/keluarga/saya" $tOrtu @{
  ibu = @{ nama = "Siti Rahmawati"; tanggal_lahir = "1995-04-12"; no_hp = "081200000001"; pekerjaan = "Ibu rumah tangga" }
  alamat = "Jl. Melati No. 5"; rt = "02"; rw = "05"; tanpa_ayah = $true
} | Out-Null
$kel = Api Get "/keluarga/saya" $tOrtu
if ($kel.data.anak.Count -eq 0) {
  Api Post "/keluarga/saya/anak" $tOrtu @{ nama = "Rian Pratama"; tanggal_lahir = "2024-06-15"; jenis_kelamin = "L"; berat_lahir_kg = 3.2; panjang_lahir_cm = 49 } | Out-Null
}

# ------------------------------------------------------------ 3. jadwal
Judul "4. Admin membuat jadwal (hari ini, mulai 30 menit lagi)"
$tanggal = (Get-Date).ToString("yyyy-MM-dd")
$mulai   = (Get-Date).AddMinutes(30).ToString("HH:mm")
$j = Api Post "/admin/jadwal" $tAdmin @{ tanggal = $tanggal; jam_mulai = $mulai; lokasi = "Balai Warga RW 05" }
if ($j) { Write-Host "   jadwal dibuat: $($j.data.id)" }

Judul "5. Orang tua melihat jadwal terdekat"
$td = Api Get "/jadwal/terdekat" $tOrtu
if (-not $td.data) { Write-Host "Tidak ada jadwal terdekat. Hentikan." -ForegroundColor Red; return }
$jadwalId = $td.data.jadwal.id
$anakId   = $td.data.anak[0].anak_id
$td.data.anak | Format-Table nama, status_kehadiran, nomor_antrean, boleh_daftar, boleh_checkin

Judul "6. Orang tua mendaftar lalu check-in"
Api Post "/jadwal/$jadwalId/daftar"  $tOrtu @{ anak_id = $anakId } | Out-Null
Api Post "/jadwal/$jadwalId/checkin" $tOrtu @{ anak_id = $anakId } | Out-Null
(Api Get "/jadwal/terdekat" $tOrtu).data.anak | Format-Table nama, status_kehadiran, nomor_antrean

# ------------------------------------------------------------ 4. kader
Judul "7. Kader melihat antrean dan mencatat pengukuran"
$antrean = Api Get "/kader/jadwal/$jadwalId/antrean" $tKader
$antrean.data | Format-Table nama, nomor_antrean, status_kehadiran, sudah_diukur
$pid = $antrean.data[0].pendaftaran_id
$ukur = Api Put "/kader/pendaftaran/$pid/pengukuran" $tKader @{
  bb_kg = 12.4; tb_cm = 88.5; lingkar_kepala_cm = 48.0; lila_cm = 16.2; asi_eksklusif = $false
}
$ukur.data | Format-List bb_kg, tb_cm, usia_bulan, cara_ukur, peringatan_validasi, status_data

# ------------------------------------------------------------ 5. bidan
Judul "8. Orang tua BELUM melihat hasil di Riwayat (bidan belum membuat catatan)"
(Api Get "/riwayat" $tOrtu).data | Measure-Object | Select-Object Count

Judul "9. Bidan melihat pengukuran kader lalu membuat catatan"
Api Get "/bidan/jadwal/$jadwalId/pengukuran" $tBidan | ForEach-Object { $_.data } |
  Format-Table nama, bb_kg, tb_cm, status_catatan
$vaksin = (Api Get "/vaksin" $tBidan).data
$bcg = $vaksin | Where-Object { $_.kode -eq "BCG" } | Select-Object -First 1
$catatan = @{
  catatan_evaluasi = "Pertumbuhan baik"
  saran_gizi       = "Tambah protein hewani: telur, ikan, hati ayam"
  tanggal_kunjungan_ulang = (Get-Date).AddMonths(1).ToString("yyyy-MM-dd")
  suplemen = @(@{ jenis = "vitamin_a"; keterangan_dosis = "Kapsul biru" })
}
if ($bcg) { $catatan.vaksin = @(@{ jenis_vaksin_id = $bcg.id; dosis_ke = 1; kondisi_anak = "Sehat" }) }
$hasil = Api Put "/bidan/pendaftaran/$pid/catatan" $tBidan $catatan
if (-not $hasil -and $bcg) {
  Write-Host "   Mencoba ulang tanpa vaksin (BCG mungkin sudah pernah dicatat)..."
  $catatan.Remove("vaksin")
  $hasil = Api Put "/bidan/pendaftaran/$pid/catatan" $tBidan $catatan
}

# ------------------------------------------------------------ 6. riwayat
Judul "10. Orang tua melihat Riwayat (sekarang sudah ada)"
$riw = Api Get "/riwayat?anak_id=$anakId" $tOrtu
$riw.data | ForEach-Object {
  Write-Host ("   {0} | {1} | BB {2} kg, TB {3} cm | saran: {4}" -f $_.nama_anak, $_.tanggal, $_.pengukuran.bb_kg, $_.pengukuran.tb_cm, $_.catatan.saran_gizi)
  Write-Host ("   vaksin: {0} | suplemen: {1}" -f $_.imunisasi.Count, $_.suplemen.Count)
}
Write-Host "`nSelesai." -ForegroundColor Green
