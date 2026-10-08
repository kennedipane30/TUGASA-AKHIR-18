import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import 'vaksin_model.dart';

class VaksinService {
  String _pesanError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Tidak dapat terhubung ke server';
  }

  List<Map<String, dynamic>> _list(dynamic data) {
    final raw = (data is Map ? data['data'] : null) as List? ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<VaksinMaster>> listMaster() async {
    try {
      final res = await ApiClient.dio.get('/vaksin/master');
      return _list(res.data).map(VaksinMaster.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<List<VaksinRencana>> listRencana(String anakId) async {
    try {
      final res = await ApiClient.dio.get('/vaksin/anak/$anakId/rencana');
      return _list(res.data).map(VaksinRencana.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<List<VaksinRiwayat>> listRiwayat(String anakId) async {
    try {
      final res = await ApiClient.dio.get('/vaksin/anak/$anakId/riwayat');
      return _list(res.data).map(VaksinRiwayat.fromJson).toList();
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
}