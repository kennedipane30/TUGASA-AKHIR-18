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
import 'riwayat/orangtua_pemeriksaan_page.dart';
import 'vaksin/orangtua_vaksin_page.dart';

// Warna aksen
const _oranye = Color(0xFFFF7A1A);
const _hijauTua = Color(0xFF0B4A38);
const _hijauGelap = Color(0xFF0E5A43);
const _mint = Color(0xFF9FF0D0);

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

  void _bukaKartuDigital() {
    if (_daftar.isEmpty) {
      soon(context, 'Kartu digital (belum ada data anak)');
      return;
    }
    soon(context, 'Kartu digital');
  }

  void _bukaPemeriksaan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrangTuaPemeriksaanPage()),
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

  // Pilih anak aktif lewat bottom sheet bila lebih dari satu anak.
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

  // Kartu identitas anak aktif + status check-in.
  Widget _kartuAnak() {
    final user = context.watch<AuthProvider>().user;
    final namaUser = (user?['nama'] ?? '').toString();
    final anak = _anak;
    final (labelStatus, _, _) = labelStatusHadir(_hadir);
    final sudah = _hadir != 'belum_daftar';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_hijauGelap, _hijauTua],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pilihAnakSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.child_care, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${anak?.nama ?? '-'} · ${_usiaAnak(anak?.tglLahir ?? '')}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700),
                      ),
                      if (_daftar.length > 1) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Anak Pertama',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaUser.isEmpty ? 'Halo, Bunda' : 'Halo, $namaUser',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      anak?.nama ?? '-',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sudah ? Icons.check_circle_outline : Icons.schedule,
                      color: AppColors.hijau,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      sudah ? 'Sudah check-in' : labelStatus,
                      style: const TextStyle(
                          color: AppColors.hijau,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Kartu jadwal terdekat.
  Widget _jadwalPosyandu() {
    final j = _jadwal;
    final pos = (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();

    final dekorasi = BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_hijauGelap, _hijauTua],
      ),
    );

    if (j == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: dekorasi,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jadwal Posyandu Terdekat',
                style: TextStyle(
                    color: _mint, fontSize: 11, fontWeight: FontWeight.w800)),
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: dekorasi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Jadwal Posyandu Terdekat',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _hijauTua,
                  border: Border.all(color: _mint.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(hitung,
                    style: const TextStyle(
                        color: _mint, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(j.lokasi.isNotEmpty ? j.lokasi : 'Posyandu',
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: _mint, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$hari, ${formatTanggal(j.tanggal)} • ${j.jam} WIB',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (j.checkinBuka != null) ...[
            const SizedBox(height: 10),
            Text(
              'Pendaftaran dapat dilakukan kapan saja. '
              'Check-in scan QR dibuka 1 jam sebelum mulai (${formatJam(j.checkinBuka!)}).',
              style: const TextStyle(color: _mint, fontSize: 11, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _oranye,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _bukaPendaftaran,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Buka Pendaftaran & Check-in',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Layanan Posyandu: deretan ikon menu (4 per baris).
  Widget _layananPosyandu() {
    final menu = <(IconData, String, Color, Color, VoidCallback)>[
      (Icons.person_add_alt_1_outlined, 'Pendaftaran\nPosyandu',
          const Color(0xFFD3F5E8), AppColors.hijau, _bukaPendaftaran),
      (Icons.bar_chart_rounded, 'Hasil\nPemeriksaan', const Color(0xFFFFE3D3),
          _oranye, _bukaPemeriksaan),
      (Icons.science_outlined, 'Vaksin\nAnak', const Color(0xFFFFE3D3), _oranye,
          _bukaVaksin),
      (Icons.menu_book_outlined, 'Buku\nPanduan', const Color(0xFFE1E4FF),
          const Color(0xFF4F5BD5), _bukaBukuPanduan),
      (Icons.groups_outlined, 'Data\nKeluarga', const Color(0xFFD3F5E8),
          AppColors.hijau, _bukaDataKeluarga),
    ];

    Widget item((IconData, String, Color, Color, VoidCallback) m) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: m.$5,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.isiField),
              ),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: m.$3,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(m.$1, color: m.$4),
                  ),
                  const SizedBox(height: 8),
                  Text(m.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        );

    final baris = <Widget>[];
    for (var i = 0; i < menu.length; i += 4) {
      final potong = menu.sublist(i, math.min(i + 4, menu.length));
      baris.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in potong) item(m),
            for (var k = potong.length; k < 4; k++)
              const Expanded(child: SizedBox()),
          ],
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 6, 2, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text('Layanan Posyandu',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                Text('Layanan Utama',
                    style: TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 2, 2, 10),
            child: Text('Pilih menu layanan kesehatan balita',
                style: TextStyle(fontSize: 11, color: AppColors.teksRedup)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB7E8D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.hijau,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TIPS POSYANDU HARI INI',
                    style: TextStyle(
                        color: _hijauTua,
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  'Bawalah buku KIA fisik jika ini kunjungan pertama, '
                  'dan pastikan bayi sudah cukup minum susu sebelum penimbangan.',
                  style: TextStyle(fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}