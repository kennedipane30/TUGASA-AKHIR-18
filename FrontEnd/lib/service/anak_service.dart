import 'package:dio/dio.dart';

import '../core/config/api_client.dart';

// ============================================================================
// MODEL SEMUA ANAK
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

/// Catatan pemeriksaan bidan pada satu kunjungan.
class CatatanBidanRingkas {
  final bool demam;
  final bool diare;
  final bool batuk;
  final String penyakitPenyerta;
  final String keluhan;
  final String catatanEvaluasi;
  final String saranGizi;
  final String saranPolaAsuh;
  final DateTime? kunjunganUlang;

  const CatatanBidanRingkas({
    required this.demam,
    required this.diare,
    required this.batuk,
    required this.penyakitPenyerta,
    required this.keluhan,
    required this.catatanEvaluasi,
    required this.saranGizi,
    required this.saranPolaAsuh,
    required this.kunjunganUlang,
  });

  factory CatatanBidanRingkas.fromJson(Map<String, dynamic> j) => CatatanBidanRingkas(
        demam: _b(j['demam']),
        diare: _b(j['diare']),
        batuk: _b(j['batuk']),
        penyakitPenyerta: _s(j['penyakit_penyerta']).trim(),
        keluhan: _s(j['keluhan']).trim(),
        catatanEvaluasi: _s(j['catatan_evaluasi']).trim(),
        saranGizi: _s(j['saran_gizi']).trim(),
        saranPolaAsuh: _s(j['saran_pola_asuh']).trim(),
        kunjunganUlang: _tgl(j['tanggal_kunjungan_ulang']),
      );

  List<String> get gejala => [
        if (demam) 'Demam',
        if (diare) 'Diare',
        if (batuk) 'Batuk',
      ];
}

/// Satu imunisasi atau suplemen yang diberikan pada kunjungan.
class PemberianRingkas {
  final String nama;
  final String keterangan;

  const PemberianRingkas({required this.nama, required this.keterangan});

  factory PemberianRingkas.fromJson(Map<String, dynamic> j) =>
      PemberianRingkas(nama: _s(j['nama']), keterangan: _s(j['keterangan']));
}

/// Data lengkap satu kunjungan posyandu (catatan kader & bidan, imunisasi, suplemen).
class KunjunganRingkas {
  final String pendaftaranId;
  final bool sedangSakit;
  final bool asiEksklusif;
  final String keluhanKader;
  final String catatanKader;
  final String peringatanValidasi;
  final CatatanBidanRingkas? catatanBidan;
  final List<PemberianRingkas> imunisasi;
  final List<PemberianRingkas> suplemen;

  const KunjunganRingkas({
    required this.pendaftaranId,
    required this.sedangSakit,
    required this.asiEksklusif,
    required this.keluhanKader,
    required this.catatanKader,
    required this.peringatanValidasi,
    required this.catatanBidan,
    required this.imunisasi,
    required this.suplemen,
  });

  factory KunjunganRingkas.fromJson(Map<String, dynamic> j) => KunjunganRingkas(
        pendaftaranId: _s(j['pendaftaran_id']),
        sedangSakit: _b(j['sedang_sakit']),
        asiEksklusif: _b(j['asi_eksklusif']),
        keluhanKader: _s(j['keluhan_kader']).trim(),
        catatanKader: _s(j['catatan_kader']).trim(),
        peringatanValidasi: _s(j['peringatan_validasi']).trim(),
        catatanBidan:
            j['catatan_bidan'] is Map ? CatatanBidanRingkas.fromJson(_m(j['catatan_bidan'])) : null,
        imunisasi: _l(j['imunisasi']).map(PemberianRingkas.fromJson).toList(),
        suplemen: _l(j['suplemen']).map(PemberianRingkas.fromJson).toList(),
      );
}

// ============================================================================
// USIA DETAIL
// ============================================================================

DateTime _tambahBulan(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final akhir = DateTime.utc(y, m + 1, 0).day;
  return DateTime.utc(y, m, d.day > akhir ? akhir : d.day);
}

/// Usia detail dari [lahir] sampai [pada] (default hari ini).
/// Contoh: "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan", "2 tahun".
String usiaDetail(DateTime? lahir, [DateTime? pada]) {
  if (lahir == null) return '-';
  final p = pada ?? DateTime.now();
  final a = DateTime.utc(lahir.year, lahir.month, lahir.day);
  final b = DateTime.utc(p.year, p.month, p.day);
  if (b.isBefore(a)) return '0 hari';

  var bulan = (b.year - a.year) * 12 + b.month - a.month;
  if (_tambahBulan(a, bulan).isAfter(b)) bulan--;
  final hari = b.difference(_tambahBulan(a, bulan)).inDays;
  final tahun = bulan ~/ 12;
  final sisaBulan = bulan % 12;

  if (bulan == 0) return '$hari hari';
  if (tahun == 0) return hari == 0 ? '$bulan bulan' : '$bulan bulan $hari hari';
  return sisaBulan == 0 ? '$tahun tahun' : '$tahun tahun $sisaBulan bulan';
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
  final KunjunganRingkas? kunjungan; // hanya terisi pada detail anak

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
    this.kunjungan,
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
        kunjungan: j['kunjungan'] is Map ? KunjunganRingkas.fromJson(_m(j['kunjungan'])) : null,
      );

  bool get perluPerhatian => duaT || bgm;
}

class ImunisasiRingkas {
  final int totalDosis;
  final int sudah;
  final int jatuhTempo;
  final int terlambat;
  final int persen;
  final bool dasarLengkap;

