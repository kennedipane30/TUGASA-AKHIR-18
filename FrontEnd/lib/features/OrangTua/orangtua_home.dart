import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../core/posyandu.dart';
import '../auth/auth_provider.dart';
import 'bukupanduan/buku_panduan_page.dart';
import 'datadiri/lengkapi_keluarga_page.dart';
import 'pendaftaran/orangtua_pendaftaran_page.dart';
import 'riwayat/orangtua_grafik_page.dart';
import 'riwayat/orangtua_pemeriksaan_page.dart';
import 'vaksin/orangtua_vaksin_page.dart';

// Warna aksen
const _oranye = Color(0xFFFF6A13);
const _hijauAtas = Color(0xFF07654A);
const _hijauBawah = Color(0xFF054D3A);
const _mint = Color(0xFF8CF0CB);
const _hijauTeks = Color(0xFF065F46);

// Ikon menu: file PNG berada langsung di folder FrontEnd (sejajar pubspec.yaml)
// dan sudah didaftarkan di pubspec.yaml:
//   flutter:
//     assets:
//       - logo.png
//       - buku_panduan.png
//       - data_keluarga.png
//       - grafik_anak.png
//       - pendaftaran.png
//       - hasil_pemeriksaan.png
//       - vaksin_anak.png
const _aset = '';

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

String _kapital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _namaHari = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

class OrangTuaHome extends StatefulWidget {
  const OrangTuaHome({super.key});

  @override
  State<OrangTuaHome> createState() => _OrangTuaHomeState();
}

class _OrangTuaHomeState extends State<OrangTuaHome> {
  int _aktif = 0;

  List<DataAnak> _daftar = [];
  bool _memuat = true;
  String? _gagal;

  JadwalTerdekatData? _jadwal;

  DataAnak? get _anak => _daftar.isEmpty ? null : _daftar[_aktif];

  AnakStatusJadwal? _statusAnakDari(DataAnak a) {
    final j = _jadwal;
    if (j == null) return null;
    for (final s in j.anak) {
      if (s.anakId == a.id) return s;
    }
    return null;
  }

  AnakStatusJadwal? get _statusAnak {
    final a = _anak;
    if (a == null) return null;
    return _statusAnakDari(a);
  }

  String get _hadir => _statusAnak?.status ?? 'belum_daftar';

  @override
  void initState() {
    super.initState();
    _muat();
  }

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

