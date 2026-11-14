import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/status_gizi_widget.dart';

part 'riwayat_detail_page.dart';

const _prefix = '/sekretaris/riwayat';

const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi semua kartu (daftar & detail): hitam lembut (tidak mencolok).
const _garisDetail = Color(0xFFB8BEC6);
const _garisKartu = _garisDetail;

// ---------------------------------------------------------------------------
// FUNGSI BANTU
// ---------------------------------------------------------------------------
String _teks(dynamic v) => v?.toString().trim() ?? '';

/// Label kondisi anak sebelum imunisasi.
String _kondisiTeks(dynamic v) {
  switch (_teks(v)) {
    case 'sehat':
      return 'Sehat';
    case 'demam_ringan':
      return 'Demam ringan';
    case 'sakit':
      return 'Sakit';
  }
  return _teks(v);
}

String _num(dynamic v) {
  final d = double.tryParse(v?.toString() ?? '');
  if (d == null) return '-';
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
}

DateTime? _tgl(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];

String _fmtTgl(DateTime? t) =>
    t == null ? '-' : '${t.day} ${_bulan[t.month - 1]} ${t.year}';

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

/// Contoh: "Sabtu, 14 November 2026".
String _fmtHariTgl(DateTime? t) => t == null ? '-' : '${_hari[t.weekday - 1]}, ${_fmtTgl(t)}';

/// Contoh: "08:00 - 11:30 WIB".
String _fmtWaktu(Map<String, dynamic> j) {
  final m = _jam(j['jam_mulai']);
  final s = _jam(j['jam_selesai']);
  if (m.isEmpty) return '-';
  return s.isEmpty ? '$m WIB' : '$m - $s WIB';
}

/// Baris "Label : nilai" (huruf hitam, tebal sama).
Widget _barisInfo(String label, String nilai) {
  const gaya = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: _teksGelap);
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 108, child: Text(label, style: gaya)),
        const Text(': ', style: gaya),
        Expanded(child: Text(nilai.isEmpty ? '-' : nilai, style: gaya)),
      ],
    ),
  );
}

DateTime _tambahBulan(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final akhir = DateTime.utc(y, m + 1, 0).day;
  return DateTime.utc(y, m, d.day > akhir ? akhir : d.day);
}

/// Usia detail dari [lahir] sampai [pada] (default hari ini).
/// Contoh: "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan", "2 tahun".
String _usiaDetail(DateTime lahir, [DateTime? pada]) {
  final p = pada ?? DateTime.now();
  final a = DateTime.utc(lahir.year, lahir.month, lahir.day);
  final b = DateTime.utc(p.year, p.month, p.day);
  if (b.isBefore(a)) return '0 hari';

  var bulan = (b.year - a.year) * 12 + b.month - a.month;
  if (_tambahBulan(a, bulan).isAfter(b)) bulan--;
  final hari = b.difference(_tambahBulan(a, bulan)).inDays;
  final tahun = bulan ~/ 12;
  final sisaBulan = bulan % 12;

  if (bulan == 0) return '$hari hari';
  if (tahun == 0) return hari == 0 ? '$bulan bulan' : '$bulan bulan $hari hari';
  return sisaBulan == 0 ? '$tahun tahun' : '$tahun tahun $sisaBulan bulan';
}

/// Usia dari tanggal lahir bila ada; bila tidak, dari jumlah bulan.
String _usia(int bln, {dynamic lahir, DateTime? pada}) {
  final l = _tgl(lahir);
  if (l != null) return _usiaDetail(l, pada);
  final th = bln ~/ 12;
  final sisa = bln % 12;
  if (th == 0) return '$bln bulan';
  return sisa == 0 ? '$th tahun' : '$th tahun $sisa bulan';
}

String _jam(dynamic v) {
  final s = _teks(v);
  return s.length >= 5 ? s.substring(0, 5) : s;
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

Future<dynamic> _get(String path) async {
  final r = await ApiClient.dio.get(path,
      options: Options(receiveTimeout: const Duration(seconds: 15)));
  dynamic d = r.data;
  if (d is Map && d.containsKey('data')) d = d['data'];
  return d;
}

List<Map<String, dynamic>> _daftarPeta(dynamic d) {
  final list = <Map<String, dynamic>>[];
  if (d is List) {
    for (final e in d) {
      if (e is Map) list.add(Map<String, dynamic>.from(e));
    }
  }
  return list;
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

// ---------------------------------------------------------------------------
// HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
// Dipakai oleh ketiga halaman riwayat. Tombol kembali hanya muncul
// bila ada halaman sebelumnya.
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  final String judul;

  const _Header(this.judul);

  @override
  Widget build(BuildContext context) {
    final bisaKembali = Navigator.canPop(context);

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
              // Judul di tengah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal(judul),
              ),
              // Tombol kembali di kiri
              if (bisaKembali)
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
}

/// Kerangka halaman: header polos di atas, isi di bawahnya.
Widget _halaman({required String judul, required Widget isi}) {
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
          _Header(judul),
          Expanded(child: isi),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// KOMPONEN TAMPILAN (SERAGAM DENGAN HALAMAN BUAT AKUN)
// ---------------------------------------------------------------------------
Widget _kartu({
  required String title,
  Widget? trailing,
  required Widget child,
}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _garisDetail, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: _teksGelap)),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );

Widget _gagalKartu(String pesan, VoidCallback ulang) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.kuningMuda,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(pesan,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16.5)),
          ),
          TextButton(onPressed: ulang, child: const Text('Coba lagi')),
        ],
      ),
    );

Widget _memuatBox() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );

// ---------------------------------------------------------------------------
// HALAMAN 1: DAFTAR TANGGAL POSYANDU
// ---------------------------------------------------------------------------
class AdminRiwayatPage extends StatefulWidget {
  const AdminRiwayatPage({super.key});

  @override
  State<AdminRiwayatPage> createState() => _AdminRiwayatPageState();
}

class _AdminRiwayatPageState extends State<AdminRiwayatPage> {
  List<Map<String, dynamic>> _data = [];
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final d = await _get('$_prefix/jadwal');
      final list = _daftarPeta(d);
      list.sort((a, b) {
        final ta = _tgl(a['tanggal']) ?? DateTime(1970);
        final tb = _tgl(b['tanggal']) ?? DateTime(1970);
        return tb.compareTo(ta);
      });
      if (!mounted) return;
      setState(() {
        _data = list;
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

  @override
  Widget build(BuildContext context) {
    return _halaman(
      judul: 'Riwayat Pemeriksaan',
      isi: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_memuat)
              _memuatBox()
            else if (_gagal != null)
              _gagalKartu(_gagal!, () {
                setState(() => _memuat = true);
                _muat();
              })
            else if (_data.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _garisKartu, width: 1.2),
                ),
                child: const Text('Belum ada jadwal posyandu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
              )
            else
              for (final j in _data) _baris(j),
          ],
        ),
      ),
    );
  }

  Widget _baris(Map<String, dynamic> j) {
    final t = _tgl(j['tanggal']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _DaftarAnakPage(jadwal: j)),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _garisKartu, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtHariTgl(t),
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w600, color: _teksGelap)),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lihat detail',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: _hijauHeader)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16, color: _hijauHeader),
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