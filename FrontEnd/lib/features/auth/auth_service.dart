// lib/features/auth/auth_service.dart
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/token_storage.dart';

class AuthService {
  String _pesanError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Tidak dapat terhubung ke server';
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final res = await ApiClient.dio.post('/auth/login',
          data: {'identifier': identifier, 'password': password});
      await TokenStorage.save(res.data['token']);
      return Map<String, dynamic>.from(res.data['user']);
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> register(
      String nama, String nik, String noHp, String password) async {
    try {
      await ApiClient.dio.post('/auth/register', data: {
        'nama': nama,
        'nik': nik,
        'no_hp': noHp,
        'password': password,
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

  // Khusus admin: membuat akun kader atau bidan
  Future<void> createStaff({
    required String nama,
    required String username,
    required String password,
    required String role, // 'kader' atau 'bidan'
  }) async {
    try {
      await ApiClient.dio.post('/admin/users', data: {
        'nama': nama,
        'username': username,
        'password': password,
        'role': role,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> ubahSandi(String lama, String baru) async {
    try {
      await ApiClient.dio.post('/auth/ubah-sandi',
          data: {'sandi_lama': lama, 'sandi_baru': baru});
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> logout() => TokenStorage.clear();
}