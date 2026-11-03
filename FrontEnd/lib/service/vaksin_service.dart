import 'package:dio/dio.dart';

import '../core/api_client.dart';

// ============================================================================
// MODEL VAKSIN
//
// Jadwal imunisasi (master Kemenkes) berlaku untuk semua anak. Jadwal per anak
// dihitung server dari tanggal lahir + riwayat, lengkap dengan status:
//   sudah · jatuh_tempo · terlambat · belum_waktunya · menunggu · terlewat
// ============================================================================

String _s(dynamic v) => v == null ? '' : v.toString();
int _i(dynamic v) => v is int ? v : int.tryParse(_s(v)) ?? 0;
int? _iN(dynamic v) => v == null ? null : int.tryParse(_s(v));
bool _b(dynamic v) => v == true || _s(v) == 'true';
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

String _tglApi(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Status dosis vaksin pada jadwal anak.
class StatusVaksin {
  static const sudah = 'sudah';
  static const jatuhTempo = 'jatuh_tempo';
  static const terlambat = 'terlambat';
  static const belumWaktunya = 'belum_waktunya';
  static const menunggu = 'menunggu';
  static const terlewat = 'terlewat';
}

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
    final lahir = _tgl(tanggalLahir);
    if (lahir == null) return '-';
    return usiaDariLahir(lahir, DateTime.now());
  }
}

/// Usia anak: "5 hari", "7 bln", "1 th 3 bln".
String usiaDariLahir(DateTime lahir, DateTime pada) {
  int bulan = (pada.year - lahir.year) * 12 + (pada.month - lahir.month);
  if (pada.day < lahir.day) bulan--;
  if (bulan < 0) bulan = 0;
  if (bulan == 0) {
    final a = DateTime(lahir.year, lahir.month, lahir.day);
    final b = DateTime(pada.year, pada.month, pada.day);
    final h = b.difference(a).inDays;
    return '${h < 0 ? 0 : h} hari';
  }
  if (bulan < 12) return '$bulan bln';
  final th = bulan ~/ 12;
  final sisa = bulan % 12;
  return sisa == 0 ? '$th th' : '$th th $sisa bln';
}

class JenisVaksinInfo {
  final String id;
  final String kode;
  final String nama;
  final String penyakit;
  final String caraPemberian;
  final bool khususDaerah;

  const JenisVaksinInfo({
    required this.id,
    required this.kode,
    required this.nama,
    required this.penyakit,
    required this.caraPemberian,
    required this.khususDaerah,
  });

  factory JenisVaksinInfo.fromJson(Map<String, dynamic> j) => JenisVaksinInfo(
        id: _s(j['id']),
        kode: _s(j['kode']),
        nama: _s(j['nama']).isEmpty ? '-' : _s(j['nama']),
        penyakit: _s(j['penyakit']),
        caraPemberian: _s(j['cara_pemberian']),
        khususDaerah: _b(j['khusus_daerah']),
      );
}

/// Satu dosis pada jadwal imunisasi master.
class JadwalImunisasi {
  final String id;
  final JenisVaksinInfo jenis;
  final int dosisKe;
  final int jumlahDosis;
  final String kelompok; // dasar | lanjutan
  final int usiaMinBulan;
  final int usiaIdealBulan;
  final int? usiaMaksBulan;
  final int? jarakMinimalHari;
  final String keterangan;
  final String labelUsia;

  const JadwalImunisasi({
    required this.id,
    required this.jenis,
    required this.dosisKe,
    required this.jumlahDosis,
    required this.kelompok,
    required this.usiaMinBulan,
    required this.usiaIdealBulan,
    required this.usiaMaksBulan,
    required this.jarakMinimalHari,
    required this.keterangan,
    required this.labelUsia,
  });

  factory JadwalImunisasi.fromJson(Map<String, dynamic> j) => JadwalImunisasi(
        id: _s(j['id']),
        jenis: JenisVaksinInfo.fromJson(_m(j['jenis_vaksin'])),
        dosisKe: _i(j['dosis_ke']),
        jumlahDosis: _i(j['jumlah_dosis']),
        kelompok: _s(j['kelompok']),
        usiaMinBulan: _i(j['usia_min_bulan']),
        usiaIdealBulan: _i(j['usia_ideal_bulan']),
        usiaMaksBulan: _iN(j['usia_maks_bulan']),
        jarakMinimalHari: _iN(j['jarak_minimal_hari']),
        keterangan: _s(j['keterangan']),
        labelUsia: _s(j['label_usia']),
      );

