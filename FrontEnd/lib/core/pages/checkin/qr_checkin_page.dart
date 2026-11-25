import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/api_client.dart';
import '../../theme/app_colors.dart';
import '../../utils/posyandu.dart';
import '../../theme/app_colors.dart';

const Color _hijauHeader = Color(0xFF065F46);
const Color _hijau = Color(0xFF176A46);
const Color _teksGelap = Color(0xFF1F2937);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

/// Warna aksen kartu: hijau lembut senada header.
const Color _aksen = Color(0xFF5E9C84);

BoxDecoration _dekorKartu() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Kepala kartu: judul tebal kapital di kiri, keterangan di kanan, garis aksen di bawah.
Widget _kepala(String judul, {String? kanan}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                judul.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _teksGelap,
                ),
              ),
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(kanan,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
              ),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
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
  // HEADER (sama seperti halaman Imunisasi Anak: polos, judul di tengah)
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

  Widget _petunjuk(String teks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 5, color: _aksen),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                color: Color(0xFF52616B),
                fontSize: 15.5,
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
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: _dekorKartu(),
            child: Column(
              children: [
                _kepala('QR Check-in', kanan: namaPosyandu),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFCFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFB8BEC6), width: 1.2),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F8F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'QR ini tetap untuk setiap pendaftaran.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF52616B),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        namaPosyandu == null
                            ? 'Scan kode QR ini untuk proses check-in kehadiran secara cepat dan akurat.'
                            : 'Scan kode QR ini untuk proses check-in kehadiran di $namaPosyandu secara cepat dan akurat.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF25313A),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: _dekorKartu(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kepala('Petunjuk Pemindaian'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _petunjuk('Orang tua memindai dari aplikasi untuk check-in.'),
                      _petunjuk('Check-in hanya dibuka 1 jam sebelum jadwal dimulai.'),
                    ],
                  ),
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
            decoration: _dekorKartu(),
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
                    fontSize: 16,
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
                  child: const Text(
                    'Coba lagi',
                    style: TextStyle(fontSize: 16.5),
                  ),
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