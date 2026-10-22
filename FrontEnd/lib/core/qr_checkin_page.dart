import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_client.dart';
import 'app_colors.dart';
import 'posyandu.dart';

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
      final path = widget.role == 'sekretaris' ? '/sekretaris/qr' : '/kader/qr';
      final r = await ApiClient.dio.get(path,
          options: Options(receiveTimeout: const Duration(seconds: 15)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('QR Check-in Posyandu',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _gagal != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_gagal!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _muat, child: const Text('Coba lagi')),
                  ],
                )
              : _kode == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_posyandu != null && _posyandu!.isNotEmpty) ...[
                          Text('Posyandu ${labelPosyandu(_posyandu)}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 14),
                        ],
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: QrImageView(
                              data: _kode!, size: 260, backgroundColor: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'QR ini tetap untuk setiap pendaftaran.\nOrang tua memindai dari aplikasi untuk check-in.\nCheck-in hanya dibuka 1 jam sebelum jadwal dimulai.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.teksRedup, height: 1.4),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}