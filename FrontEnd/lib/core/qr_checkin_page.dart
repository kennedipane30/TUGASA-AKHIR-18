import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_client.dart';
import 'app_colors.dart';
import 'posyandu.dart';

const Color _hijauHeader = Color(0xFF0B6043);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text(
          'QR Check-in Posyandu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: _hijauHeader,
        surfaceTintColor: _hijauHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _hijauHeader,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        child: _gagal != null
            ? Center(
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
              )
            : _kode == null
                ? const Center(
                    child: CircularProgressIndicator(color: _hijau),
                  )
                : _konten(),
      ),
    );
  }
}