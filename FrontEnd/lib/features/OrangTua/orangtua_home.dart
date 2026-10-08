import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import 'buku_panduan_page.dart';
import 'lengkapi_keluarga_page.dart';
import 'orangtua_pendaftaran_page.dart';
import 'orangtua_vaksin_page.dart';

// Data kesehatan (pemeriksaan, KMS, imunisasi) belum punya endpoint di backend.
// Selama false, bagian tersebut menampilkan pesan "belum ada data" dan TIDAK
// memakai data contoh di bawah. Ubah menjadi true hanya untuk keperluan demo.
bool get _tampilDataContoh => false;

// ---------------------------------------------------------------------------
// DATA CONTOH (khusus bagian kesehatan, belum tersambung ke API)
// ---------------------------------------------------------------------------
class _Anak {
  final String nama;
  final String usia;
  final String jk;
  final String nik;
  final String tglPeriksa;
  final double bb, selisihBb, tb, lk, lla;
  final (String, Gizi) bbu;
  final (String, Gizi) tbu;
  final (String, Gizi) bbtb;
  final String catatanBidan;
  final String? peringatan;
  final List<double> kmsBb, kmsBawah, kmsAtas;
  final List<String> vaksinSelesai;
  final String vaksinBerikutnya;
  final String? vaksinTerlewat;
  final String vitaminA;
  final String obatCacing;

  const _Anak({
    required this.nama,
    required this.usia,
    required this.jk,
    required this.nik,
    required this.tglPeriksa,
    required this.bb,
    required this.selisihBb,
    required this.tb,
    required this.lk,
    required this.lla,
    required this.bbu,
    required this.tbu,
    required this.bbtb,
    required this.catatanBidan,
    required this.kmsBb,
    required this.kmsBawah,
    required this.kmsAtas,
    required this.vaksinSelesai,
    required this.vaksinBerikutnya,
    required this.vitaminA,
    required this.obatCacing,
    this.peringatan,
    this.vaksinTerlewat,
  });
}

const _daftarAnak = <_Anak>[
  _Anak(
    nama: 'Rian Pratama',
    usia: '2 th 3 bln',
    jk: 'Laki-laki',
    nik: '3273••••••••001',
    tglPeriksa: '14 Sep 2024',
    bb: 12.4,
    selisihBb: 0.3,
    tb: 88.5,
    lk: 48.0,
    lla: 16.2,
    bbu: ('Naik · Gizi Baik', Gizi.baik),
    tbu: ('Normal / Tinggi Ideal', Gizi.baik),
    bbtb: ('Gizi Baik', Gizi.baik),
    catatanBidan:
        'Pertumbuhan Rian sangat konsisten di grafik hijau. Lanjutkan MP-ASI padat gizi, tambah protein hewani seperti telur, ikan, dan hati ayam.',
    kmsBb: [10.6, 11.0, 11.4, 11.8, 12.1, 12.4],
    kmsBawah: [9.4, 9.7, 10.0, 10.2, 10.4, 10.6],
    kmsAtas: [13.4, 13.8, 14.2, 14.5, 14.8, 15.1],
    vaksinSelesai: ['HB-0', 'BCG', 'Polio 1-4', 'DPT-HB-Hib 1-3', 'Campak'],
    vaksinBerikutnya: 'DPT-HB-Hib lanjutan · sekitar bulan depan',
    vitaminA: 'Vitamin A: 12 Agu 2026 (biru)',
    obatCacing: 'Obat cacing: 12 Feb 2026',
  ),
  _Anak(
    nama: 'Aisyah',
    usia: '8 bln',
    jk: 'Perempuan',
    nik: '3273••••••••002',
    tglPeriksa: '14 Sep 2024',
    bb: 7.8,
    selisihBb: 0.1,
    tb: 68.0,
    lk: 43.5,
    lla: 13.8,
    bbu: ('Kurang Naik · Waspada', Gizi.waspada),
    tbu: ('Normal', Gizi.baik),
    bbtb: ('Gizi Kurang', Gizi.waspada),
    catatanBidan:
        'Kenaikan berat badan Aisyah masih kecil. Tambah frekuensi MP-ASI menjadi 3 kali sehari dan kunjungan ulang 2 minggu lagi.',
    peringatan:
        'Berat badan kurang naik. Anjuran: perbanyak protein hewani dan datang kembali ke posyandu bulan depan.',
    kmsBb: [6.7, 6.9, 7.2, 7.5, 7.7, 7.8],
    kmsBawah: [6.3, 6.5, 6.7, 6.9, 7.1, 7.3],
    kmsAtas: [8.9, 9.1, 9.3, 9.5, 9.7, 9.9],
    vaksinSelesai: ['HB-0', 'BCG', 'Polio 1-3', 'DPT-HB-Hib 1-2'],
    vaksinBerikutnya: 'Campak-Rubella · sekitar 1 bulan lagi',
    vaksinTerlewat: 'Polio 4 (IPV) belum diberikan',
    vitaminA: 'Vitamin A: belum waktunya (mulai usia 6 bln)',
    obatCacing: 'Obat cacing: belum waktunya',
  ),
];