  void _bukaPemeriksaan() {
    final a = _anak;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaPemeriksaanPage(anakId: a?.id?.toString()),
      ),
    );
  }

  void _bukaGrafik() {
    final a = _anak;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaGrafikPage(anakId: a?.id?.toString()),
      ),
    );
  }

  Future<void> _bukaDataKeluarga() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.latar,
          appBar: AppBar(
            title: const Text('Data Keluarga'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [KartuLengkapiKeluarga(onKembali: _muat)],
          ),
        ),
      ),
    );
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    final pos = (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();
    final lokasi = pos.isEmpty
        ? 'Posyandu belum ditetapkan, hubungi admin'
        : 'Posyandu ${labelPosyandu(pos)}';

    return HomeShell(
      peran: 'Orang Tua',
      lokasi: lokasi,
      notif: 2,
      children: [
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
          _kartuAnak(),
          _jadwalPosyandu(),
          _layananPosyandu(),
          _tipsHariIni(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Belum ada data anak. Lengkapi data keluarga terlebih dahulu.',
            style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: AppButton('Lengkapi Data Keluarga',
                icon: Icons.family_restroom, onPressed: _bukaDataKeluarga),
          ),
        ],
      ),
    );
  }

  void _pilihAnakSheet() {
    if (_daftar.length < 2) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Pilih Anak',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            for (var i = 0; i < _daftar.length; i++)
              ListTile(
                leading: Icon(
                  i == _aktif ? Icons.check_circle : Icons.circle_outlined,
                  color: i == _aktif ? AppColors.hijau : AppColors.teksRedup,
                ),
                title: Text(_daftar[i].nama,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_usiaAnak(_daftar[i].tglLahir)),
                onTap: () {
                  setState(() => _aktif = i);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Wadah kartu hijau dengan lingkaran dekoratif transparan.
  Widget _kartuHijau({required EdgeInsets padding, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_hijauAtas, _hijauBawah],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x26054D3A), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -34,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: -46,
              bottom: -56,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  // Kartu kecil: pemilih anak + label urutan anak.
  Widget _kartuAnak() {
    final anak = _anak;

    return _kartuHijau(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pilihAnakSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(Icons.child_care,
                        color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${anak?.nama ?? '-'} - ${_usiaAnak(anak?.tglLahir ?? '')}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FBF3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Anak Pertama',
                style: TextStyle(
                    color: _hijauTeks,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // Kartu gabungan: sapaan + status check-in + jadwal terdekat.
  Widget _jadwalPosyandu() {
    final j = _jadwal;
    final user = context.watch<AuthProvider>().user;
    final namaUser = (user?['nama'] ?? '').toString();
    final pos = (user?['posyandu'] ?? '').toString();
    final anak = _anak;
    final (labelStatus, _, _) = labelStatusHadir(_hadir);
    final sudah = _hadir != 'belum_daftar';

    final kepala = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                namaUser.isEmpty ? 'Halo, Bunda' : 'Halo, $namaUser',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                _kapital(anak?.nama ?? '-'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE9FBF3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sudah ? Icons.check_rounded : Icons.schedule,
                color: _hijauTeks,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                sudah ? 'Sudah check-in' : labelStatus,
                style: const TextStyle(
                    color: _hijauTeks,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );

    final garis = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.12)),
    );

    if (j == null) {
      return _kartuHijau(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            kepala,
            garis,
            const Text('Jadwal Posyandu Terdekat',
                style: TextStyle(
                    color: _mint, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
                pos.isEmpty
                    ? 'Belum ada jadwal posyandu mendatang.'
                    : 'Belum ada jadwal mendatang untuk Posyandu ${labelPosyandu(pos)}.',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      );
    }

    final hariIni = DateTime.now();
    final selisih = DateTime(j.tanggal.year, j.tanggal.month, j.tanggal.day)
        .difference(DateTime(hariIni.year, hariIni.month, hariIni.day))
        .inDays;
    final hitung = selisih <= 0 ? 'HARI INI' : 'H-$selisih HARI';
    final hari = _namaHari[j.tanggal.weekday - 1];

    return _kartuHijau(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kepala,
          garis,
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Jadwal Posyandu Terdekat',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(hitung,
                    style: const TextStyle(
                        color: _mint,
                        fontSize: 11.5,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(j.lokasi.isNotEmpty ? j.lokasi : 'Posyandu',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _mint, width: 1.6),
                ),
                child: const Icon(Icons.access_time_rounded,
                    color: _mint, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$hari, ${formatTanggal(j.tanggal)} • ${j.jam} WIB',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (j.checkinBuka != null) ...[
            const SizedBox(height: 14),
            Text(
              'Pendaftaran dapat dilakukan kapan saja. '
              'Check-in scan QR dibuka 1 jam sebelum mulai (${formatJam(j.checkinBuka!)}).',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x66FF6A13),
                    blurRadius: 14,
                    offset: Offset(0, 6)),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _oranye,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _bukaPendaftaran,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Buka Pendaftaran & Check-in',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Layanan Posyandu: ikon tetap 54, kartu dikecilkan, jarak antar kartu dilebarkan.
  Widget _layananPosyandu() {
    final menu = <(String, IconData, String, Color, VoidCallback)>[
      ('${_aset}pendaftaran.png', Icons.person_add_alt_1_rounded,
          'Pendaftaran\nPosyandu', const Color(0xFF0B6B55), _bukaPendaftaran),
      ('${_aset}hasil_pemeriksaan.png', Icons.assignment_rounded,
          'Hasil\nPemeriksaan', const Color(0xFF0369A1), _bukaPemeriksaan),
      ('${_aset}grafik_anak.png', Icons.show_chart_rounded, 'Grafik\nAnak',
          const Color(0xFF0B6B55), _bukaGrafik),
      ('${_aset}vaksin_anak.png', Icons.vaccines_rounded, 'Vaksin\nAnak',
          const Color(0xFF2563EB), _bukaVaksin),
      ('${_aset}buku_panduan.png', Icons.menu_book_rounded, 'Buku\nPanduan',
          const Color(0xFF2563EB), _bukaBukuPanduan),
      ('${_aset}data_keluarga.png', Icons.family_restroom_rounded,
          'Data\nKeluarga', const Color(0xFF0B6B55), _bukaDataKeluarga),
    ];

    Widget item((String, IconData, String, Color, VoidCallback) m) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 3)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: m.$5,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: Image.asset(
                          m.$1,
                          width: 54,
                          height: 54,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFD9F7EA),
                            ),
                            child: Icon(m.$2, color: m.$4, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(m.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: Color(0xFF0F2547),
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    final baris = <Widget>[];
    for (var i = 0; i < menu.length; i += 4) {
      final potong = menu.sublist(i, math.min(i + 4, menu.length));
      baris.add(Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in potong) item(m),
              for (var k = potong.length; k < 4; k++)
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('Layanan Posyandu',
                      style: TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800)),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Layanan Utama',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teksRedup)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 14),
            child: Text('Pilih menu layanan kesehatan balita',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.teksRedup)),
          ),
          ...baris,
        ],
      ),
    );
  }

  // Kartu tips harian.
  Widget _tipsHariIni() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEBFBF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCDEFDD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hijauTeks,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TIPS POSYANDU HARI INI',
                    style: TextStyle(
                        color: _hijauTeks,
                        fontSize: 12.5,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  'Bawalah buku KIA fisik jika ini kunjungan pertama, '
                  'dan pastikan bayi sudah cukup minum susu sebelum penimbangan.',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}