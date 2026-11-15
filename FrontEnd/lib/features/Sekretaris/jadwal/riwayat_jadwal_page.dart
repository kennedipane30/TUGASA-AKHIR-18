import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'jadwal_page.dart';
import 'riwayat_jadwal_detail_page.dart';

const _hijauHeader = Color(0xFF065F46);
const teksGelapRiwayat = Color(0xFF1F2937);

String _pesan(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return 'Tidak dapat terhubung ke server.';
  }
  return 'Terjadi kesalahan: $e';
}

String _jam(dynamic v) {
  final s = v?.toString() ?? '';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

int _i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

class RiwayatJadwal {
  final String id;
  final DateTime tanggal;
  final String jam;
  final String lokasi;
  final int terdaftar, checkin, batal, tidakHadir;

  RiwayatJadwal(Map<String, dynamic> j)
      : id = j['id']?.toString() ?? '',
        tanggal = DateTime.tryParse(
                (j['tanggal']?.toString() ?? '').padRight(10).substring(0, 10)) ??
            DateTime.now(),
        jam = _jam(j['jam_selesai']).isEmpty
            ? _jam(j['jam_mulai'])
            : '${_jam(j['jam_mulai'])} - ${_jam(j['jam_selesai'])}',
        lokasi = j['lokasi']?.toString() ?? '',
        terdaftar = _i(j['jumlah_terdaftar']),
        checkin = _i(j['jumlah_checkin']),
        batal = _i(j['jumlah_batal']),
        tidakHadir = _i(j['jumlah_tidak_hadir']);

  /// Pendaftar yang tidak datang (sudah daftar tetapi tidak check-in).
  int get tidakDatang => terdaftar + tidakHadir;
  int get totalDaftar => terdaftar + checkin + tidakHadir;
}

/// Judul header (gaya teks sama dengan halaman lain).
Widget _judulTebal(String teks) {
  return Text(
    teks,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: Colors.white,
    ),
  );
}

/// Daftar tanggal jadwal yang sudah selesai. Ketuk tanggal untuk melihat detailnya.
class AdminRiwayatJadwalPage extends StatefulWidget {
  const AdminRiwayatJadwalPage({super.key});

  @override
  State<AdminRiwayatJadwalPage> createState() => _AdminRiwayatJadwalPageState();
}

class _AdminRiwayatJadwalPageState extends State<AdminRiwayatJadwalPage> {
  List<RiwayatJadwal> _data = [];
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final r = await ApiClient.dio.get('/sekretaris/jadwal/riwayat',
          options: Options(receiveTimeout: const Duration(seconds: 15)));
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      final list = <RiwayatJadwal>[];
      if (d is List) {
        for (final e in d) {
          if (e is Map) list.add(RiwayatJadwal(Map<String, dynamic>.from(e)));
        }
      }
      list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      if (!mounted) return;
      setState(() {
        _data = list;
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesan(e);
        _memuat = false;
      });
    }
  }

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
  // -------------------------------------------------------------------------
  Widget _header() {
    return Container(
      width: double.infinity,
      color: _hijauHeader,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal('Riwayat Jadwal'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_memuat)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_gagal != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.kuningMuda,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE6ECE8)),
                        ),
                        child: Row(children: [
                          Expanded(
                              child: Text(_gagal!, style: const TextStyle(fontSize: 16.5))),
                          TextButton(
                            onPressed: () {
                              setState(() => _memuat = true);
                              _muat();
                            },
                            child: const Text('Coba lagi'),
                          ),
                        ]),
                      )
                    else if (_data.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                        decoration: dekorKartuJadwal(),
                        child: const Text('Belum ada jadwal yang sudah selesai.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                      )
                    else
                      for (final j in _data) _kartu(j),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartu(RiwayatJadwal j) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: dekorKartuJadwal(),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RiwayatJadwalDetailPage(jadwal: j)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kepalaKartuJadwal(tglPanjangJadwal(j.tanggal), kanan: '${j.jam} WIB'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: bagianKartuJadwal(Icons.location_on_outlined, 'Lokasi',
                            j.lokasi.isEmpty ? '-' : j.lokasi),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 10, bottom: 8),
                        child: tautanDetailJadwal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}