  bool get lanjutan => kelompok == 'lanjutan';

  /// "Polio Tetes (OPV) · Dosis 2" atau tanpa dosis bila hanya satu dosis.
  String get namaDosis => jumlahDosis > 1 ? '${jenis.nama} · Dosis $dosisKe' : jenis.nama;

  String get kunci => '${jenis.id}|$dosisKe';
}

class RiwayatVaksin {
  final String id;
  final JenisVaksinInfo jenis;
  final int dosisKe;
  final DateTime? tanggal;
  final int usiaBulan;
  final String usiaTeks;
  final String tempat;
  final String kondisiAnak;
  final String catatan;
  final String namaPemberi;
  final bool dariPosyandu;

  const RiwayatVaksin({
    required this.id,
    required this.jenis,
    required this.dosisKe,
    required this.tanggal,
    required this.usiaBulan,
    required this.usiaTeks,
    required this.tempat,
    required this.kondisiAnak,
    required this.catatan,
    required this.namaPemberi,
    required this.dariPosyandu,
  });

  factory RiwayatVaksin.fromJson(Map<String, dynamic> j) => RiwayatVaksin(
        id: _s(j['id']),
        jenis: JenisVaksinInfo.fromJson(_m(j['jenis_vaksin'])),
        dosisKe: _i(j['dosis_ke']),
        tanggal: _tgl(j['tanggal_pemberian']),
        usiaBulan: _i(j['usia_bulan']),
        usiaTeks: _s(j['usia_teks']),
        tempat: _s(j['tempat']),
        kondisiAnak: _s(j['kondisi_anak']),
        catatan: _s(j['catatan']),
        namaPemberi: _s(j['nama_pemberi']),
        dariPosyandu: _b(j['dari_posyandu']),
      );
}

/// Satu dosis pada jadwal vaksin anak, lengkap dengan status.
class JadwalVaksinAnak {
  final JadwalImunisasi jadwal;
  final DateTime? tanggalJadwal;
  final String status;
  final String labelStatus;
  final bool opsional;
  final RiwayatVaksin? riwayat;

  const JadwalVaksinAnak({
    required this.jadwal,
    required this.tanggalJadwal,
    required this.status,
    required this.labelStatus,
    required this.opsional,
    required this.riwayat,
  });

  factory JadwalVaksinAnak.fromJson(Map<String, dynamic> j) => JadwalVaksinAnak(
        jadwal: JadwalImunisasi.fromJson(j),
        tanggalJadwal: _tgl(j['tanggal_jadwal']),
        status: _s(j['status']),
        labelStatus: _s(j['label_status']),
        opsional: _b(j['opsional']),
        riwayat: j['riwayat'] is Map ? RiwayatVaksin.fromJson(_m(j['riwayat'])) : null,
      );

  bool get sudah => status == StatusVaksin.sudah;

  /// Boleh diberikan hari ini (sesuai usia dan urutan dosis).
  bool get bisaDiberikan =>
      status == StatusVaksin.jatuhTempo || status == StatusVaksin.terlambat;
}

class SuplemenRiwayat {
  final String id;
  final String nama;
  final String dosis;
  final int jumlah;
  final String satuan;
  final String keterangan;
  final DateTime? tanggal;
  final String usiaTeks;
  final String catatan;
  final String namaPemberi;

  const SuplemenRiwayat({
    required this.id,
    required this.nama,
    required this.dosis,
    required this.jumlah,
    required this.satuan,
    required this.keterangan,
    required this.tanggal,
    required this.usiaTeks,
    required this.catatan,
    required this.namaPemberi,
  });

  factory SuplemenRiwayat.fromJson(Map<String, dynamic> j) => SuplemenRiwayat(
        id: _s(j['id']),
        nama: namaSuplemen(_s(j['nama'])),
        dosis: _s(j['dosis']),
        jumlah: _i(j['jumlah']),
        satuan: _s(j['satuan']),
        keterangan: _s(j['keterangan']),
        tanggal: _tgl(j['tanggal']),
        usiaTeks: _s(j['usia_teks']),
        catatan: _s(j['catatan']),
        namaPemberi: _s(j['nama_pemberi']),
      );

  String get ringkasDosis {
    if (keterangan.isNotEmpty) return keterangan;
    final b = <String>[
      if (dosis.isNotEmpty) dosis,
      if (jumlah > 0) '$jumlah $satuan'.trim(),
    ];
    return b.join(' · ');
  }
}

