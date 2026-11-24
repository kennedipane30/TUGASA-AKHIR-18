// lib/features/auth/auth_service.dart
import 'package:dio/dio.dart';
import '../../core/config/api_client.dart';
import '../../core/token_storage.dart';

/// Autentikasi: semua role masuk dengan No. HP (format +62) + PIN 6 digit.
class AuthService {
  String _pesanError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Tidak dapat terhubung ke server';
  }

  /// [noHp]: format +62 (mis. +6281234567890).
  Future<Map<String, dynamic>> login(String noHp, String pin) async {
    try {
      final res = await ApiClient.dio.post('/auth/login',
          data: {'no_hp': noHp, 'pin': pin});
      await TokenStorage.save(res.data['token']);
      return Map<String, dynamic>.from(res.data['user']);
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> register(
    String nama,
    String nik,
    String noHp,
    String pin, {
    String posyandu = '',
  }) async {
    try {
      await ApiClient.dio.post('/auth/register', data: {
        'nama': nama,
        'nik': nik,
        'no_hp': noHp,
        'pin': pin,
        'posyandu': posyandu,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // Dipakai saat aplikasi dibuka untuk memulihkan sesi dari token tersimpan
  Future<Map<String, dynamic>?> me() async {
    try {
      final token = await TokenStorage.read();
      if (token == null) return null;
      final res = await ApiClient.dio.get('/auth/me');
      return Map<String, dynamic>.from(res.data['user']);
    } catch (_) {
      await TokenStorage.clear();
      return null;
    }
  }

  Future<void> ubahPin(String pinLama, String pinBaru) async {
    try {
      await ApiClient.dio.post('/auth/ubah-pin',
          data: {'pin_lama': pinLama, 'pin_baru': pinBaru});
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Sekretaris (akun kader/bidan/orang tua) atau kader (akun orang tua):
  /// membuat PIN sementara. Mengembalikan PIN sementara.
  Future<String> resetPin(String prefix, int userId) async {
    try {
      final res = await ApiClient.dio.post('$prefix/users/$userId/reset-pin');
      return (res.data['data']?['pin_sementara'] ?? '').toString();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> logout() => TokenStorage.clear();
}