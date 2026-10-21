import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../core/posyandu.dart';
import '../OrangTua/pendaftaran/orangtua_pendaftaran_page.dart';
import '../auth/auth_provider.dart';
import 'pendataan/kader_pendataan_page.dart';
import 'vaksin/kader_vaksin_page.dart';

// Warna tampilan
const _hijauTua = Color(0xFF065F46);
const _hijauGelap = Color(0xFF054D3A);
const _hijauAtas = Color(0xFF07654A);
const _mint = Color(0xFF8CF0CB);
const _oranye = Color(0xFFFF7A00);
const _teksGelap = Color(0xFF0F172A);
const _teksAbu = Color(0xFF64748B);
const _teksBiru = Color(0xFF7C8DA6);
const _biruVaksin = Color(0xFF0B7FBF);

class KaderHome extends StatefulWidget {
  const KaderHome({super.key});

  @override
  State<KaderHome> createState() => _KaderHomeState();
}

class _KaderHomeState extends State<KaderHome> {
  JadwalTerdekatData? _jadwal;
  List<AntreanKader> _antrean = [];
  bool _memuat = true;
  String? _gagal;

  bool _sinkronBerjalan = false;
  int _tertunda = 0;
  String _sinkronTerakhir = 'baru saja';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      final list = j == null ? <AntreanKader>[] : await AntreanKader.ambil(j.id);
      if (!mounted) return;
      setState(() {
        _jadwal = j;
        _antrean = list;
        _gagal = null;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gagal = 'Gagal memuat data antrean dari server.';
        _memuat = false;
      });
    }
  }

  Future<void> _sinkronkan() async {
    setState(() => _sinkronBerjalan = true);
    await _muat();
    if (!mounted) return;
    setState(() {
      _sinkronBerjalan = false;
      _tertunda = 0;
      _sinkronTerakhir = 'baru saja';
    });
  }

  Future<void> _bukaAntrean() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderPendataanPage()),
    );
    _muat();
  }

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderVaksinPage()),
    );
  }

  // -------------------------------------------------------------------------
  // Komponen umum
  // -------------------------------------------------------------------------
  Widget _kartuPutih({required Widget child, EdgeInsets? padding, Color? color, Color? border}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: border == null ? null : Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E293B), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _kepalaKartu(IconData ikon, String judul, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: Color(0xFFE6F8EF), shape: BoxShape.circle),
          child: Icon(ikon, size: 18, color: _hijauTua),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(judul,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w800, color: _teksGelap)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _kartuGagal() {
    return _kartuPutih(
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

  @override
  Widget build(BuildContext context) {
    final pos = (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();
    final lokasi = pos.isEmpty
        ? 'Posyandu belum ditetapkan, hubungi admin'
        : 'Posyandu ${labelPosyandu(pos)}';

    final j = _jadwal;
    final hadir = _antrean.length;
    final diukur = _antrean.where((a) => a.sudahDiukur).length;
    final menunggu = hadir - diukur;
    final belumDiukur = _antrean.where((a) => !a.sudahDiukur).toList();

    return HomeShell(
      peran: 'Kader',
      lokasi: lokasi,
      notif: 3,
      children: [
        if (_memuat)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_gagal != null)
          _kartuGagal()
        else if (j == null)
          _kartuPutih(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kepalaKartu(Icons.event_busy, 'Jadwal $lokasi'),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada jadwal aktif untuk posyandu Anda. Antrean pendataan muncul setelah admin menerbitkan jadwal.',
                  style: TextStyle(fontSize: 12.5, color: _teksAbu, height: 1.4),
                ),
              ],
            ),
          )
        else ...[
          _sesiTerdekat(j),
          _kehadiran(hadir, diukur, menunggu),
          _antreanPendataan(),
        ],

        // Layanan utama kader
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Text('LAYANAN UTAMA KADER',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                  color: _teksAbu)),
        ),
        _layananUtama(),

        // Menunggu pengukuran
        if (!_memuat && _gagal == null && j != null) _menungguPengukuran(belumDiukur),

        // Vaksin anak
        _vaksinAnak(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Sesi terdekat
  // -------------------------------------------------------------------------
  Widget _sesiTerdekat(JadwalTerdekatData j) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9FBF3), Color(0xFFD7F7E8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB9EBD2)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month_outlined,
                color: _hijauTua, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SESI POSYANDU TERDEKAT',
                    style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w800,
                        color: _hijauTua)),
                const SizedBox(height: 2),
                Text(formatTanggal(j.tanggal),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: _teksGelap)),
                if (j.lokasi.isNotEmpty)
                  Text(j.lokasi,
                      style: const TextStyle(fontSize: 11.5, color: _teksAbu)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(j.jam.replaceAll(' - ', ' -\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: _teksGelap)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Kehadiran balita
  // -------------------------------------------------------------------------
  Widget _kotakAngka(String nilai, String label, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(nilai,
                style: TextStyle(
                    fontSize: 30, height: 1.1, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: _teksGelap)),
          ],
        ),
      ),
    );
  }

  Widget _kehadiran(int hadir, int diukur, int menunggu) {
    return _kartuPutih(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepalaKartu(
            Icons.groups_2_outlined,
            'Kehadiran Balita',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F8EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Hari Ini',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: _hijauTua)),
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kotakAngka('$hadir', 'Sudah\ncheck-in', const Color(0xFFE7F1FD),
                    _teksGelap),
                const SizedBox(width: 10),
                _kotakAngka('$diukur', 'Sudah\ndiukur', const Color(0xFFE6F5EC),
                    _hijauTua),
                const SizedBox(width: 10),
                _kotakAngka('$menunggu', 'Menunggu\npengukuran',
                    const Color(0xFFFFEFDD), const Color(0xFFB45309)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: hadir == 0 ? 0 : diukur / hadir,
              minHeight: 8,
              backgroundColor: const Color(0xFFE9EEF3),
              color: _hijauTua,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text('$diukur dari $hadir balita yang check-in sudah diukur',
                style: const TextStyle(fontSize: 11.5, color: _teksAbu)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Antrean pendataan
  // -------------------------------------------------------------------------
  Widget _antreanPendataan() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_hijauAtas, _hijauGelap],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x26054D3A), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              bottom: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      const Text('Antrean Pendataan',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Orang tua check-in dengan scan QR. Balita yang sudah check-in otomatis masuk antrean ini.',
                    style: TextStyle(color: _mint, fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x66FF7A00),
                            blurRadius: 14,
                            offset: Offset(0, 6)),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _oranye,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _bukaAntrean,
                      icon: const Icon(Icons.sort_rounded, size: 22),
                      label: const Text('Antrian Pendaftaran',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Layanan utama kader
  // -------------------------------------------------------------------------
  Widget _layananUtama() {
    final menu = <(IconData, String, Color, Color, VoidCallback)>[
      (Icons.qr_code_2_rounded, 'QR\nCheck-in\nPosyandu', const Color(0xFFE7F1FD),
          const Color(0xFF1D6FD6), _bukaAntrean),
      (Icons.calendar_view_week_rounded, 'Ukur Data\nBB TB LiLA',
          const Color(0xFFE3F8EE), const Color(0xFF0B6B55), _bukaAntrean),
      (Icons.person_add_alt_1_outlined, 'Daftar\nBalita Baru',
          const Color(0xFFFFF4D9), const Color(0xFFEA580C),
          () => soon(context, 'Pendataan balita baru')),
      (Icons.science_outlined, 'Jadwal &\nRiwayat', const Color(0xFFE0F7F4),
          const Color(0xFF0E8F7E), _bukaVaksin),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < menu.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _itemLayanan(menu[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemLayanan((IconData, String, Color, Color, VoidCallback) m) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: m.$5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: m.$3,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(m.$1, color: m.$4, size: 26),
                ),
                const SizedBox(height: 10),
                Text(m.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: _teksGelap)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Menunggu pengukuran
  // -------------------------------------------------------------------------
  Widget _menungguPengukuran(List<AntreanKader> belumDiukur) {
    return _kartuPutih(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered_rounded,
                  size: 24, color: _hijauTua),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Menunggu Pengukuran',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: _teksGelap)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F8EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${belumDiukur.length} menunggu',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _hijauTua)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (belumDiukur.isEmpty)
            const Text('Tidak ada balita yang menunggu pengukuran saat ini.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: _teksBiru))
          else
            for (final a in belumDiukur) _barisAntrean(a),
        ],
      ),
    );
  }

  Widget _barisAntrean(AntreanKader a) {
    final usia = a.usiaBulan >= 12
        ? '${a.usiaBulan ~/ 12} th ${a.usiaBulan % 12} bln'
        : '${a.usiaBulan} bln';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE6F8EF),
            child: Text(a.nomor?.toString() ?? '-',
                style: const TextStyle(
                    color: _hijauTua, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nama,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: _teksGelap)),
                const SizedBox(height: 2),
                Text('${a.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · $usia',
                    style: const TextStyle(fontSize: 11, color: _teksAbu)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F8EF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Sudah check-in',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _hijauTua)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hijauTua,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _bukaAntrean,
              child: const Text('Ukur\nSekarang',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12, height: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Vaksin anak
  // -------------------------------------------------------------------------
  Widget _vaksinAnak() {
    return _kartuPutih(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7F4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.vaccines_outlined,
                    color: Color(0xFF0E8F7E), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vaksin Anak',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _teksGelap)),
                    const SizedBox(height: 6),
                    const Text(
                      'Cari anak di posyandu Anda untuk melihat rencana vaksin yang ditetapkan bidan dan riwayat vaksin yang sudah diterima.',
                      style: TextStyle(
                          fontSize: 12.5, height: 1.5, color: _teksBiru),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _biruVaksin,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _bukaVaksin,
              icon: const Icon(Icons.event_available_outlined, size: 20),
              label: const Text('Lihat Rencana & Riwayat Vaksin',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }
}