// Usia dari tanggal "dd/mm/yyyy"
String _usiaAnak(String tgl) {
  final p = tgl.split('/');
  if (p.length != 3) return '-';
  final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return '-';
  final n = DateTime.now();
  var bln = (n.year - y) * 12 + (n.month - m);
  if (n.day < d) bln--;
  if (bln < 0) bln = 0;
  return bln >= 12 ? '${bln ~/ 12} th ${bln % 12} bln' : '$bln bln';
}

class OrangTuaHome extends StatefulWidget {
  const OrangTuaHome({super.key});

  @override
  State<OrangTuaHome> createState() => _OrangTuaHomeState();
}

class _OrangTuaHomeState extends State<OrangTuaHome> {
  int _aktif = 0;

  // Data anak dari server (GET /keluarga)
  List<DataAnak> _daftar = [];
  bool _memuat = true;
  String? _gagal;

  // Jadwal terdekat dari server (GET /jadwal/terdekat). Null = tidak ada jadwal aktif.
  JadwalTerdekatData? _jadwal;

  DataAnak? get _anak => _daftar.isEmpty ? null : _daftar[_aktif];
  _Anak get _contoh => _daftarAnak[_aktif % _daftarAnak.length];

  AnakStatusJadwal? get _statusAnak {
    final a = _anak;
    final j = _jadwal;
    if (a == null || j == null) return null;
    for (final s in j.anak) {
      if (s.anakId == a.id) return s;
    }
    return null;
  }

  String get _hadir => _statusAnak?.status ?? 'belum_daftar';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  // Ambil daftar anak dan jadwal terdekat dari server
  Future<void> _muat() async {
    JadwalTerdekatData? jadwal;
    try {
      jadwal = await JadwalTerdekatData.ambil();
    } catch (_) {
      jadwal = null;
    }

    try {
      final data = await KeluargaApi.ambil();
      final daftar = ((data['anak'] as List?) ?? [])
          .map((e) => DataAnak.fromApi(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        _daftar = daftar;
        _jadwal = jadwal;
        if (_aktif >= daftar.length) _aktif = 0;
        _gagal = null;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gagal = 'Gagal memuat data anak dari server.';
        _memuat = false;
      });
    }
  }

