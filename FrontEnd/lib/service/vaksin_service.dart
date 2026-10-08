import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../features/Admin/admin_vaksin_model.dart';
import '../features/Bidan/vaksin_model.dart';

/// Ringkasan data anak untuk daftar pilihan (orang tua dan kader).
class AnakRingkas {
  final String id;
  final String nama;
  final String tanggalLahir;

  const AnakRingkas({required this.id, required this.nama, required this.tanggalLahir});

  factory AnakRingkas.fromJson(Map<String, dynamic> j) => AnakRingkas(
        id: '${j['id']}',
        nama: '${j['nama'] ?? '-'}',
        tanggalLahir: '${j['tanggal_lahir'] ?? ''}',
      );

  String get usia {
    final lahir = DateTime.tryParse(tanggalLahir);
    if (lahir == null) return '-';
    final n = DateTime.now();
    int bulan = (n.year - lahir.year) * 12 + (n.month - lahir.month);
    if (n.day < lahir.day) bulan--;
    if (bulan < 0) bulan = 0;
    if (bulan < 24) return '$bulan bln';
    final th = bulan ~/ 12;
    final sisa = bulan % 12;
    return sisa == 0 ? '$th th' : '$th th $sisa bln';
  }
}

class VaksinService {
  // ---------------------------------------------------------------- helper

  String _pesanError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Tidak dapat terhubung ke server';
  }

  List<Map<String, dynamic>> _list(dynamic data) {
    final raw = (data is Map ? data['data'] : null) as List? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<AnakRingkas> _parseAnak(dynamic list) {
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => AnakRingkas.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------------------------------------------------------------- anak

  /// Orang tua: daftar anak pada keluarganya sendiri.
  Future<List<AnakRingkas>> anakSaya() async {
    try {
      final res = await ApiClient.dio.get('/keluarga/saya');
      final root = res.data;
      final data = (root is Map && root['data'] is Map) ? root['data'] : root;
      return _parseAnak(data is Map ? data['anak'] : null);
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Kader: cari anak berdasarkan nama atau NIK.
  Future<List<AnakRingkas>> cariAnak(String kata) async {
    try {
      final res = await ApiClient.dio.get('/kader/anak', queryParameters: {'q': kata});
      final root = res.data;
      return _parseAnak(root is Map ? root['data'] : root);
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // ---------------------------------------------------------------- master

  Future<List<VaksinMaster>> listMaster() async {
    try {
      final res = await ApiClient.dio.get('/vaksin/master');
      return _list(res.data).map(VaksinMaster.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // ---------------------------------------------------------------- rencana

  Future<List<VaksinRencana>> listRencana(String anakId) async {
    try {
      final res = await ApiClient.dio.get('/vaksin/anak/$anakId/rencana');
      return _list(res.data).map(VaksinRencana.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> buatRencana({
    required String anakId,
    required String jadwalImunisasiId,
    required DateTime tanggal,
    required String alasan,
  }) async {
    try {
      await ApiClient.dio.post('/vaksin/rencana', data: {
        'anak_id': anakId,
        'jadwal_imunisasi_id': jadwalImunisasiId,
        'perkiraan_tanggal': formatTanggalApi(tanggal),
        'alasan': alasan,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> ubahRencana({
    required String id,
    required DateTime tanggal,
    required String alasan,
  }) async {
    try {
      await ApiClient.dio.put('/vaksin/rencana/$id', data: {
        'perkiraan_tanggal': formatTanggalApi(tanggal),
        'alasan': alasan,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> batalkanRencana(String id, String alasan) async {
    try {
      await ApiClient.dio.patch('/vaksin/rencana/$id/batal', data: {'alasan': alasan});
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // ---------------------------------------------------------------- riwayat

  Future<List<VaksinRiwayat>> listRiwayat(String anakId) async {
    try {
      final res = await ApiClient.dio.get('/vaksin/anak/$anakId/riwayat');
      return _list(res.data).map(VaksinRiwayat.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> catatRiwayat({
    required String anakId,
    required String jenisVaksinId,
    required int dosisKe,
    required DateTime tanggal,
    String kondisiAnak = '',
    String catatan = '',
  }) async {
    try {
      await ApiClient.dio.post('/vaksin/riwayat', data: {
        'anak_id': anakId,
        'jenis_vaksin_id': jenisVaksinId,
        'dosis_ke': dosisKe,
        'tanggal_pemberian': formatTanggalApi(tanggal),
        'kondisi_anak': kondisiAnak,
        'catatan': catatan,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // ---------------------------------------------------------------- admin

  /// Admin: jumlah vaksin yang diberikan dan rincian per jenis vaksin.
  Future<VaksinStatistik> statistikAdmin() async {
    try {
      final res = await ApiClient.dio.get('/admin/vaksin/statistik');
      final root = res.data;
      final data = (root is Map && root['data'] is Map) ? root['data'] : root;
      return VaksinStatistik.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }
}