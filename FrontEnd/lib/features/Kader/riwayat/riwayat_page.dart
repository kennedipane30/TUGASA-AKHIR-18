import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/status_gizi_widget.dart';

part 'riwayat_detail_page.dart';

const _prefix = '/kader/riwayat';
const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi kotak di dalam kartu: hitam lembut (tidak mencolok).
const _garis = Color(0xFFB8BEC6);

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
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String _fmtTgl(DateTime? t) =>
    t == null ? '-' : '${t.day} ${_bulan[t.month - 1]} ${t.year}';

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

/// Contoh: "Sabtu".
String _fmtHari(DateTime? t) => t == null ? '-' : _hari[t.weekday - 1];

/// Contoh: "08:00 - 11:30 WIB".
String _fmtWaktu(Map<String, dynamic> j) {
  final m = _jam(j['jam_mulai']);
  final s = _jam(j['jam_selesai']);
  if (m.isEmpty) return '';
  return s.isEmpty ? '$m WIB' : '$m - $s WIB';
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
  final r = await ApiClient.dio.get(
    path,
    options: Options(
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dynamic d = r.data;
  if (d is Map && d.containsKey('data')) d = d['data'];
  return d;
}

List<Map<String, dynamic>> _daftarPeta(dynamic d) {
  final list = <Map<String, dynamic>>[];

  if (d is List) {
    for (final e in d) {
      if (e is Map) {
        list.add(Map<String, dynamic>.from(e));
      }
    }
  }

  return list;
}

Widget _gagalKartu(String pesan, VoidCallback ulang) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.kuningMuda,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pesan,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16.5,
              ),
            ),
          ),
          TextButton(
            onPressed: ulang,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );

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
// HEADER (sama seperti halaman Imunisasi Anak: polos, judul di tengah)
// Dipakai oleh ketiga halaman riwayat.
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String judul;

  const _Header(this.judul);

  @override
  Widget build(BuildContext context) {
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
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
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

Widget _memuatBox() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );

// ---------------------------------------------------------------------------
// KOMPONEN KARTU (SERAGAM DENGAN HALAMAN LAIN)
// ---------------------------------------------------------------------------

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

BoxDecoration _dekorKartu() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Kepala kartu: judul tebal kapital (dan sub judul) di kiri, keterangan di kanan,
/// lalu garis aksen di bawahnya.
Widget _kepala(String judul, {String? sub, String? kanan}) {
  return Column(
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
                    judul.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: _teksGelap,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
                ],
              ),
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(kanan,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Kartu berjudul (kepala + isi).
Widget _kartu({required String title, String? sub, String? kanan, required Widget child}) =>
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: _dekorKartu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala(title, sub: sub, kanan: kanan),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );

/// Satu bagian isi kartu: ikon kecil + label tebal, nilai langsung di sampingnya.
Widget _bagian(IconData ikon, String label, String nilai) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(ikon, size: 18, color: _aksen),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label : ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _teksGelap),
                ),
                TextSpan(
                  text: nilai.isEmpty ? '-' : nilai,
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 15.5, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

/// Baris "Label : nilai" (satu warna hitam).
Widget _barisInfo(String label, String nilai, {double lebar = 130}) {
  const gaya = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.35, color: _teksGelap);
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: lebar, child: Text(label, style: gaya)),
        const Text(': ', style: gaya),
        Expanded(child: Text(nilai.isEmpty ? '-' : nilai, style: gaya)),
      ],
    ),
  );
}

/// Tautan "Lihat detail" (hijau lembut bergaris bawah).
const _tautanDetail = Text(
  'Lihat detail',
  style: TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: _aksen,
    decoration: TextDecoration.underline,
    decorationColor: _aksen,
  ),
);

/// Teks abu untuk keadaan kosong.
Widget _teksKosong(String teks) =>
    Text(teks, style: const TextStyle(fontSize: 16, color: AppColors.teksRedup));

// ---------------------------------------------------------------------------
// HALAMAN 1: DAFTAR TANGGAL POSYANDU
// ---------------------------------------------------------------------------

class KaderRiwayatPage extends StatefulWidget {
  const KaderRiwayatPage({super.key});

  @override
  State<KaderRiwayatPage> createState() => _KaderRiwayatPageState();
}

class _KaderRiwayatPageState extends State<KaderRiwayatPage> {
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
                decoration: _dekorKartu(),
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
    final checkin = int.tryParse(_teks(j['jumlah_checkin'])) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: _dekorKartu(),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _DaftarAnakPage(jadwal: j)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kepala(_fmtHari(t), sub: _fmtTgl(t), kanan: _fmtWaktu(j)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bagian(Icons.location_on_outlined, 'Lokasi', _teks(j['lokasi'])),
                            _bagian(Icons.how_to_reg_outlined, 'Anak check-in', '$checkin anak'),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 10, bottom: 8),
                        child: _tautanDetail,
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