  Future<void> _bukaPendaftaran() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrangTuaPendaftaranPage()),
    );
    _muat();
  }

  void _bukaBukuPanduan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BukuPanduanPage()),
    );
  }

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrangTuaVaksinPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HomeShell(
      peran: 'Orang Tua',
      lokasi: 'Posyandu Melati RW 05',
      notif: 2,
      children: [
        KartuLengkapiKeluarga(onKembali: _muat),
        if (_memuat)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_gagal != null)
          _kartuGagal()
        else if (_daftar.isEmpty)
          _kartuBelumAdaAnak()
        else ...[
          _pilihAnak(),
          _kartuDigital(),
          _jadwalPosyandu(),
          if (_tampilDataContoh) ...[
            _hasilTerakhir(),
            _grafikKms(),
            _imunisasi(),
            _riwayatKunjungan(),
          ] else
            _belumAdaPemeriksaan(),
          _kartuVaksin(),
          _aksiCepat(),
        ],
      ],
    );
  }

  Widget _kartuGagal() {
    return SectionCard(
      color: AppColors.kuningMuda,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.kuning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_gagal!,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _memuat = true);
              _muat();
            },
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _kartuBelumAdaAnak() {
    return SectionCard(
      title: 'Data Anak',
      icon: Icons.child_care,
      child: const Text(
        'Belum ada data anak. Tambahkan lewat "Lengkapi Data Keluarga" di atas.',
        style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
      ),
    );
  }

  Widget _belumAdaPemeriksaan() {
    return SectionCard(
      title: 'Hasil Pemeriksaan',
      icon: Icons.monitor_heart_outlined,
      child: const Text(
        'Belum ada data pemeriksaan. Berat badan, tinggi badan, grafik KMS, dan imunisasi akan muncul setelah anak diperiksa di posyandu.',
        style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
      ),
    );
  }

  // Pintasan ke halaman rencana dan riwayat vaksin (hanya lihat).
  Widget _kartuVaksin() {
    return SectionCard(
      title: 'Vaksin Anak',
      icon: Icons.vaccines_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lihat jadwal vaksin berikutnya yang ditetapkan bidan dan riwayat vaksin yang sudah diterima anak.',
            style: TextStyle(fontSize: 12, color: AppColors.teksRedup),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: AppButton('Lihat Rencana & Riwayat Vaksin',
                icon: Icons.event_available_outlined, onPressed: _bukaVaksin),
          ),
        ],
      ),
    );
  }

  // OT-02: satu akun bisa memuat lebih dari satu anak, pilih anak aktif.
  Widget _pilihAnak() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _daftar.length; i++)
            ChoiceChip(
              selected: i == _aktif,
              selectedColor: AppColors.hijau,
              backgroundColor: Colors.white,
              label: Text('${_daftar[i].nama} · ${_usiaAnak(_daftar[i].tglLahir)}'),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: i == _aktif ? Colors.white : Colors.black87,
              ),
              onSelected: (_) => setState(() => _aktif = i),
            ),
        ],
      ),
    );
  }

  // OT-08: kartu anak digital dengan kode QR untuk check-in.
  Widget _kartuDigital() {
    final anak = _anak!;
    final terdaftar = _hadir == 'terdaftar' || _hadir == 'sudah_checkin';
    final nomor = _statusAnak?.nomorAntrean;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.hijau,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('KARTU DIGITAL ANAK POSYANDU',
                  style: TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: anak.kodeQr.isEmpty ? 'PSY-${anak.id}' : anak.kodeQr,
                    size: 76,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nama Lengkap Anak',
                          style: TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
                      Text(anak.nama,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Pill(
                              terdaftar
                                  ? (nomor != null ? 'Antrean #$nomor' : 'Terdaftar')
                                  : 'Belum terdaftar',
                              bg: terdaftar ? AppColors.hijauMuda : AppColors.isiField,
                              fg: terdaftar ? AppColors.hijau : AppColors.teksRedup),
                          if (_hadir == 'sudah_checkin')
                            const Pill('Siap Check-in',
                                bg: AppColors.hijauMuda,
                                fg: AppColors.hijau,
                                icon: Icons.check_circle),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Perlihatkan barcode ini ke Meja 1 Pendaftaran saat tiba di balai.',
                          style: TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _tombolKartu(Icons.zoom_out_map, 'Perbesar', () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(anak.nama),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QrImageView(
                            data: anak.kodeQr.isEmpty ? 'PSY-${anak.id}' : anak.kodeQr,
                            size: 220,
                          ),
                          const SizedBox(height: 8),
                          const Text('Tunjukkan kode ini kepada kader di Meja 1'),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tombolKartu(
                    Icons.picture_as_pdf, 'Unduh PDF', () => soon(context, 'Unduh ringkasan PDF')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tombolKartu(Icons.share, 'Bagikan', () => soon(context, 'Bagikan kartu')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tombolKartu(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }

  // OT-05: info jadwal terdekat. Pendaftaran dan check-in ada di halaman terpisah.
  Widget _jadwalPosyandu() {
    final j = _jadwal;
    if (j == null) {
      return SectionCard(
        title: 'Jadwal Posyandu Terdekat',
        icon: Icons.event_note,
        child: const Text(
          'Belum ada jadwal posyandu mendatang.',
          style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
        ),
      );
    }

    final (labelStatus, bg, fg) = labelStatusHadir(_hadir);

    return SectionCard(
      title: 'Jadwal Posyandu Terdekat',
      icon: Icons.event_note,
      trailing: Pill(labelStatus, bg: bg, fg: fg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${formatTanggal(j.tanggal)} · ${j.jam} WIB',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          if (j.lokasi.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(j.lokasi, style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.kuningMuda,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              [
                if (j.pendaftaranBuka != null)
                  'Pendaftaran dibuka ${formatTanggal(j.pendaftaranBuka!)}.',
                if (j.checkinBuka != null)
                  'Check-in dibuka 1 jam sebelum mulai (${formatJam(j.checkinBuka!)}).',
              ].join(' '),
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 12),
          AppButton('Buka Pendaftaran & Check-in',
              icon: Icons.how_to_reg, onPressed: _bukaPendaftaran),
        ],
      ),
    );
  }

  // OT-03: hasil pemeriksaan terakhir, status gizi warna, catatan bidan.
  Widget _hasilTerakhir() {
    final a = _contoh;
    return SectionCard(
      title: 'Hasil Pemeriksaan Terakhir',
      icon: Icons.monitor_heart_outlined,
      trailing: Text(a.tglPeriksa,
          style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: StatBox(
                      nilai: '${a.bb}', label: 'Berat (kg)\n+${a.selisihBb} dari bulan lalu')),
              const SizedBox(width: 8),
              Expanded(child: StatBox(nilai: '${a.tb}', label: 'Tinggi/Panjang (cm)')),
              const SizedBox(width: 8),
              Expanded(child: StatBox(nilai: '${a.lk}', label: 'Lingkar Kepala (cm)')),
              const SizedBox(width: 8),
              Expanded(child: StatBox(nilai: '${a.lla}', label: 'Lingkar Lengan (cm)')),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Status Gizi', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill('BB/U: ${a.bbu.$1}', bg: giziBg(a.bbu.$2), fg: giziFg(a.bbu.$2)),
              Pill('TB/U: ${a.tbu.$1}', bg: giziBg(a.tbu.$2), fg: giziFg(a.tbu.$2)),
              Pill('BB/TB: ${a.bbtb.$1}', bg: giziBg(a.bbtb.$2), fg: giziFg(a.bbtb.$2)),
            ],
          ),
          if (a.peringatan != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.merahMuda,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.merah, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(a.peringatan!, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.hijauMuda,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Catatan Bidan Ratna',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text(a.catatanBidan, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _bukaBukuPanduan,
              child: const Text('Buka Buku Panduan →',
                  style: TextStyle(color: AppColors.hijau, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // OT-03 #3: grafik perkembangan terhadap kurva standar.
  Widget _grafikKms() {
    final a = _contoh;
    final sekarang = DateTime.now();
    final label = [
      for (var i = a.kmsBb.length - 1; i >= 0; i--)
        bulanSingkat(DateTime(sekarang.year, sekarang.month - i, 1)),
    ];
    return SectionCard(
      title: 'Grafik Pertumbuhan KMS',
      icon: Icons.show_chart,
      trailing: const Pill('BB/U'),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _KmsPainter(a.kmsBb, a.kmsBawah, a.kmsAtas),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in label)
                Text(l, style: const TextStyle(fontSize: 10, color: AppColors.teksRedup)),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legenda(Color(0xFFCFEBDD), 'Pita hijau (normal)'),
              SizedBox(width: 14),
              _Legenda(AppColors.hijau, 'Berat badan anak'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton('Unduh Grafik KMS Resmi (PDF)',
                icon: Icons.download, filled: false,
                onPressed: () => soon(context, 'Unduh PDF')),
          ),
        ],
      ),
    );
  }

  // OT-04: riwayat vaksin, saran vaksin berikutnya, vaksin terlewat, vitamin A.
  Widget _imunisasi() {
    final a = _contoh;
    return SectionCard(
      title: 'Imunisasi & Suplemen',
      icon: Icons.vaccines_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sudah diberikan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in a.vaksinSelesai) Pill(v, icon: Icons.check),
            ],
          ),
          const SizedBox(height: 10),
          _baris(Icons.event_available, 'Saran berikutnya', a.vaksinBerikutnya, AppColors.biru),
          if (a.vaksinTerlewat != null)
            _baris(Icons.error_outline, 'Terlewat / belum lengkap', a.vaksinTerlewat!, AppColors.merah),
          _baris(Icons.wb_sunny_outlined, 'Suplemen', a.vitaminA, AppColors.kuning),
          _baris(Icons.medication_outlined, 'Obat cacing', a.obatCacing, AppColors.teksRedup),
        ],
      ),
    );
  }

  Widget _baris(IconData icon, String judul, String isi, Color warna) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: warna),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: TextStyle(fontSize: 11, color: warna, fontWeight: FontWeight.w800)),
                Text(isi, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // OT-03 #1: riwayat pemeriksaan tiap posyandu.
  Widget _riwayatKunjungan() {
    const riwayat = [
      ('14 Sep 2024', 'Naik (OK)', '2 Th 3 Bln · BB 12.4 kg · TB 88.5 cm'),
      ('10 Agu 2024', 'Naik (OK)', '2 Th 2 Bln · BB 12.1 kg · TB 87.8 cm'),
      ('13 Jul 2024', 'Naik (OK)', '2 Th 1 Bln · BB 11.8 kg · TB 87.1 cm'),
    ];
    return SectionCard(
      title: 'Riwayat Kunjungan Posyandu',
      icon: Icons.history,
      child: Column(
        children: [
          for (final r in riwayat)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(width: 8),
                  Pill(r.$2),
                ],
              ),
              subtitle: Text(r.$3, style: const TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => soon(context, 'Detail pemeriksaan'),
            ),
        ],
      ),
    );
  }

  Widget _aksiCepat() {
    Widget item(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.hijauMuda,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.hijau),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );

    return SectionCard(
      title: 'Aksi Cepat Layanan',
      child: Row(
        children: [
          item(Icons.how_to_reg, 'Pendaftaran\nPosyandu', _bukaPendaftaran),
          item(Icons.show_chart, 'Riwayat\nKMS', () => soon(context, 'Riwayat KMS')),
          item(Icons.vaccines, 'Jadwal\nVaksin', _bukaVaksin),
          item(Icons.menu_book, 'Buku\nPanduan', _bukaBukuPanduan),
        ],
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color warna;
  final String teks;
  const _Legenda(this.warna, this.teks);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(teks, style: const TextStyle(fontSize: 10.5)),
      ],
    );
  }
}

