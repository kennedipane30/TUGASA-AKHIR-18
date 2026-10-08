import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../OrangTua/pendaftaran/orangtua_pendaftaran_page.dart';

class _AnakHadir {
  final String pendaftaranId;
  final String anakId;
  final String nama;
  final String jk;
  final int usiaBulan;
  final int? nomor;
  final bool sudahDiukur;

  _AnakHadir({
    required this.pendaftaranId,
    required this.anakId,
    required this.nama,
    required this.jk,
    required this.usiaBulan,
    required this.nomor,
    required this.sudahDiukur,
  });

  factory _AnakHadir.fromApi(Map<String, dynamic> j) => _AnakHadir(
        pendaftaranId: j['pendaftaran_id']?.toString() ?? '',
        anakId: j['anak_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        jk: j['jenis_kelamin']?.toString() ?? '',
        usiaBulan: int.tryParse(j['usia_bulan']?.toString() ?? '') ?? 0,
        nomor: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
        sudahDiukur: j['sudah_diukur'] == true,
      );
}

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

List<dynamic> _ambilList(dynamic d) {
  if (d is List) return d;
  if (d is Map) {
    for (final k in ['data', 'antrean', 'items']) {
      if (d[k] is List) return d[k] as List;
    }
  }
  return [];
}

String _usia(int bln) => bln >= 12 ? '${bln ~/ 12} th ${bln % 12} bln' : '$bln bln';

final Options _opsi = Options(receiveTimeout: const Duration(seconds: 15));

// ---------------------------------------------------------------------------
// HALAMAN SCAN & KEHADIRAN (KADER)
// ---------------------------------------------------------------------------
class KaderScanPage extends StatefulWidget {
  const KaderScanPage({super.key});

  @override
  State<KaderScanPage> createState() => _KaderScanPageState();
}

class _KaderScanPageState extends State<KaderScanPage> {
  JadwalTerdekatData? _jadwal;
  List<_AnakHadir> _hadir = [];
  bool _memuat = true;
  bool _proses = false;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      var hadir = <_AnakHadir>[];
      if (j != null) {
        final r = await ApiClient.dio.get('/kader/jadwal/${j.id}/antrean', options: _opsi);
        // Hanya anak yang sudah di-scan / check-in yang ditampilkan
        hadir = _ambilList(r.data)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((m) => m['status_kehadiran'] == 'sudah_checkin')
            .map(_AnakHadir.fromApi)
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _jadwal = j;
        _hadir = hadir;
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesanError(e);
        _memuat = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _kirimKode(String kode) async {
    final j = _jadwal;
    if (j == null || _proses) return;
    setState(() => _proses = true);
    try {
      await ApiClient.dio
          .post('/kader/jadwal/${j.id}/scan', data: {'kode_qr': kode.trim()}, options: _opsi);
      _snack('Kehadiran tercatat');
      await _muat();
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _scan() async {
    final kode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _LayarScan()),
    );
    if (kode != null && kode.isNotEmpty) _kirimKode(kode);
  }

  Future<void> _manual() async {
    final kode = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogKode(),
    );
    if (kode != null && kode.isNotEmpty) _kirimKode(kode);
  }

  @override
  Widget build(BuildContext context) {
    final j = _jadwal;
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Scan Kehadiran Anak',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_memuat)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_gagal != null)
              SectionCard(
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
              )
            else if (j == null)
              SectionCard(
                title: 'Jadwal Posyandu',
                icon: Icons.event_busy,
                child: const Text(
                  'Belum ada jadwal posyandu aktif. Scan dapat dilakukan setelah admin membuat jadwal.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                ),
              )
            else ...[
              SectionCard(
                title: 'Sesi Posyandu',
                icon: Icons.event_note,
                trailing: Pill('${_hadir.length} hadir',
                    bg: AppColors.hijauMuda, fg: AppColors.hijau),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatTanggal(j.tanggal)} · ${j.jam} WIB',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    if (j.lokasi.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(j.lokasi,
                          style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(_proses ? 'Memproses...' : 'Scan Kode QR Anak',
                          icon: Icons.qr_code_scanner,
                          onPressed: _proses ? () {} : _scan),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton('Masukkan Kode Manual',
                          icon: Icons.keyboard_outlined,
                          filled: false,
                          onPressed: _proses ? () {} : _manual),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Anak Sudah Check-in',
                icon: Icons.how_to_reg,
                child: _hadir.isEmpty
                    ? const Text(
                        'Belum ada anak. Data anak muncul di sini setelah kode QR kartu digitalnya di-scan.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                      )
                    : Column(children: [for (final a in _hadir) _baris(a)]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _baris(_AnakHadir a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.hijauMuda,
            child: Icon(a.jk == 'P' ? Icons.female : Icons.male, color: AppColors.hijau),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nama,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text(
                  '${a.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${_usia(a.usiaBulan)}'
                  '${a.nomor != null ? ' · Antrean #${a.nomor}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.teksRedup),
                ),
              ],
            ),
          ),
          a.sudahDiukur
              ? const Pill('Sudah diukur', icon: Icons.check)
              : const Pill('Belum diukur', bg: AppColors.kuningMuda, fg: AppColors.kuning),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LAYAR KAMERA
// ---------------------------------------------------------------------------
class _LayarScan extends StatefulWidget {
  const _LayarScan();

  @override
  State<_LayarScan> createState() => _LayarScanState();
}

class _LayarScanState extends State<_LayarScan> {
  final MobileScannerController _c = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _selesai = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _deteksi(BarcodeCapture cap) {
    if (_selesai) return;
    for (final b in cap.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _selesai = true;
        Navigator.pop(context, v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Arahkan ke Kode QR Anak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _c.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _c.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _c,
            onDetect: _deteksi,
            errorBuilder: (ctx, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kamera tidak dapat dibuka. Izinkan akses kamera atau gunakan kode manual.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DIALOG KODE MANUAL
// ---------------------------------------------------------------------------
class _DialogKode extends StatefulWidget {
  const _DialogKode();

  @override
  State<_DialogKode> createState() => _DialogKodeState();
}

class _DialogKodeState extends State<_DialogKode> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kode kartu anak'),
      content: TextField(
        controller: _c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'PSY-...'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _c.text.trim()),
          child: const Text('Kirim'),
        ),
      ],
    );
  }
}