  const ImunisasiRingkas({
    required this.totalDosis,
    required this.sudah,
    required this.jatuhTempo,
    required this.terlambat,
    required this.persen,
    required this.dasarLengkap,
  });

  factory ImunisasiRingkas.fromJson(Map<String, dynamic> j) => ImunisasiRingkas(
        totalDosis: _i(j['total_dosis']),
        sudah: _i(j['sudah']),
        jatuhTempo: _i(j['jatuh_tempo']),
        terlambat: _i(j['terlambat']),
        persen: _i(j['persen']),
        dasarLengkap: _b(j['dasar_lengkap']),
      );
}

class AnakItem {
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
  final ImunisasiRingkas imunisasi;

  /// Hanya terisi untuk anak arsip (pindah, meninggal, lulus posyandu).
  final DateTime? tanggalArsip;
  final String alasanArsip;

  const AnakItem({
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
    required this.imunisasi,
    this.tanggalArsip,
    this.alasanArsip = '',
  });

  factory AnakItem.fromJson(Map<String, dynamic> j) => AnakItem(
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
        imunisasi: ImunisasiRingkas.fromJson(_m(j['vaksin'])),
        tanggalArsip: _tgl(j['tanggal_arsip']),
        alasanArsip: _s(j['alasan_arsip']),
      );

  bool get diarsipkan => status == 'arsip';

  String get jkTeks => jenisKelamin == 'P' ? 'Perempuan' : 'Laki-laki';
  bool get masalahGizi => (terakhir?.masalah.isNotEmpty ?? false);
  bool get perluPerhatian => terakhir?.perluPerhatian ?? false;
}

class RingkasAnak {
  final int total;
  final int lakiLaki;
  final int perempuan;
  final int usia0_11;
  final int usia12_23;
  final int usia24_59;
  final int masalahGizi;
  final int stunting;
  final int duaTBgm;
  final int imunisasiTerlambat;
  final int belumPernah;

  const RingkasAnak({
    required this.total,
    required this.lakiLaki,
    required this.perempuan,
    required this.usia0_11,
    required this.usia12_23,
    required this.usia24_59,
    required this.masalahGizi,
    required this.stunting,
    required this.duaTBgm,
    required this.imunisasiTerlambat,
    required this.belumPernah,
  });

  factory RingkasAnak.fromJson(Map<String, dynamic> j) => RingkasAnak(
        total: _i(j['total']),
        lakiLaki: _i(j['laki_laki']),
        perempuan: _i(j['perempuan']),
        usia0_11: _i(j['usia_0_11']),
        usia12_23: _i(j['usia_12_23']),
        usia24_59: _i(j['usia_24_59']),
        masalahGizi: _i(j['masalah_gizi']),
        stunting: _i(j['stunting']),
        duaTBgm: _i(j['dua_t_bgm']),
        imunisasiTerlambat: _i(j['vaksin_terlambat']),
        belumPernah: _i(j['belum_pernah']),
      );
}

class DaftarAnak {
  final RingkasAnak ringkas;
  final List<AnakItem> anak;

  const DaftarAnak({required this.ringkas, required this.anak});

  factory DaftarAnak.fromJson(Map<String, dynamic> j) => DaftarAnak(
        ringkas: RingkasAnak.fromJson(_m(j['ringkas'])),
        anak: _l(j['anak']).map(AnakItem.fromJson).toList(),
      );
}

class DetailAnak {
  final Map<String, dynamic> anak;
  final Map<String, dynamic> keluarga;
  final AnakItem ringkas;
  final List<TimbangRingkas> riwayat;

  const DetailAnak({
    required this.anak,
    required this.keluarga,
    required this.ringkas,
    required this.riwayat,
  });

  factory DetailAnak.fromJson(Map<String, dynamic> j) => DetailAnak(
        anak: _m(j['anak']),
        keluarga: _m(j['keluarga']),
        ringkas: AnakItem.fromJson(_m(j['ringkas'])),
        riwayat: _l(j['riwayat']).map(TimbangRingkas.fromJson).toList(),
      );
}

class AnakBerisiko {
  final AnakItem anak;
  final List<String> alasan;
  final int skor;
  final String tingkat; // tinggi | sedang

  const AnakBerisiko({required this.anak, required this.alasan, required this.skor, required this.tingkat});

  factory AnakBerisiko.fromJson(Map<String, dynamic> j) => AnakBerisiko(
        anak: AnakItem.fromJson(j),
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

class AnakService {
  /// [prefix] '/sekretaris', '/kader', atau '/bidan'.
  final String prefix;

  const AnakService(this.prefix);

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

  Future<DaftarAnak> daftar({String cari = '', bool semua = false}) async {
    try {
      final res = await ApiClient.dio.get(
        '$prefix/semua-anak',
        queryParameters: {if (cari.isNotEmpty) 'cari': cari, if (semua) 'semua': '1'},
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return DaftarAnak.fromJson(_data(res.data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Bidan: daftar anak berisiko (deteksi dini), urut dari risiko tertinggi.
  Future<DaftarBerisiko> berisiko() async {
    try {
      final res = await ApiClient.dio.get(
        '$prefix/anak-berisiko',
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return DaftarBerisiko.fromJson(_data(res.data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<DetailAnak> detail(String anakId) async {
    try {
      final res = await ApiClient.dio.get('$prefix/semua-anak/$anakId');
      return DetailAnak.fromJson(_data(res.data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }
}