/// Menggambar pita hijau (batas bawah-atas) dan garis berat badan anak.
class _KmsPainter extends CustomPainter {
  final List<double> bb;
  final List<double> bawah;
  final List<double> atas;
  _KmsPainter(this.bb, this.bawah, this.atas);

  @override
  void paint(Canvas canvas, Size size) {
    final n = bb.length;
    if (n < 2) return;
    final minY = math.min(bawah.reduce(math.min), bb.reduce(math.min)) - 0.5;
    final maxY = math.max(atas.reduce(math.max), bb.reduce(math.max)) + 0.5;
    final dx = size.width / (n - 1);
    double y(double v) => size.height - (v - minY) / (maxY - minY) * size.height;

    final grid = Paint()
      ..color = const Color(0xFFE5E5EE)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final gy = size.height * i / 3;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }

    final pita = Path()..moveTo(0, y(atas[0]));
    for (var i = 1; i < n; i++) {
      pita.lineTo(dx * i, y(atas[i]));
    }
    for (var i = n - 1; i >= 0; i--) {
      pita.lineTo(dx * i, y(bawah[i]));
    }
    pita.close();
    canvas.drawPath(pita, Paint()..color = const Color(0xFFCFEBDD));

    final garis = Paint()
      ..color = AppColors.hijau
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final jalur = Path()..moveTo(0, y(bb[0]));
    for (var i = 1; i < n; i++) {
      jalur.lineTo(dx * i, y(bb[i]));
    }
    canvas.drawPath(jalur, garis);

    final titik = Paint()..color = AppColors.hijau;
    final putih = Paint()..color = Colors.white;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(dx * i, y(bb[i])), 5, putih);
      canvas.drawCircle(Offset(dx * i, y(bb[i])), 3.5, titik);
    }
  }

  @override
  bool shouldRepaint(covariant _KmsPainter old) =>
      old.bb != bb || old.bawah != bawah || old.atas != atas;
}