import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// LOG AKTIVITAS (SEKRETARIS)
// Hanya menampilkan aktivitas di posyandu sekretaris yang login.
// ---------------------------------------------------------------------------

const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);
const _teksAbu = Color(0xFF64748B);

/// Garis tepi chip & kotak di dalam kartu: hitam lembut.
const _garis = Color(0xFFB8BEC6);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Pilihan saring: (nilai role di server, label).
const _saring = [
  ('', 'Semua'),
  ('sekretaris', 'Sekretaris'),
  ('bidan', 'Bidan'),
  ('kader', 'Kader'),
  ('orang_tua', 'Orang Tua'),
];

String _labelRole(String r) => switch (r) {
      'sekretaris' => 'Sekretaris',
      'bidan' => 'Bidan',
      'kader' => 'Kader',
      'orang_tua' => 'Orang Tua',
      _ => r,
    };

String _pesanError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server tidak merespons. Periksa koneksi dan alamat server.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server.';
      default:
        return 'Terjadi kesalahan (kode ${e.response?.statusCode ?? '-'}).';
    }
  }
  return 'Terjadi kesalahan: $e';
}

class _Aktivitas {
  final int id;
  final String nama;
  final String role;
  final String aksi;
  final String modul;
  final DateTime waktu;

  _Aktivitas(this.id, this.nama, this.role, this.aksi, this.modul, this.waktu);

  factory _Aktivitas.fromApi(Map<String, dynamic> j) => _Aktivitas(
        int.tryParse(j['id']?.toString() ?? '') ?? 0,
        (j['nama_user'] ?? '-').toString(),
        (j['role'] ?? '').toString(),
        (j['aksi'] ?? '-').toString(),
        (j['modul'] ?? '').toString(),
        (DateTime.tryParse(j['waktu']?.toString() ?? '') ?? DateTime.now()).toLocal(),
      );

  DateTime get hari => DateTime(waktu.year, waktu.month, waktu.day);

  String get jam =>
      '${waktu.hour.toString().padLeft(2, '0')}:${waktu.minute.toString().padLeft(2, '0')}';
}

class LogAktivitasPage extends StatefulWidget {
  const LogAktivitasPage({super.key});

  @override
  State<LogAktivitasPage> createState() => _LogAktivitasPageState();
}

class _LogAktivitasPageState extends State<LogAktivitasPage> {
  static const _perHalaman = 30;

  final List<_Aktivitas> _data = [];
  String _role = '';
  int _halaman = 1;
  int _total = 0;
  bool _memuat = true;
  bool _memuatLagi = false;
  String? _gagal;
  int _permintaan = 0;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat({bool lanjut = false}) async {
    final no = ++_permintaan;
    final halaman = lanjut ? _halaman + 1 : 1;
    setState(() {
      if (lanjut) {
        _memuatLagi = true;
      } else {
        _memuat = _data.isEmpty;
        _gagal = null;
      }
    });
    try {
      final r = await ApiClient.dio.get(
        '/sekretaris/log-aktivitas',
        queryParameters: {
          if (_role.isNotEmpty) 'role': _role,
          'halaman': halaman,
          'per_halaman': _perHalaman,
        },
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      final body = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
      final list = ((body['data'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => _Aktivitas.fromApi(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted || no != _permintaan) return;
      setState(() {
        if (!lanjut) _data.clear();
        _data.addAll(list);
        _halaman = halaman;
        _total = int.tryParse(body['total']?.toString() ?? '') ?? _data.length;
        _memuat = false;
        _memuatLagi = false;
      });
    } catch (e) {
      if (!mounted || no != _permintaan) return;
      setState(() {
        _memuat = false;
        _memuatLagi = false;
        if (lanjut) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(_pesanError(e))));
        } else {
          _gagal = _pesanError(e);
        }
      });
    }
  }

  void _pilihRole(String r) {
    if (_role == r) return;
    setState(() {
      _role = r;
      _data.clear();
    });
    _muat();
  }

  // -------------------------------------------------------------------------
  // HEADER (polos, judul di tengah)
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 56),
                child: Text(
                  'Log Aktivitas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
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

  // -------------------------------------------------------------------------
  // KOMPONEN
  // -------------------------------------------------------------------------
  Widget _chipSaring() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          for (final (nilai, label) in _saring)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _role == nilai,
                showCheckmark: false,
                selectedColor: _hijauHeader,
                backgroundColor: Colors.white,
                side: BorderSide(color: _role == nilai ? _hijauHeader : _garis, width: 1.2),
                labelStyle: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: _role == nilai ? Colors.white : _teksGelap,
                ),
                onSelected: (_) => _pilihRole(nilai),
              ),
            ),
        ],
      ),
    );
  }

  String _judulHari(DateTime d) {
    final n = DateTime.now();
    final hariIni = DateTime(n.year, n.month, n.day);
    if (d == hariIni) return 'Hari ini';
    if (d == hariIni.subtract(const Duration(days: 1))) return 'Kemarin';
    return _hari[d.weekday - 1];
  }

  /// Kartu satu hari: hari di atas, tanggal di bawah, jumlah aktivitas di kanan.
  Widget _kartuHari(DateTime hari, List<_Aktivitas> isi) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _judulHari(hari).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: _teksGelap,
                        ),
                      ),
                      Text(
                        '${hari.day} ${_bulan[hari.month - 1]} ${hari.year}',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${isi.length} aktivitas',
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap),
                ),
              ],
            ),
          ),
          Container(height: 3, color: _aksen),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Column(
              children: [
                for (var i = 0; i < isi.length; i++) ...[
                  _baris(isi[i]),
                  if (i < isi.length - 1) const Divider(height: 1, color: Color(0xFFE5E7EB)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Satu baris aktivitas: jam di kiri, aksi + pelaku di kanan.
  Widget _baris(_Aktivitas a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              a.jam,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w700, color: _hijauHeader),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.aksi,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.3, color: _teksGelap),
                ),
                const SizedBox(height: 2),
                Text(
                  '${a.nama} · ${_labelRole(a.role)}',
                  style: const TextStyle(fontSize: 14.5, height: 1.3, color: _teksAbu),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pesan(String teks) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Text(teks,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.4, color: _teksAbu)),
    );
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Kelompokkan per hari (data sudah terurut terbaru lebih dulu).
    final grup = <DateTime, List<_Aktivitas>>{};
    for (final a in _data) {
      grup.putIfAbsent(a.hari, () => []).add(a);
    }
    final masihAda = _data.length < _total;

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
            _chipSaring(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    if (_memuat)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_gagal != null) ...[
                      _pesan(_gagal!),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _muat,
                          child: const Text(
                            'Coba lagi',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: _aksen,
                              decoration: TextDecoration.underline,
                              decorationColor: _aksen,
                            ),
                          ),
                        ),
                      ),
                    ] else if (_data.isEmpty)
                      _pesan('Belum ada aktivitas yang tercatat.')
                    else ...[
                      for (final e in grup.entries) _kartuHari(e.key, e.value),
                      if (masihAda)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _memuatLagi ? null : () => _muat(lanjut: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _hijauHeader,
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: _hijauHeader, width: 1.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            child: Text(_memuatLagi ? 'Memuat...' : 'Muat lebih banyak'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}