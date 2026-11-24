// lib/features/auth/otp_service.dart
import 'package:dio/dio.dart';
import '../../core/config/api_client.dart';

/// Tujuan kode OTP (sama dengan backend: models.TujuanOTP...).
class TujuanOtp {
  static const registrasi = 'registrasi';
  static const resetPin = 'reset_pin';
}

/// Jawaban server setelah kode dikirim ke WhatsApp.
class InfoKirimOtp {
  final String noHpSamaran; // contoh: +62 812****7890
  final int berlakuDetik; // kode berlaku (detik)
  final int kirimUlangDetik; // jeda sebelum boleh kirim ulang (detik)
  final bool modeUji; // true bila server belum memakai gateway WA (kode ada di log server)

  InfoKirimOtp({
    required this.noHpSamaran,
    required this.berlakuDetik,
    required this.kirimUlangDetik,
    required this.modeUji,
  });

  factory InfoKirimOtp.fromJson(Map<String, dynamic> j) => InfoKirimOtp(
        noHpSamaran: (j['no_hp'] ?? '').toString(),
        berlakuDetik: (j['berlaku_detik'] as num?)?.toInt() ?? 300,
        kirimUlangDetik: (j['kirim_ulang_detik'] as num?)?.toInt() ?? 60,
        modeUji: j['mode_uji'] == true,
      );
}

/// Kode OTP WhatsApp untuk registrasi orang tua dan lupa PIN.
class OtpService {
  String _pesanError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Tidak dapat terhubung ke server';
  }

  /// Kirim kode 6 digit ke WhatsApp. [tujuan]: TujuanOtp.registrasi / TujuanOtp.resetPin.
  /// [noHp]: No. WhatsApp format +62 (registrasi: nomor baru; lupa PIN: nomor login).
  Future<InfoKirimOtp> kirim(String noHp, String tujuan) async {
    try {
      final res = await ApiClient.dio.post('/auth/otp/kirim',
          data: {'no_hp': noHp, 'tujuan': tujuan});
      return InfoKirimOtp.fromJson(Map<String, dynamic>.from(res.data['data']));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Cocokkan kode. Mengembalikan token_otp (sekali pakai, berlaku 15 menit).
  Future<String> verifikasi(String noHp, String tujuan, String kode) async {
    try {
      final res = await ApiClient.dio.post('/auth/otp/verifikasi',
          data: {'no_hp': noHp, 'tujuan': tujuan, 'kode': kode});
      return (res.data['data']?['token_otp'] ?? '').toString();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Registrasi orang tua setelah No. WhatsApp terverifikasi.
  Future<void> registerOtp({
    required String nama,
    required String nik,
    required String noHp,
    required String pin,
    required String posyandu,
    required String tokenOtp,
  }) async {
    try {
      await ApiClient.dio.post('/auth/register-otp', data: {
        'nama': nama,
        'nik': nik,
        'no_hp': noHp,
        'pin': pin,
        'posyandu': posyandu,
        'token_otp': tokenOtp,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Lupa PIN: atur PIN baru setelah No. WhatsApp terverifikasi.
  /// [noHp]: No. HP login (format +62).
  Future<void> lupaPin({
    required String noHp,
    required String pinBaru,
    required String tokenOtp,
  }) async {
    try {
      await ApiClient.dio.post('/auth/lupa-pin', data: {
        'no_hp': noHp,
        'pin_baru': pinBaru,
        'token_otp': tokenOtp,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }
}