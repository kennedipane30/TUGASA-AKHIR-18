import 'package:dio/dio.dart';

import '../../core/api_client.dart';

class StaffAkun {
  final int id;
  final String nama;
  final String username;
  final String role; // 'kader' atau 'bidan'
  final bool aktif;

  const StaffAkun({
    required this.id,
    required this.nama,
    required this.username,
    required this.role,
    required this.aktif,
  });

  factory StaffAkun.fromJson(Map<String, dynamic> j) => StaffAkun(
        id: (j['id'] as num).toInt(),
        nama: (j['nama'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        aktif: j['is_active'] == true,
      );

  String get labelPeran => role == 'bidan' ? 'Bidan' : 'Kader';
}

class AdminService {
  String _pesanError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Tidak dapat terhubung ke server';
  }

  Future<List<StaffAkun>> daftarStaff() async {
    try {
      final res = await ApiClient.dio.get('/admin/users');
      final list = (res.data['users'] as List?) ?? [];
      return list
          .map((e) => StaffAkun.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> tambah({
    required String nama,
    required String username,
    required String password,
    required String role,
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

  Future<void> ubah(
    int id, {
    required String nama,
    required String username,
    required String role,
    String? password,
  }) async {
    try {
      await ApiClient.dio.put('/admin/users/$id', data: {
        'nama': nama,
        'username': username,
        'role': role,
        if (password != null && password.isNotEmpty) 'password': password,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> setAktif(int id, bool aktif) async {
    try {
      await ApiClient.dio.patch('/admin/users/$id/active', data: {'is_active': aktif});
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> hapus(int id) async {
    try {
      await ApiClient.dio.delete('/admin/users/$id');
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }
}