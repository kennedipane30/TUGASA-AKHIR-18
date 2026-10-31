import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_client.dart';
import 'app_colors.dart';
import 'posyandu.dart';

const Color _hijauHeader = Color(0xFF065F46);
const Color _hijau = Color(0xFF176A46);
const Color _biru = Color(0xFF2582C4);

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

/// Judul header ekstra tebal (sama seperti halaman Akun).
/// Lapis bawah: garis tepi putih agar huruf lebih gemuk; lapis atas: isi putih.
Widget _judulTebal(String teks) {
  const ukuran = 20.0;
  const jarak = 1.2; // jarak antar huruf

  return Stack(
    children: [
      // Lapis bawah: garis tepi untuk menebalkan huruf
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        ),
      ),
      // Lapis atas: isi huruf
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Color(0x40000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Halaman QR check-in tetap (satu per posyandu).
/// [role] = 'sekretaris' atau 'kader'.
class QrCheckinPage extends StatefulWidget {
  final String role;

  const QrCheckinPage({super.key, required this.role});

  @override
  State<QrCheckinPage> createState() => _QrCheckinPageState();
}

class _QrCheckinPageState extends State<QrCheckinPage> {
  String? _kode;
  String? _posyandu;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _gagal = null;
      _kode = null;
    });

    try {
      final path =
          widget.role == 'sekretaris' ? '/sekretaris/qr' : '/kader/qr';

      final r = await ApiClient.dio.get(
        path,
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];

      if (!mounted) return;

      setState(() {
        _kode = (d as Map)['kode_qr']?.toString();
        _posyandu = d['posyandu']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _gagal = _pesanError(e));
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
              // Judul di tengah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal('QR Check-in'),
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

  Widget _badge({
    required IconData icon,
    required String label,
    required Color warna,
    required Color latar,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: warna.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: warna),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: warna,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _petunjuk(String teks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 5, color: _biru),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                color: Color(0xFF52616B),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _konten() {
    final namaPosyandu = _posyandu != null && _posyandu!.isNotEmpty
        ? labelPosyandu(_posyandu)
        : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            namaPosyandu == null
                ? 'Scan kode QR ini untuk proses check-in kehadiran secara cepat dan akurat.'
                : 'Scan kode QR ini untuk proses check-in kehadiran di $namaPosyandu secara cepat dan akurat.',
            style: const TextStyle(
              color: Color(0xFF25313A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5ECE9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (namaPosyandu != null)
                      _badge(
                        icon: Icons.location_on,
                        label: namaPosyandu,
                        warna: _biru,
                        latar: const Color(0xFFF0F8FF),
                      ),
                    _badge(
                      icon: Icons.qr_code_2,
                      label: 'QR Check-in',
                      warna: _hijau,
                      latar: const Color(0xFFEAF8F1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFCFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDF1EF)),
                  ),
                  child: QrImageView(
                    data: _kode!,
                    size: 230,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: _hijau),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'QR ini tetap untuk setiap pendaftaran.',
                          style: TextStyle(
                            color: Color(0xFF52616B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F9FE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7EDFB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 17, color: _biru),
                    SizedBox(width: 8),
                    Text(
                      'Petunjuk Pemindaian',
                      style: TextStyle(
                        color: Color(0xFF25313A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _petunjuk(
                  'Orang tua memindai dari aplikasi untuk check-in.',
                ),
                _petunjuk(
                  'Check-in hanya dibuka 1 jam sebelum jadwal dimulai.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_gagal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5ECE9)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF4E5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    color: Color(0xFFE89B24),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _gagal!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF25313A),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _muat,
                  style: FilledButton.styleFrom(
                    backgroundColor: _hijau,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_kode == null) {
      return const Center(
        child: CircularProgressIndicator(color: _hijau),
      );
    }

    return _konten();
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
              child: SafeArea(
                top: false,
                child: _isi(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}