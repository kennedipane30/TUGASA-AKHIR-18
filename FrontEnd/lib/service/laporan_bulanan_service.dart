import 'package:dio/dio.dart';

import '../core/config/api_client.dart';
import 'rekap_service.dart' show bulanApi;

// ============================================================================
// MODEL LAPORAN BULANAN POSYANDU (sekretaris & bidan)
// ============================================================================

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
List<String> _ls(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

class KegiatanLaporan {
  final int jumlahSesi;
  final List<DateTime> tanggalSesi;
  final int sasaran;
  final int didaftarkan;
  final int hadir;
  final int tidakHadir;
  final double persenHadir;

  KegiatanLaporan.fromJson(Map<String, dynamic> j)
      : jumlahSesi = _i(j['jumlah_sesi']),
        tanggalSesi = _ls(j['tanggal_sesi'])
            .map((t) => DateTime.tryParse(t.length >= 10 ? t.substring(0, 10) : t))
            .whereType<DateTime>()
            .toList(),
        sasaran = _i(j['sasaran']),
        didaftarkan = _i(j['didaftarkan']),
        hadir = _i(j['hadir']),
        tidakHadir = _i(j['tidak_hadir']),
        persenHadir = _d(j['persen_hadir']);
}

class SkdnLaporan {
  final int s, k, d, n, t, duaT, bgm;
  final double persenKS, persenDS, persenND;

  SkdnLaporan.fromJson(Map<String, dynamic> j)
      : s = _i(j['s']),
        k = _i(j['k']),
        d = _i(j['d']),
        n = _i(j['n']),
        t = _i(j['t']),
        duaT = _i(j['dua_t']),
        bgm = _i(j['bgm']),
        persenKS = _d(j['persen_ks']),
        persenDS = _d(j['persen_ds']),
        persenND = _d(j['persen_nd']);
}

class KategoriGiziLaporan {
  final String label;
  final String indeks;
  final int jumlah;
  final double persen;

  KategoriGiziLaporan.fromJson(Map<String, dynamic> j)
      : label = _s(j['label']),
        indeks = _s(j['indeks']),
        jumlah = _i(j['jumlah']),
        persen = _d(j['persen']);
}

class GiziLaporan {
  final int diukur, normal, stunting, wasting, underweight, giziLebih;
  final List<KategoriGiziLaporan> kategori;

  GiziLaporan.fromJson(Map<String, dynamic> j)
      : diukur = _i(j['diukur']),
        normal = _i(j['normal']),
        stunting = _i(j['stunting']),
        wasting = _i(j['wasting']),
        underweight = _i(j['underweight']),
        giziLebih = _i(j['gizi_lebih']),
        kategori = _l(j['kategori']).map(KategoriGiziLaporan.fromJson).toList();
}

class JumlahLaporan {
  final String nama;
  final int jumlah;

  JumlahLaporan.fromJson(Map<String, dynamic> j)
      : nama = _s(j['nama']),
        jumlah = _i(j['jumlah']);
}

class BalitaBerisikoLaporan {
  final String nama;
  final String jenisKelamin;
  final String usiaTeks;
  final List<String> masalah;

  BalitaBerisikoLaporan.fromJson(Map<String, dynamic> j)
      : nama = _s(j['nama']),
        jenisKelamin = _s(j['jenis_kelamin']),
        usiaTeks = _s(j['usia_teks']),
        masalah = _ls(j['masalah']);

  String get jk {
    final v = jenisKelamin.toUpperCase();
    if (v.startsWith('L')) return 'L';
    if (v.startsWith('P')) return 'P';
    return '-';
  }
}

class LaporanBulanan {
  final String bulan;
  final String label;
  final String posyandu;
  final KegiatanLaporan kegiatan;
  final SkdnLaporan skdn;
  final GiziLaporan gizi;
  final List<JumlahLaporan> imunisasi;
  final int totalImunisasi;
  final List<JumlahLaporan> suplemen;
  final List<BalitaBerisikoLaporan> balitaBerisiko;

  LaporanBulanan.fromJson(Map<String, dynamic> j)
      : bulan = _s(j['bulan']),
        label = _s(j['label']),
        posyandu = _s(j['posyandu']),
        kegiatan = KegiatanLaporan.fromJson(_m(j['kegiatan'])),
        skdn = SkdnLaporan.fromJson(_m(j['skdn'])),
        gizi = GiziLaporan.fromJson(_m(j['gizi'])),
        imunisasi = _l(j['imunisasi']).map(JumlahLaporan.fromJson).toList(),
        totalImunisasi = _i(j['total_imunisasi']),
        suplemen = _l(j['suplemen']).map(JumlahLaporan.fromJson).toList(),
        balitaBerisiko = _l(j['balita_berisiko']).map(BalitaBerisikoLaporan.fromJson).toList();
}

// ============================================================================
// SERVICE
// ============================================================================

class LaporanBulananService {
  /// [prefix] '/sekretaris' atau '/bidan'.
  final String prefix;

  const LaporanBulananService(this.prefix);

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

  Future<LaporanBulanan> ambil(DateTime bulan) async {
    try {
      final res = await ApiClient.dio.get(
        '$prefix/laporan-bulanan',
        queryParameters: {'bulan': bulanApi(bulan)},
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      final root = res.data;
      final data = (root is Map && root.containsKey('data')) ? root['data'] : root;
      return LaporanBulanan.fromJson(_m(data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }
}