/// Nama suplemen dari data lama (kode) menjadi nama yang mudah dibaca.
String namaSuplemen(String jenis) {
  switch (jenis) {
    case 'vitamin_a':
      return 'Vitamin A';
    case 'obat_cacing':
      return 'Obat Cacing';
    case 'pmt':
      return 'PMT';
  }
  return jenis.isEmpty ? '-' : jenis;
}

class RingkasanVaksin {
  final int totalDosis;
  final int sudah;
  final int jatuhTempo;
  final int terlambat;
  final int terlewat;
  final int persen;
  final bool dasarLengkap;
  final bool lanjutanLengkap;

  const RingkasanVaksin({
    required this.totalDosis,
    required this.sudah,
    required this.jatuhTempo,
    required this.terlambat,
    required this.terlewat,
    required this.persen,
    required this.dasarLengkap,
    required this.lanjutanLengkap,
  });

  factory RingkasanVaksin.fromJson(Map<String, dynamic> j) => RingkasanVaksin(
        totalDosis: _i(j['total_dosis']),
        sudah: _i(j['sudah']),
        jatuhTempo: _i(j['jatuh_tempo']),
        terlambat: _i(j['terlambat']),
        terlewat: _i(j['terlewat']),
        persen: _i(j['persen']),
        dasarLengkap: _b(j['dasar_lengkap']),
        lanjutanLengkap: _b(j['lanjutan_lengkap']),
      );
}

class AnakVaksinInfo {
  final String id;
  final String nama;
  final String jenisKelamin;
  final DateTime? tanggalLahir;
  final int usiaBulan;
  final String usiaTeks;

  const AnakVaksinInfo({
    required this.id,
    required this.nama,
    required this.jenisKelamin,
    required this.tanggalLahir,
    required this.usiaBulan,
    required this.usiaTeks,
  });

  factory AnakVaksinInfo.fromJson(Map<String, dynamic> j) => AnakVaksinInfo(
        id: _s(j['id']),
        nama: _s(j['nama']),
        jenisKelamin: _s(j['jenis_kelamin']),
        tanggalLahir: _tgl(j['tanggal_lahir']),
        usiaBulan: _i(j['usia_bulan']),
        usiaTeks: _s(j['usia_teks']),
      );
}

/// Kartu vaksin anak: jadwal + status, riwayat vaksin, riwayat suplemen.
class KartuVaksin {
  final AnakVaksinInfo anak;
  final RingkasanVaksin ringkasan;
  final List<JadwalVaksinAnak> jadwal;
  final List<RiwayatVaksin> riwayat;
  final List<SuplemenRiwayat> suplemen;

  const KartuVaksin({
    required this.anak,
    required this.ringkasan,
    required this.jadwal,
    required this.riwayat,
    required this.suplemen,
  });

  factory KartuVaksin.fromJson(Map<String, dynamic> j) => KartuVaksin(
        anak: AnakVaksinInfo.fromJson(_m(j['anak'])),
        ringkasan: RingkasanVaksin.fromJson(_m(j['ringkasan'])),
        jadwal: _l(j['jadwal']).map(JadwalVaksinAnak.fromJson).toList(),
        riwayat: _l(j['riwayat']).map(RiwayatVaksin.fromJson).toList(),
        suplemen: _l(j['suplemen']).map(SuplemenRiwayat.fromJson).toList(),
      );

  /// Dosis yang boleh diberikan hari ini.
  List<JadwalVaksinAnak> get dianjurkan => jadwal.where((e) => e.bisaDiberikan).toList();
}

class StatistikJenisVaksin {
  final JenisVaksinInfo jenis;
  final int jumlahDosis;
  final int jumlahAnak;
  final int dosisPerAnak;

  const StatistikJenisVaksin({
    required this.jenis,
    required this.jumlahDosis,
    required this.jumlahAnak,
    required this.dosisPerAnak,
  });

  factory StatistikJenisVaksin.fromJson(Map<String, dynamic> j) => StatistikJenisVaksin(
        jenis: JenisVaksinInfo.fromJson(_m(j['jenis_vaksin'])),
        jumlahDosis: _i(j['jumlah_dosis']),
        jumlahAnak: _i(j['jumlah_anak']),
        dosisPerAnak: _i(j['dosis_per_anak']),
      );
}

