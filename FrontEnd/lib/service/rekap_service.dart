import 'package:dio/dio.dart';

import '../core/config/api_client.dart';

// ============================================================================
// MODEL REKAP POSYANDU
// ============================================================================

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
double? _dN(dynamic v) => v == null ? null : double.tryParse(_s(v));
bool _b(dynamic v) => v == true || _s(v) == 'true';
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
List<String> _ls(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

DateTime? _tgl(dynamic v) {
  final t = _s(v);
  if (t.length < 10) return null;
  return DateTime.tryParse(t.substring(0, 10));
}

/// Format bulan untuk API: "2026-11".
String bulanApi(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

const namaBulanRekap = [
  '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

class AnakRekap {
  final String anakId;
  final String nama;
  final String jenisKelamin;
  final DateTime? tanggalLahir;
  final int usiaBulan;
  final String usiaTeks;

  const AnakRekap({
    required this.anakId,
    required this.nama,
    required this.jenisKelamin,
    required this.tanggalLahir,
    required this.usiaBulan,
    required this.usiaTeks,
  });

  factory AnakRekap.fromJson(Map<String, dynamic> j) => AnakRekap(
        anakId: _s(j['anak_id']),
        nama: _s(j['nama']).isEmpty ? '-' : _s(j['nama']),
        jenisKelamin: _s(j['jenis_kelamin']),
        tanggalLahir: _tgl(j['tanggal_lahir']),
        usiaBulan: _i(j['usia_bulan']),
        usiaTeks: _s(j['usia_teks']),
      );

  String get jkTeks => jenisKelamin == 'P' ? 'Perempuan' : 'Laki-laki';
}

// ---------------------------------------------------------------- status gizi

class KategoriGizi {
  final String kode;
  final String label;
  final String indeks;
  final int jumlah;
  final double persen;
  final String tingkat; // baik | waspada | risiko

  const KategoriGizi({
    required this.kode,
    required this.label,
    required this.indeks,
    required this.jumlah,
    required this.persen,
    required this.tingkat,
  });

  factory KategoriGizi.fromJson(Map<String, dynamic> j) => KategoriGizi(
        kode: _s(j['kode']),
        label: _s(j['label']),
        indeks: _s(j['indeks']),
        jumlah: _i(j['jumlah']),
        persen: _d(j['persen']),
        tingkat: _s(j['tingkat']),
      );
}

class AnakGizi {
  final AnakRekap anak;
  final DateTime? tanggalUkur;
  final double? zBbu;
  final double? zTbu;
  final double? zBbtb;
  final List<String> masalah;

  const AnakGizi({
    required this.anak,
    required this.tanggalUkur,
    required this.zBbu,
    required this.zTbu,
    required this.zBbtb,
    required this.masalah,
  });

  factory AnakGizi.fromJson(Map<String, dynamic> j) => AnakGizi(
        anak: AnakRekap.fromJson(j),
        tanggalUkur: _tgl(j['tanggal_ukur']),
        zBbu: _dN(j['z_bbu']),
        zTbu: _dN(j['z_tbu']),
        zBbtb: _dN(j['z_bbtb']),
        masalah: _ls(j['masalah']),
      );
}

class TrenGizi {
  final String bulan;
  final String label;
  final int diukur;
  final int stunting;
  final int wasting;
  final int underweight;

  const TrenGizi({
    required this.bulan,
    required this.label,
    required this.diukur,
    required this.stunting,
    required this.wasting,
    required this.underweight,
  });

  factory TrenGizi.fromJson(Map<String, dynamic> j) => TrenGizi(
        bulan: _s(j['bulan']),
        label: _s(j['label']),
        diukur: _i(j['diukur']),
        stunting: _i(j['stunting']),
        wasting: _i(j['wasting']),
        underweight: _i(j['underweight']),
      );
}

class RekapGizi {
  final String label;
  final int sasaran;
  final int diukur;
  final double partisipasi;
  final int normal;
  final int stunting;
  final int wasting;
  final int underweight;
  final int giziLebih;
  final List<KategoriGizi> kategori;
  final List<TrenGizi> tren;
  final List<AnakGizi> prioritas;

  const RekapGizi({
    required this.label,
    required this.sasaran,
    required this.diukur,
    required this.partisipasi,
    required this.normal,
    required this.stunting,
    required this.wasting,
    required this.underweight,
    required this.giziLebih,
    required this.kategori,
    required this.tren,
    required this.prioritas,
  });

  factory RekapGizi.fromJson(Map<String, dynamic> j) => RekapGizi(
        label: _s(j['label']),
        sasaran: _i(j['sasaran']),
        diukur: _i(j['diukur']),
        partisipasi: _d(j['partisipasi']),
        normal: _i(j['normal']),
        stunting: _i(j['stunting']),
        wasting: _i(j['wasting']),
        underweight: _i(j['underweight']),
        giziLebih: _i(j['gizi_lebih']),
        kategori: _l(j['kategori']).map(KategoriGizi.fromJson).toList(),
        tren: _l(j['tren']).map(TrenGizi.fromJson).toList(),
        prioritas: _l(j['prioritas']).map(AnakGizi.fromJson).toList(),
      );

  double persen(int n) => diukur == 0 ? 0 : (n * 1000 / diukur).round() / 10;
}

// ---------------------------------------------------------------- Vitamin A & obat cacing

class KelompokSuplemen {
  final String kode;
  final String label;
  final String keterangan;
  final int sasaran;
  final int sudah;
  final int belum;
  final double persen;

  const KelompokSuplemen({
    required this.kode,
    required this.label,
    required this.keterangan,
    required this.sasaran,
    required this.sudah,
    required this.belum,
    required this.persen,
  });

  factory KelompokSuplemen.fromJson(Map<String, dynamic> j) => KelompokSuplemen(
        kode: _s(j['kode']),
        label: _s(j['label']),
        keterangan: _s(j['keterangan']),
        sasaran: _i(j['sasaran']),
        sudah: _i(j['sudah']),
        belum: _i(j['belum']),
        persen: _d(j['persen']),
      );
}

class AnakSuplemen {
  final AnakRekap anak;
  final String kelompok;
  final List<String> belum;

  const AnakSuplemen({required this.anak, required this.kelompok, required this.belum});

  factory AnakSuplemen.fromJson(Map<String, dynamic> j) => AnakSuplemen(
        anak: AnakRekap.fromJson(j),
        kelompok: _s(j['kelompok']),
        belum: _ls(j['belum']),
      );
}

class RekapSuplemen {
  final int tahun;
  final int periode;
  final String label;
  final DateTime? rentangDari;
  final DateTime? rentangSampai;
  final List<KelompokSuplemen> vitaminA;
  final KelompokSuplemen obatCacing;
  final List<AnakSuplemen> belumMenerima;

  const RekapSuplemen({
    required this.tahun,
    required this.periode,
    required this.label,
    required this.rentangDari,
    required this.rentangSampai,
    required this.vitaminA,
    required this.obatCacing,
    required this.belumMenerima,
  });

  factory RekapSuplemen.fromJson(Map<String, dynamic> j) => RekapSuplemen(
        tahun: _i(j['tahun']),
        periode: _i(j['periode']),
        label: _s(j['label']),
        rentangDari: _tgl(j['rentang_dari']),
        rentangSampai: _tgl(j['rentang_sampai']),
        vitaminA: _l(j['vitamin_a']).map(KelompokSuplemen.fromJson).toList(),
        obatCacing: KelompokSuplemen.fromJson(_m(j['obat_cacing'])),
        belumMenerima: _l(j['belum_menerima']).map(AnakSuplemen.fromJson).toList(),
      );
}

// ---------------------------------------------------------------- balita tidak hadir

class AnakTidakHadir {
  final AnakRekap anak;
  final DateTime? terakhirDitimbang;
  final int bulanTidakDatang; // -1 = belum pernah ditimbang
  final bool sudahMendaftar;
  final String keterangan;

  const AnakTidakHadir({
    required this.anak,
    required this.terakhirDitimbang,
    required this.bulanTidakDatang,
    required this.sudahMendaftar,
    required this.keterangan,
  });

  factory AnakTidakHadir.fromJson(Map<String, dynamic> j) => AnakTidakHadir(
        anak: AnakRekap.fromJson(j),
        terakhirDitimbang: _tgl(j['terakhir_ditimbang']),
        bulanTidakDatang: _i(j['bulan_tidak_datang']),
        sudahMendaftar: _b(j['sudah_mendaftar']),
        keterangan: _s(j['keterangan']),
      );

  bool get belumPernah => bulanTidakDatang < 0;
}

class RekapTidakHadir {
  final String label;
  final int jumlahJadwal;
  final int sasaran;
  final int ditimbang;
  final int tidakHadir;
  final double persenDS;
  final int belumPernah;
  final List<AnakTidakHadir> anak;

  const RekapTidakHadir({
    required this.label,
    required this.jumlahJadwal,
    required this.sasaran,
    required this.ditimbang,
    required this.tidakHadir,
    required this.persenDS,
    required this.belumPernah,
    required this.anak,
  });

  factory RekapTidakHadir.fromJson(Map<String, dynamic> j) => RekapTidakHadir(
        label: _s(j['label']),
        jumlahJadwal: _i(j['jumlah_jadwal']),
        sasaran: _i(j['sasaran']),
        ditimbang: _i(j['ditimbang']),
        tidakHadir: _i(j['tidak_hadir']),
        persenDS: _d(j['persen_ds']),
        belumPernah: _i(j['belum_pernah']),
        anak: _l(j['anak']).map(AnakTidakHadir.fromJson).toList(),
      );
}

// ============================================================================
// SERVICE
// ============================================================================

class RekapService {
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

  Map<String, dynamic> _data(dynamic root) =>
      _m((root is Map && root.containsKey('data')) ? root['data'] : root);

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> q) async {
    try {
      final res = await ApiClient.dio.get(
        path,
        queryParameters: q,
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return _data(res.data);
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Sekretaris: rekap status gizi satu bulan.
  /// Rekap status gizi. [prefix] '/sekretaris' atau '/bidan'.
  Future<RekapGizi> gizi(DateTime bulan, {String prefix = '/sekretaris'}) async =>
      RekapGizi.fromJson(await _get('$prefix/rekap/gizi', {'bulan': bulanApi(bulan)}));

  /// Sekretaris: rekap Vitamin A dan obat cacing. [periode] 1 = Februari, 2 = Agustus.
  /// Rekap Vitamin A & obat cacing. [prefix] '/sekretaris' atau '/bidan'.
  Future<RekapSuplemen> suplemen(int tahun, int periode, {String prefix = '/sekretaris'}) async =>
      RekapSuplemen.fromJson(
          await _get('$prefix/rekap/suplemen', {'tahun': tahun, 'periode': periode}));

  /// Balita tidak hadir. [prefix] '/sekretaris', '/bidan', atau '/kader'.
  Future<RekapTidakHadir> tidakHadir(String prefix, DateTime bulan) async =>
      RekapTidakHadir.fromJson(await _get('$prefix/rekap/tidak-hadir', {'bulan': bulanApi(bulan)}));
}