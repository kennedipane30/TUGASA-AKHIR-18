import 'package:dio/dio.dart';

import '../core/api_client.dart';

// ============================================================================
// MODEL SEMUA BALITA
// ============================================================================

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
int? _iN(dynamic v) => v == null ? null : int.tryParse(_s(v));
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
double? _dN(dynamic v) => v == null ? null : double.tryParse(_s(v));
bool _b(dynamic v) => v == true || _s(v) == 'true';
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
List<String> _ls(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

DateTime? _tgl(dynamic v) {
  final t = _s(v);
  if (t.length < 10) return null;
  return DateTime.tryParse(t.substring(0, 10));
}

class TimbangRingkas {
  final DateTime? tanggal;
  final String usiaTeks;
  final double bbKg;
  final double tbCm;
  final String caraUkur;
  final double? lkCm;
  final double? lilaCm;
  final String statusTimbang; // N | T | O | B | ''
  final int? kenaikanGram;
  final int? kbmGram;
  final bool duaT;
  final bool bgm;
  final String kategoriBbu;
  final String kategoriTbu;
  final String kategoriBbtb;
  final double? zBbu;
  final double? zTbu;
  final double? zBbtb;
  final List<String> masalah;
  final String tingkat;

  const TimbangRingkas({
    required this.tanggal,
    required this.usiaTeks,
    required this.bbKg,
    required this.tbCm,
    required this.caraUkur,
    required this.lkCm,
    required this.lilaCm,
    required this.statusTimbang,
    required this.kenaikanGram,
    required this.kbmGram,
    required this.duaT,
    required this.bgm,
    required this.kategoriBbu,
    required this.kategoriTbu,
    required this.kategoriBbtb,
    required this.zBbu,
    required this.zTbu,
    required this.zBbtb,
    required this.masalah,
    required this.tingkat,
  });

  factory TimbangRingkas.fromJson(Map<String, dynamic> j) => TimbangRingkas(
        tanggal: _tgl(j['tanggal']),
        usiaTeks: _s(j['usia_teks']),
        bbKg: _d(j['bb_kg']),
        tbCm: _d(j['tb_cm']),
        caraUkur: _s(j['cara_ukur']),
        lkCm: _dN(j['lingkar_kepala_cm']),
        lilaCm: _dN(j['lila_cm']),
        statusTimbang: _s(j['status_timbang']),
        kenaikanGram: _iN(j['kenaikan_gram']),
        kbmGram: _iN(j['kbm_gram']),
        duaT: _b(j['dua_t']),
        bgm: _b(j['bgm']),
        kategoriBbu: _s(j['kategori_bbu']),
        kategoriTbu: _s(j['kategori_tbu']),
        kategoriBbtb: _s(j['kategori_bbtb']),
        zBbu: _dN(j['z_bbu']),
        zTbu: _dN(j['z_tbu']),
        zBbtb: _dN(j['z_bbtb']),
        masalah: _ls(j['masalah']),
        tingkat: _s(j['tingkat']),
      );

  bool get perluPerhatian => duaT || bgm;
}

class VaksinRingkas {
  final int totalDosis;
  final int sudah;
  final int jatuhTempo;
  final int terlambat;
  final int persen;
  final bool dasarLengkap;

  const VaksinRingkas({
    required this.totalDosis,
    required this.sudah,
    required this.jatuhTempo,
    required this.terlambat,
    required this.persen,
    required this.dasarLengkap,
  });

  factory VaksinRingkas.fromJson(Map<String, dynamic> j) => VaksinRingkas(
        totalDosis: _i(j['total_dosis']),
        sudah: _i(j['sudah']),
        jatuhTempo: _i(j['jatuh_tempo']),
        terlambat: _i(j['terlambat']),
        persen: _i(j['persen']),
        dasarLengkap: _b(j['dasar_lengkap']),
      );
}

class BalitaItem {
  final String anakId;
  final String nama;
  final String jenisKelamin;
  final DateTime? tanggalLahir;
  final int usiaBulan;
  final String usiaTeks;
  final String status;
  final String kelompokUsia; // 0-11 | 12-23 | 24-59
  final int jumlahTimbang;
  final TimbangRingkas? terakhir;
  final int bulanTidakDatang; // -1 = belum pernah ditimbang
  final VaksinRingkas vaksin;

  const BalitaItem({
    required this.anakId,
    required this.nama,
    required this.jenisKelamin,
    required this.tanggalLahir,
    required this.usiaBulan,
    required this.usiaTeks,
    required this.status,
    required this.kelompokUsia,
    required this.jumlahTimbang,
    required this.terakhir,
    required this.bulanTidakDatang,
    required this.vaksin,
  });

  factory BalitaItem.fromJson(Map<String, dynamic> j) => BalitaItem(
        anakId: _s(j['anak_id']),
        nama: _s(j['nama']).isEmpty ? '-' : _s(j['nama']),
        jenisKelamin: _s(j['jenis_kelamin']),
        tanggalLahir: _tgl(j['tanggal_lahir']),
        usiaBulan: _i(j['usia_bulan']),
        usiaTeks: _s(j['usia_teks']),
        status: _s(j['status']),
        kelompokUsia: _s(j['kelompok_usia']),
        jumlahTimbang: _i(j['jumlah_timbang']),
        terakhir: j['terakhir'] is Map ? TimbangRingkas.fromJson(_m(j['terakhir'])) : null,
        bulanTidakDatang: _i(j['bulan_tidak_datang']),
        vaksin: VaksinRingkas.fromJson(_m(j['vaksin'])),
      );

  String get jkTeks => jenisKelamin == 'P' ? 'Perempuan' : 'Laki-laki';
  bool get masalahGizi => (terakhir?.masalah.isNotEmpty ?? false);
  bool get perluPerhatian => terakhir?.perluPerhatian ?? false;
}

class RingkasBalita {
  final int total;
  final int lakiLaki;
  final int perempuan;
  final int usia0_11;
  final int usia12_23;
  final int usia24_59;
  final int masalahGizi;
  final int stunting;
  final int duaTBgm;
  final int vaksinTerlambat;
  final int belumPernah;

  const RingkasBalita({
    required this.total,
    required this.lakiLaki,
    required this.perempuan,
    required this.usia0_11,
    required this.usia12_23,
    required this.usia24_59,
    required this.masalahGizi,
    required this.stunting,
    required this.duaTBgm,
    required this.vaksinTerlambat,
    required this.belumPernah,
  });

  factory RingkasBalita.fromJson(Map<String, dynamic> j) => RingkasBalita(
        total: _i(j['total']),
        lakiLaki: _i(j['laki_laki']),
        perempuan: _i(j['perempuan']),
        usia0_11: _i(j['usia_0_11']),
        usia12_23: _i(j['usia_12_23']),
        usia24_59: _i(j['usia_24_59']),
        masalahGizi: _i(j['masalah_gizi']),
        stunting: _i(j['stunting']),
        duaTBgm: _i(j['dua_t_bgm']),
        vaksinTerlambat: _i(j['vaksin_terlambat']),
        belumPernah: _i(j['belum_pernah']),
      );
}

class DaftarBalita {
  final RingkasBalita ringkas;
  final List<BalitaItem> balita;

  const DaftarBalita({required this.ringkas, required this.balita});

  factory DaftarBalita.fromJson(Map<String, dynamic> j) => DaftarBalita(
        ringkas: RingkasBalita.fromJson(_m(j['ringkas'])),
        balita: _l(j['balita']).map(BalitaItem.fromJson).toList(),
      );
}

class DetailBalita {
  final Map<String, dynamic> anak;
  final Map<String, dynamic> keluarga;
  final BalitaItem ringkas;
  final List<TimbangRingkas> riwayat;

  const DetailBalita({
    required this.anak,
    required this.keluarga,
    required this.ringkas,
    required this.riwayat,
  });

  factory DetailBalita.fromJson(Map<String, dynamic> j) => DetailBalita(
        anak: _m(j['anak']),
        keluarga: _m(j['keluarga']),
        ringkas: BalitaItem.fromJson(_m(j['ringkas'])),
        riwayat: _l(j['riwayat']).map(TimbangRingkas.fromJson).toList(),
      );
}

class AnakBerisiko {
  final BalitaItem balita;
  final List<String> alasan;
  final int skor;
  final String tingkat; // tinggi | sedang

  const AnakBerisiko({required this.balita, required this.alasan, required this.skor, required this.tingkat});

  factory AnakBerisiko.fromJson(Map<String, dynamic> j) => AnakBerisiko(
        balita: BalitaItem.fromJson(j),
        alasan: _ls(j['alasan']),
        skor: _i(j['skor']),
        tingkat: _s(j['tingkat']),
      );

  bool get tinggi => tingkat == 'tinggi';
}

class RingkasBerisiko {
  final int total;
  final int tinggi;
  final int sedang;
  final int duaT;
  final int bgm;
  final int giziBuruk;
  final int wasting;
  final int stunting;

  const RingkasBerisiko({
    required this.total,
    required this.tinggi,
    required this.sedang,
    required this.duaT,
    required this.bgm,
    required this.giziBuruk,
    required this.wasting,
    required this.stunting,
  });

  factory RingkasBerisiko.fromJson(Map<String, dynamic> j) => RingkasBerisiko(
        total: _i(j['total']),
        tinggi: _i(j['tinggi']),
        sedang: _i(j['sedang']),
        duaT: _i(j['dua_t']),
        bgm: _i(j['bgm']),
        giziBuruk: _i(j['gizi_buruk']),
        wasting: _i(j['wasting']),
        stunting: _i(j['stunting']),
      );
}

class DaftarBerisiko {
  final RingkasBerisiko ringkas;
  final List<AnakBerisiko> anak;

  const DaftarBerisiko({required this.ringkas, required this.anak});

  factory DaftarBerisiko.fromJson(Map<String, dynamic> j) => DaftarBerisiko(
        ringkas: RingkasBerisiko.fromJson(_m(j['ringkas'])),
        anak: _l(j['anak']).map(AnakBerisiko.fromJson).toList(),
      );
}

// ============================================================================
// SERVICE
// ============================================================================

class BalitaService {
  /// [prefix] '/sekretaris', '/kader', atau '/bidan'.
  final String prefix;

  const BalitaService(this.prefix);

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

  Map<String, dynamic> _data(dynamic root) => _m((root is Map && root.containsKey('data')) ? root['data'] : root);

  Future<DaftarBalita> daftar({String cari = '', bool semua = false}) async {
    try {
      final res = await ApiClient.dio.get(
        '$prefix/balita',
        queryParameters: {if (cari.isNotEmpty) 'cari': cari, if (semua) 'semua': '1'},
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return DaftarBalita.fromJson(_data(res.data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Bidan: daftar anak berisiko (deteksi dini), urut dari risiko tertinggi.
  Future<DaftarBerisiko> berisiko() async {
    try {
      final res = await ApiClient.dio.get(
        '$prefix/balita-berisiko',
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return DaftarBerisiko.fromJson(_data(res.data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<DetailBalita> detail(String anakId) async {
    try {
      final res = await ApiClient.dio.get('$prefix/balita/$anakId');
      return DetailBalita.fromJson(_data(res.data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }
}