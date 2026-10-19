import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/posyandu.dart';

class StaffAkun {
  final int id;
  final String nama;
  final String username;
  final String role; // kader | bidan
  final String posyandu;
  final bool aktif;

  const StaffAkun({
    required this.id,
    required this.nama,
    required this.username,
    required this.role,
    required this.posyandu,
    required this.aktif,
  });

  String get labelPeran => role == 'bidan' ? 'Bidan' : 'Kader';
  String get labelPosyandu => posyanduLabel(posyandu);

  factory StaffAkun.fromJson(Map<String, dynamic> j) => StaffAkun(
        id: (j['id'] as num).toInt(),
        nama: (j['nama'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        posyandu: (j['posyandu'] ?? '').toString(),
        aktif: j['is_active'] == true,
      );
}

String posyanduLabel(String kode) => labelPosyandu(kode);

/// Layanan akun untuk sekretaris. Server hanya mengembalikan dan mengubah
/// akun milik desa sekretaris yang sedang login.
class AdminService {
  String _pesan(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return 'Tidak dapat terhubung ke server';
  }

  Future<List<StaffAkun>> daftarStaff() async {
    try {
      final res = await ApiClient.dio.get('/sekretaris/users');
      final list = (res.data['users'] as List?) ?? [];
      return list
          .map((e) => StaffAkun.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_pesan(e));
    }
  }

  Future<void> tambah({
    required String nama,
    required String username,
    required String password,
    required String role,
  }) async {
    try {
      await ApiClient.dio.post('/sekretaris/users', data: {
        'nama': nama,
        'username': username,
        'password': password,
        'role': role,
      });
    } on DioException catch (e) {
      throw Exception(_pesan(e));
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
      await ApiClient.dio.put('/sekretaris/users/$id', data: {
        'nama': nama,
        'username': username,
        'role': role,
        if (password != null && password.isNotEmpty) 'password': password,
      });
    } on DioException catch (e) {
      throw Exception(_pesan(e));
    }
  }

  Future<void> setAktif(int id, bool aktif) async {
    try {
      await ApiClient.dio.patch('/sekretaris/users/$id/aktif', data: {'is_active': aktif});
    } on DioException catch (e) {
      throw Exception(_pesan(e));
    }
  }

  Future<void> hapus(int id) async {
    try {
      await ApiClient.dio.delete('/sekretaris/users/$id');
    } on DioException catch (e) {
      throw Exception(_pesan(e));
    }
  }
}