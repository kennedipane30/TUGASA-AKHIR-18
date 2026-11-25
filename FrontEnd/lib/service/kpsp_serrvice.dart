import 'package:dio/dio.dart';

import '../core/config/api_client.dart';

/// KPSP (Kuesioner Pra Skrining Perkembangan): skrining perkembangan anak yang
/// diisi bidan saat sesi posyandu, 10 pertanyaan per kelompok umur.
///
/// Penilaian mengikuti pedoman SDIDTK Kemenkes dan dihitung di server:
///
///   jumlah jawaban "Ya" 9-10  -> Sesuai (S)
///   jumlah jawaban "Ya" 7-8   -> Meragukan (M)
///   jumlah jawaban "Ya" <= 6  -> Kemungkinan ada Penyimpangan (P)
class KpspService {
  /// Mengambil lembar KPSP yang sesuai untuk anak berumur [usiaBulan].
  /// Kelompok umurnya ditentukan server, aplikasi cukup mengirim umur anak.
  ///
  /// Mengembalikan null bila gagal, supaya halaman catatan bidan tetap dapat
  /// dibuka walaupun lembar KPSP tidak dapat diambil.
  Future<LembarKpsp?> lembar(int usiaBulan) async {
    try {
      final r = await ApiClient.dio.get(
        '/bidan/kpsp/lembar',
        queryParameters: {'usia_bulan': usiaBulan},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      if (d is! Map) return null;
      return LembarKpsp.fromJson(Map<String, dynamic>.from(d));
    } catch (_) {
      return null;
    }
  }
}

/// Satu lembar KPSP: kelompok umur beserta 10 pertanyaannya.
class LembarKpsp {
  /// Kelompok umur lembar ini: 3, 6, 9, 12, 15, 18, 21, 24, 30, 36, 42, 48,
  /// 54, 60, 66, atau 72 bulan.
  final int usiaBulan;

  /// Umur anak sebenarnya dalam bulan.
  final int usiaAnakBulan;

  /// false bila anak di luar jangkauan KPSP (umur < 3 atau > 72 bulan).
  /// Kartu KPSP disembunyikan bila bernilai false.
  final bool berlaku;

  /// 10 pertanyaan terurut nomor 1-10.
  final List<PertanyaanKpsp> pertanyaan;

  const LembarKpsp({
    required this.usiaBulan,
    required this.usiaAnakBulan,
    required this.berlaku,
    required this.pertanyaan,
  });

  factory LembarKpsp.fromJson(Map<String, dynamic> j) {
    final list = <PertanyaanKpsp>[];
    final p = j['pertanyaan'];
    if (p is List) {
      for (final e in p) {
        if (e is Map) list.add(PertanyaanKpsp.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return LembarKpsp(
      usiaBulan: _int(j['usia_bulan']),
      usiaAnakBulan: _int(j['usia_anak_bulan']),
      berlaku: j['berlaku'] == true,
      pertanyaan: list,
    );
  }

  /// Lembar siap dipakai hanya bila berlaku dan pertanyaannya lengkap 10 butir.
  bool get siap => berlaku && pertanyaan.length == 10;
}

/// Satu pertanyaan KPSP.
class PertanyaanKpsp {
  final int nomor;

  /// Aspek perkembangan: gerak_kasar, gerak_halus, bicara, atau sosialisasi.
  final String aspek;

  final String pertanyaan;

  const PertanyaanKpsp({
    required this.nomor,
    required this.aspek,
    required this.pertanyaan,
  });

  factory PertanyaanKpsp.fromJson(Map<String, dynamic> j) => PertanyaanKpsp(
        nomor: _int(j['nomor']),
        aspek: j['aspek']?.toString() ?? '',
        pertanyaan: j['pertanyaan']?.toString() ?? '',
      );

  /// Nama aspek untuk ditampilkan di layar.
  String get labelAspek => labelAspekKpsp(aspek);
}

/// Hasil KPSP yang sudah tersimpan pada satu kunjungan.
class HasilKpsp {
  final int usiaBulan;
  final int jumlahYa;

  /// sesuai | meragukan | penyimpangan
  final String hasil;

  final String catatan;

  /// Jawaban per nomor pertanyaan: nomor -> true bila "Ya".
  final Map<int, bool> jawaban;

  const HasilKpsp({
    required this.usiaBulan,
    required this.jumlahYa,
    required this.hasil,
    required this.catatan,
    required this.jawaban,
  });

  factory HasilKpsp.fromJson(Map<String, dynamic> j) {
    final map = <int, bool>{};
    final jw = j['jawaban'];
    if (jw is List) {
      for (final e in jw) {
        if (e is Map) map[_int(e['nomor'])] = e['ya'] == true;
      }
    }
    return HasilKpsp(
      usiaBulan: _int(j['usia_bulan']),
      jumlahYa: _int(j['jumlah_ya']),
      hasil: j['hasil']?.toString() ?? '',
      catatan: j['catatan']?.toString() ?? '',
      jawaban: map,
    );
  }
}

// ---------------------------------------------------------------------------
// Pembantu tampilan
// ---------------------------------------------------------------------------

const kpspSesuai = 'sesuai';
const kpspMeragukan = 'meragukan';
const kpspPenyimpangan = 'penyimpangan';

/// Menghitung hasil S/M/P dari jumlah jawaban "Ya".
/// Dipakai untuk pratinjau di layar; nilai yang disimpan tetap dihitung server.
String hitungHasilKpsp(int jumlahYa) {
  if (jumlahYa >= 9) return kpspSesuai;
  if (jumlahYa >= 7) return kpspMeragukan;
  return kpspPenyimpangan;
}

/// Nama hasil KPSP untuk ditampilkan.
String labelHasilKpsp(String hasil) {
  switch (hasil) {
    case kpspSesuai:
      return 'Sesuai (S)';
    case kpspMeragukan:
      return 'Meragukan (M)';
    case kpspPenyimpangan:
      return 'Kemungkinan ada penyimpangan (P)';
  }
  return '-';
}

/// Tindak lanjut yang dianjurkan sesuai hasil skrining.
String saranHasilKpsp(String hasil) {
  switch (hasil) {
    case kpspSesuai:
      return 'Perkembangan anak sesuai umur. Lanjutkan stimulasi dan skrining berikutnya sesuai jadwal.';
    case kpspMeragukan:
      return 'Beri stimulasi lebih sering, lalu ulangi KPSP dua minggu lagi.';
    case kpspPenyimpangan:
      return 'Rujuk ke puskesmas atau rumah sakit untuk pemeriksaan lebih lanjut.';
  }
  return '';
}

/// Nama aspek perkembangan untuk ditampilkan.
String labelAspekKpsp(String aspek) {
  switch (aspek) {
    case 'gerak_kasar':
      return 'Gerak kasar';
    case 'gerak_halus':
      return 'Gerak halus';
    case 'bicara':
      return 'Bicara & bahasa';
    case 'sosialisasi':
      return 'Sosialisasi & kemandirian';
  }
  return aspek;
}

int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;