class StatistikVaksin {
  final String posyandu;
  final int jumlahBalita;
  final int totalDiberikan;
  final int totalAnakDivaksin;
  final int anakJatuhTempo;
  final int anakTerlambat;
  final int anakDasarLengkap;
  final int anakUsia12Bulan;
  final List<StatistikJenisVaksin> jenis;

  const StatistikVaksin({
    required this.posyandu,
    required this.jumlahBalita,
    required this.totalDiberikan,
    required this.totalAnakDivaksin,
    required this.anakJatuhTempo,
    required this.anakTerlambat,
    required this.anakDasarLengkap,
    required this.anakUsia12Bulan,
    required this.jenis,
  });

  factory StatistikVaksin.fromJson(Map<String, dynamic> j) => StatistikVaksin(
        posyandu: _s(j['posyandu']),
        jumlahBalita: _i(j['jumlah_balita']),
        totalDiberikan: _i(j['total_diberikan']),
        totalAnakDivaksin: _i(j['total_anak_divaksin']),
        anakJatuhTempo: _i(j['anak_jatuh_tempo']),
        anakTerlambat: _i(j['anak_terlambat']),
        anakDasarLengkap: _i(j['anak_dasar_lengkap']),
        anakUsia12Bulan: _i(j['anak_usia_12_bulan']),
        jenis: _l(j['jenis']).map(StatistikJenisVaksin.fromJson).toList(),
      );

  /// Persentase Imunisasi Dasar Lengkap pada anak usia >= 12 bulan.
  int get persenIdl => anakUsia12Bulan == 0 ? 0 : (anakDasarLengkap * 100 ~/ anakUsia12Bulan);
}

// ============================================================================
// SERVICE
// ============================================================================

class VaksinService {
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

  List<AnakRingkas> _parseAnak(dynamic list) => _l(list).map(AnakRingkas.fromJson).toList();

  // ---------------------------------------------------------------- anak

  /// Orang tua: daftar anak pada keluarganya sendiri.
  Future<List<AnakRingkas>> anakSaya() async {
    try {
      final res = await ApiClient.dio.get('/keluarga/saya');
      final data = _data(res.data);
      return _parseAnak(data is Map ? data['anak'] : null);
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Kader: cari anak berdasarkan nama atau NIK (hanya posyandu kader).
  Future<List<AnakRingkas>> cariAnak(String kata) async {
    try {
      final res = await ApiClient.dio.get('/kader/anak', queryParameters: {'cari': kata});
      return _parseAnak(_data(res.data));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // ---------------------------------------------------------------- jadwal & kartu

  /// Jadwal imunisasi rutin (master, sama untuk semua anak).
  Future<List<JadwalImunisasi>> jadwalMaster() async {
    try {
      final res = await ApiClient.dio.get('/vaksin/jadwal');
      return _l(_data(res.data)).map(JadwalImunisasi.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  /// Kartu vaksin anak: jadwal dengan status, riwayat vaksin, dan suplemen.
  Future<KartuVaksin> kartuAnak(String anakId) async {
    try {
      final res = await ApiClient.dio.get('/vaksin/anak/$anakId');
      return KartuVaksin.fromJson(_m(_data(res.data)));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // ---------------------------------------------------------------- bidan

  /// Catat vaksin yang diberikan di luar sesi posyandu (puskesmas, bidan praktik, RS).
  Future<void> catatRiwayat({
    required String anakId,
    required String jenisVaksinId,
    required int dosisKe,
    required DateTime tanggal,
    String tempat = '',
    String kondisiAnak = '',
    String catatan = '',
  }) async {
    try {
      await ApiClient.dio.post('/bidan/vaksin/riwayat', data: {
        'anak_id': anakId,
        'jenis_vaksin_id': jenisVaksinId,
        'dosis_ke': dosisKe,
        'tanggal_pemberian': _tglApi(tanggal),
        'tempat': tempat,
        'kondisi_anak': kondisiAnak,
        'catatan': catatan,
      });
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  Future<void> hapusRiwayat(String id) async {
    try {
      await ApiClient.dio.delete('/bidan/vaksin/riwayat/$id');
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }

  // ---------------------------------------------------------------- sekretaris

  Future<StatistikVaksin> statistik() async {
    try {
      final res = await ApiClient.dio.get('/sekretaris/vaksin/statistik');
      return StatistikVaksin.fromJson(_m(_data(res.data)));
    } on DioException catch (e) {
      throw Exception(_pesanError(e));
    }
  }
}