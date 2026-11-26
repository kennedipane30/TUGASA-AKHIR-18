import 'package:dio/dio.dart';

import '../core/config/api_client.dart';

// ============================================================================
// MODEL & SERVICE RUJUKAN BALITA (bidan & orang tua)
// ============================================================================

String _s(dynamic v) => v == null ? '' : v.toString();
bool _b(dynamic v) => v == true || _s(v) == 'true';
double? _dN(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(_s(v)));
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

DateTime? _tgl(dynamic v) {
  final t = _s(v);
  if (t.length < 10) return null;
  return DateTime.tryParse(t.substring(0, 10));
}

DateTime? _waktu(dynamic v) {
  final t = _s(v);
  if (t.isEmpty) return null;
  return DateTime.tryParse(t.replaceFirst(' ', 'T'));
}

const _namaBulan = [
  '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// "12 November 2026".
String tglRujukan(DateTime? d) => d == null ? '-' : '${d.day} ${_namaBulan[d.month]} ${d.year}';

String angkaRujukan(double? v, String satuan) {
  if (v == null) return '-';
  final t = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '${t.replaceAll('.', ',')} $satuan';
}

String jkRujukan(String jk) {
  final v = jk.toUpperCase();
  if (v.startsWith('L')) return 'Laki-laki';
  if (v.startsWith('P')) return 'Perempuan';
  return '-';
}

class PemeriksaanRujukan {
  final DateTime? tanggalUkur;
  final String usiaUkur;
  final double? bbKg, tbCm, lilaCm, lkCm;
  final String statusBbu, statusTbu, statusBbtb;
  final bool duaT, bgm;

  PemeriksaanRujukan.fromJson(Map<String, dynamic> j)
      : tanggalUkur = _tgl(j['tanggal_ukur']),
        usiaUkur = _s(j['usia_ukur']),
        bbKg = _dN(j['bb_kg']),
        tbCm = _dN(j['tb_cm']),
        lilaCm = _dN(j['lila_cm']),
        lkCm = _dN(j['lk_cm']),
        statusBbu = _s(j['status_bbu']),
        statusTbu = _s(j['status_tbu']),
        statusBbtb = _s(j['status_bbtb']),
        duaT = _b(j['dua_t']),
        bgm = _b(j['bgm']);

  /// "2T, BGM" atau kosong.
  String get tandaTimbang => [if (duaT) '2T (2 kali tidak naik)', if (bgm) 'BGM'].join(', ');
}

class DataAnakRujukan {
  final String anakId;
  final String nama, nik, jenisKelamin, usiaTeks;
  final DateTime? tanggalLahir;
  final double? beratLahirKg, panjangLahirCm;
  final String namaIbu, namaAyah, namaWali, noHp, alamat, posyandu;
  final PemeriksaanRujukan? pemeriksaan;
  final String keluhanTerakhir, penyakitPenyerta;

  DataAnakRujukan.fromJson(Map<String, dynamic> j)
      : anakId = _s(j['anak_id']),
        nama = _s(j['nama']),
        nik = _s(j['nik']),
        jenisKelamin = _s(j['jenis_kelamin']),
        usiaTeks = _s(j['usia_teks']),
        tanggalLahir = _tgl(j['tanggal_lahir']),
        beratLahirKg = _dN(j['berat_lahir_kg']),
        panjangLahirCm = _dN(j['panjang_lahir_cm']),
        namaIbu = _s(j['nama_ibu']),
        namaAyah = _s(j['nama_ayah']),
        namaWali = _s(j['nama_wali']),
        noHp = _s(j['no_hp']),
        alamat = _s(j['alamat']),
        posyandu = _s(j['posyandu']),
        pemeriksaan = j['pemeriksaan'] is Map ? PemeriksaanRujukan.fromJson(_m(j['pemeriksaan'])) : null,
        keluhanTerakhir = _s(j['keluhan_terakhir']),
        penyakitPenyerta = _s(j['penyakit_penyerta']);
}

class AnakCariRujukan {
  final String anakId, nama, jenisKelamin, usiaTeks, namaOrangTua;

  AnakCariRujukan.fromJson(Map<String, dynamic> j)
      : anakId = _s(j['anak_id']),
        nama = _s(j['nama']),
        jenisKelamin = _s(j['jenis_kelamin']),
        usiaTeks = _s(j['usia_teks']),
        namaOrangTua = _s(j['nama_orang_tua']);
}

class RujukanRingkas {
  final String id, nomor, anakId, namaAnak, jenisKelamin, usiaTeks, diagnosis, tujuan, status;
  final DateTime? tanggal;

  RujukanRingkas.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        nomor = _s(j['nomor']),
        anakId = _s(j['anak_id']),
        namaAnak = _s(j['nama_anak']),
        jenisKelamin = _s(j['jenis_kelamin']),
        usiaTeks = _s(j['usia_teks']),
        diagnosis = _s(j['diagnosis']),
        tujuan = _s(j['tujuan']),
        status = _s(j['status']),
        tanggal = _tgl(j['tanggal']);
}

class RujukanBalik {
  final DateTime? tanggalDiperiksa;
  final String hasilDiagnosis, terapiSaran, tindakLanjut;

  RujukanBalik.fromJson(Map<String, dynamic> j)
      : tanggalDiperiksa = _tgl(j['tanggal_diperiksa']),
        hasilDiagnosis = _s(j['hasil_diagnosis']),
        terapiSaran = _s(j['terapi_saran']),
        tindakLanjut = _s(j['tindak_lanjut']);
}

class RujukanDetail {
  final String id, nomor, posyandu, status;
  final DateTime? tanggal;
  final DataAnakRujukan dataAnak;
  final String keluhan, diagnosis, tindakan, tujuan, bidanNama;
  final RujukanBalik? balik;
  final String alasanBatal;
  final DateTime? dibatalkanPada;

  RujukanDetail.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        nomor = _s(j['nomor']),
        posyandu = _s(j['posyandu']),
        status = _s(j['status']),
        tanggal = _tgl(j['tanggal']),
        dataAnak = DataAnakRujukan.fromJson(_m(j['data_anak'])),
        keluhan = _s(j['keluhan']),
        diagnosis = _s(j['diagnosis']),
        tindakan = _s(j['tindakan']),
        tujuan = _s(j['tujuan']),
        bidanNama = _s(j['bidan_nama']),
        balik = j['rujukan_balik'] is Map ? RujukanBalik.fromJson(_m(j['rujukan_balik'])) : null,
        alasanBatal = _s(j['alasan_batal']),
        dibatalkanPada = _waktu(j['dibatalkan_pada']);

  bool get aktif => status == 'dirujuk';
  bool get selesai => status == 'selesai';
  bool get dibatalkan => status == 'dibatalkan';
}

String labelStatusRujukan(String s) {
  switch (s) {
    case 'dirujuk':
      return 'Dirujuk';
    case 'selesai':
      return 'Selesai';
    case 'dibatalkan':
      return 'Dibatalkan';
    default:
      return s;
  }
}

// ============================================================================
// SERVICE
// ============================================================================

class RujukanService {
  const RujukanService();

  String _pesanError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server tidak merespons. Periksa koneksi Anda.';
      default:
        return 'Tidak dapat terhubung ke server';
    }
  }

  dynamic _data(dynamic root) => (root is Map && root.containsKey('data')) ? root['data'] : root;

  Future<dynamic> _get(String path, [Map<String, dynamic>? q]) async {
    try {
      final res = await ApiClient.dio.get(path,
          queryParameters: q, options: Options(receiveTimeout: const Duration(seconds: 20)));
      return _data(res.data);
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<dynamic> _kirim(String metode, String path, Map<String, dynamic> body) async {
    try {
      final res = await ApiClient.dio.request(path,
          data: body,
          options: Options(method: metode, receiveTimeout: const Duration(seconds: 20)));
      return _data(res.data);
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // ------------------------------------------------------------------ bidan

  /// [status] 'aktif' | 'selesai'.
  Future<List<RujukanRingkas>> daftarBidan(String status) async =>
      _l(await _get('/bidan/rujukan', {'status': status})).map(RujukanRingkas.fromJson).toList();

  Future<List<AnakCariRujukan>> cariAnak(String kata) async =>
      _l(await _get('/bidan/rujukan-anak', {'cari': kata})).map(AnakCariRujukan.fromJson).toList();

  Future<DataAnakRujukan> dataAnak(String anakId) async =>
      DataAnakRujukan.fromJson(_m(await _get('/bidan/rujukan-anak/$anakId')));

  Future<RujukanDetail> buat({
    required String anakId,
    required String keluhan,
    required String diagnosis,
    required String tindakan,
    required String tujuan,
  }) async =>
      RujukanDetail.fromJson(_m(await _kirim('POST', '/bidan/rujukan', {
        'anak_id': anakId,
        'keluhan': keluhan,
        'diagnosis': diagnosis,
        'tindakan': tindakan,
        'tujuan': tujuan,
      })));

  /// Ubah isian rujukan yang masih aktif.
  Future<RujukanDetail> ubah(
    String id, {
    required String keluhan,
    required String diagnosis,
    required String tindakan,
    required String tujuan,
  }) async =>
      RujukanDetail.fromJson(_m(await _kirim('PUT', '/bidan/rujukan/$id', {
        'keluhan': keluhan,
        'diagnosis': diagnosis,
        'tindakan': tindakan,
        'tujuan': tujuan,
      })));

  Future<RujukanDetail> detailBidan(String id) async =>
      RujukanDetail.fromJson(_m(await _get('/bidan/rujukan/$id')));

  Future<RujukanDetail> catatBalik(
    String id, {
    required DateTime tanggalDiperiksa,
    required String hasilDiagnosis,
    required String terapiSaran,
    required String tindakLanjut,
  }) async {
    final t = '${tanggalDiperiksa.year.toString().padLeft(4, '0')}-'
        '${tanggalDiperiksa.month.toString().padLeft(2, '0')}-'
        '${tanggalDiperiksa.day.toString().padLeft(2, '0')}';
    return RujukanDetail.fromJson(_m(await _kirim('PUT', '/bidan/rujukan/$id/balik', {
      'tanggal_diperiksa': t,
      'hasil_diagnosis': hasilDiagnosis,
      'terapi_saran': terapiSaran,
      'tindak_lanjut': tindakLanjut,
    })));
  }

  /// Hapus rujukan (bidan).
  Future<void> hapus(String id) async {
    try {
      await ApiClient.dio.delete('/bidan/rujukan/$id',
          options: Options(receiveTimeout: const Duration(seconds: 20)));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<RujukanDetail> batal(String id, String alasan) async =>
      RujukanDetail.fromJson(_m(await _kirim('POST', '/bidan/rujukan/$id/batal', {'alasan': alasan})));

  // ------------------------------------------------------------------ orang tua

  Future<List<RujukanRingkas>> daftarOrangTua() async =>
      _l(await _get('/rujukan')).map(RujukanRingkas.fromJson).toList();

  Future<RujukanDetail> detailOrangTua(String id) async =>
      RujukanDetail.fromJson(_m(await _get('/rujukan/$id')));
}