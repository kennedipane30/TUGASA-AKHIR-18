// ===== admin_riwayat_jadwal_page.dart =====
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

const _hijauGelap = Color(0xFF14634A);
const _hijauHeader = Color(0xFF14634A);
const _teksGelap = Color(0xFF1F2937);

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

class _Riwayat {
  final String id;
  final DateTime tanggal;
  final String jam;
  final String lokasi;
  final int terdaftar, checkin, batal, tidakHadir;

  _Riwayat(Map<String, dynamic> j)
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

/// Riwayat jadwal yang sudah lewat: hanya lihat dan hapus (tidak dapat diubah).
class AdminRiwayatJadwalPage extends StatefulWidget {
  const AdminRiwayatJadwalPage({super.key});

  @override
  State<AdminRiwayatJadwalPage> createState() => _AdminRiwayatJadwalPageState();
}

class _AdminRiwayatJadwalPageState extends State<AdminRiwayatJadwalPage> {
  List<_Riwayat> _data = [];
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
      final list = <_Riwayat>[];
      if (d is List) {
        for (final e in d) {
          if (e is Map) list.add(_Riwayat(Map<String, dynamic>.from(e)));
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

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _hapus(_Riwayat j) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus riwayat jadwal?'),
        content: Text('Jadwal ${formatTanggal(j.tanggal)} akan dihapus dari riwayat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.merah, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await ApiClient.dio.delete('/sekretaris/jadwal/${j.id}');
      _snack('Riwayat jadwal dihapus');
      _muat();
    } catch (e) {
      _snack(_pesan(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: _hijauHeader,
        surfaceTintColor: _hijauHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _hijauHeader,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Riwayat Jadwal',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      body: RefreshIndicator(
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
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE6ECE8)),
                ),
                child: Row(children: [
                  const Icon(Icons.cloud_off, color: AppColors.kuning),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_gagal!)),
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
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE6ECE8)),
                ),
                child: const Text('Belum ada jadwal yang sudah lewat.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup)),
              )
            else
              for (final j in _data) _kartu(j),
          ],
        ),
      ),
    );
  }

  Widget _kartu(_Riwayat j) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.hijauMuda,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFE5D0)),
                ),
                child: const Icon(Icons.history, color: _hijauGelap, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatTanggal(j.tanggal),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5, color: _teksGelap)),
                    const SizedBox(height: 2),
                    Text('${j.jam} WIB${j.lokasi.isEmpty ? '' : ' • ${j.lokasi}'}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              const Pill('Selesai', bg: Color(0xFFE3E8E5), fg: Colors.black87),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: StatBox(
                      nilai: '${j.checkin}',
                      label: 'Check-in',
                      bg: AppColors.hijauMuda,
                      fg: AppColors.hijau)),
              const SizedBox(width: 6),
              Expanded(child: StatBox(nilai: '${j.totalDaftar}', label: 'Terdaftar')),
              const SizedBox(width: 6),
              Expanded(
                  child: StatBox(
                      nilai: '${j.tidakDatang}',
                      label: 'Tidak hadir',
                      bg: AppColors.kuningMuda,
                      fg: AppColors.kuning)),
              const SizedBox(width: 6),
              Expanded(
                  child: StatBox(
                      nilai: '${j.batal}',
                      label: 'Batal',
                      bg: AppColors.merahMuda,
                      fg: AppColors.merah)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEDF1EF)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _hapus(j),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFF1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF7C4CB)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, size: 14, color: AppColors.merah),
                    SizedBox(width: 5),
                    Text('Hapus',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.merah)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}