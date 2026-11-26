import 'package:dio/dio.dart';

import '../core/config/api_client.dart';

// ============================================================================
// MODEL RINGKASAN PENIMBANGAN (SKDN)
//
//   S = jumlah seluruh balita        K = balita yang punya Buku KIA
//   D = balita yang datang ditimbang N = balita yang berat badannya naik
// ============================================================================

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
int? _iN(dynamic v) => v == null ? null : int.tryParse(_s(v));
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
bool _b(dynamic v) => v == true || _s(v) == 'true';
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

DateTime? _tgl(dynamic v) {
  final t = _s(v);
  if (t.length < 10) return null;
  return DateTime.tryParse(t.substring(0, 10));
}

/// Angka SKDN satu bulan.
class SkdnBulan {
  final String bulan; // YYYY-MM
  final String label; // November 2026
  final int s;
  final int k;
  final int d;
  final int n;
  final int t;
  final int o;
  final int b;
  final int duaT;
  final int bgm;
  final int tidakDatang;
  final double persenKS;
  final double persenDS;
  final double persenND;
  final double persenDK;
  final double persenNS;

  const SkdnBulan({
    required this.bulan,
    required this.label,
    required this.s,
    required this.k,
    required this.d,
    required this.n,
    required this.t,
    required this.o,
    required this.b,
    required this.duaT,
    required this.bgm,
    required this.tidakDatang,
    required this.persenKS,
    required this.persenDS,
    required this.persenND,
    required this.persenDK,
    required this.persenNS,
  });

  factory SkdnBulan.fromJson(Map<String, dynamic> j) => SkdnBulan(
        bulan: _s(j['bulan']),
        label: _s(j['label']),
        s: _i(j['s']),
        k: _i(j['k']),
        d: _i(j['d']),
        n: _i(j['n']),
        t: _i(j['t']),
        o: _i(j['o']),
        b: _i(j['b']),
        duaT: _i(j['dua_t']),
        bgm: _i(j['bgm']),
        tidakDatang: _i(j['tidak_datang']),
        persenKS: _d(j['persen_ks']),
        persenDS: _d(j['persen_ds']),
        persenND: _d(j['persen_nd']),
        persenDK: _d(j['persen_dk']),
        persenNS: _d(j['persen_ns']),
      );

  /// Label bulan singkat untuk grafik, mis. "Nov".
  String get labelSingkat {
    final p = label.split(' ');
    if (p.isEmpty || p.first.length < 3) return label;
    return p.first.substring(0, 3);
  }
}

/// Balita yang perlu perhatian (tidak naik, 2T, atau BGM).
class AnakSkdn {
  final String anakId;
  final String nama;
  final String jenisKelamin;
  final String usiaTeks;
  final DateTime? tanggalUkur;
  final double bbKg;
  final String status;
  final int? kenaikanGram;
  final int? kbmGram;
  final bool duaT;
  final bool bgm;
  final String keterangan;

  const AnakSkdn({
    required this.anakId,
    required this.nama,
    required this.jenisKelamin,
    required this.usiaTeks,
    required this.tanggalUkur,
    required this.bbKg,
    required this.status,
    required this.kenaikanGram,
    required this.kbmGram,
    required this.duaT,
    required this.bgm,
    required this.keterangan,
  });

  factory AnakSkdn.fromJson(Map<String, dynamic> j) => AnakSkdn(
        anakId: _s(j['anak_id']),
        nama: _s(j['nama']).isEmpty ? '-' : _s(j['nama']),
        jenisKelamin: _s(j['jenis_kelamin']),
        usiaTeks: _s(j['usia_teks']),
        tanggalUkur: _tgl(j['tanggal_ukur']),
        bbKg: _d(j['bb_kg']),
        status: _s(j['status']),
        kenaikanGram: _iN(j['kenaikan_gram']),
        kbmGram: _iN(j['kbm_gram']),
        duaT: _b(j['dua_t']),
        bgm: _b(j['bgm']),
        keterangan: _s(j['keterangan']),
      );

  String get jkTeks => jenisKelamin == 'P' ? 'Perempuan' : 'Laki-laki';
}

class SkdnData {
  final SkdnBulan bulan;
  final String posyandu;
  final double targetDS;
  final List<SkdnBulan> tren;
  final List<AnakSkdn> perluRujuk;
  final List<AnakSkdn> tidakNaik;

  const SkdnData({
    required this.bulan,
    required this.posyandu,
    required this.targetDS,
    required this.tren,
    required this.perluRujuk,
    required this.tidakNaik,
  });

  factory SkdnData.fromJson(Map<String, dynamic> j) => SkdnData(
        bulan: SkdnBulan.fromJson(j),
        posyandu: _s(j['posyandu']),
        targetDS: j['target_ds'] == null ? 85 : _d(j['target_ds']),
        tren: _l(j['tren']).map(SkdnBulan.fromJson).toList(),
        perluRujuk: _l(j['perlu_rujuk']).map(AnakSkdn.fromJson).toList(),
        tidakNaik: _l(j['tidak_naik']).map(AnakSkdn.fromJson).toList(),
      );

  bool get capaiTarget => bulan.persenDS >= targetDS;
}

// ============================================================================
// SERVICE
// ============================================================================

class SkdnService {
  /// [prefix] '/sekretaris' atau '/bidan'.
  final String prefix;

  const SkdnService(this.prefix);

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

  static String formatBulan(DateTime b) => '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}';

  /// Ringkasan penimbangan untuk [bulan] (default bulan berjalan).
  Future<SkdnData> hitung([DateTime? bulan]) async {
    try {
      final res = await ApiClient.dio.get(
        '$prefix/skdn',
        queryParameters: {if (bulan != null) 'bulan': formatBulan(bulan)},
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      final root = res.data;
      final data = (root is Map && root.containsKey('data')) ? root['data'] : root;
      return SkdnData.fromJson(_m(data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }
}