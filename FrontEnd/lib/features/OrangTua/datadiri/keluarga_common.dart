import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class DataAnak {
  String? id; // UUID
  String kodeQr;
  String nama, nik, tglLahir, jk, beratLahir, panjangLahir; // tglLahir: dd/mm/yyyy

  DataAnak({
    this.id,
    this.kodeQr = '',
    this.nama = '',
    this.nik = '',
    this.tglLahir = '',
    this.jk = '',
    this.beratLahir = '',
    this.panjangLahir = '',
  });

  factory DataAnak.fromApi(Map<String, dynamic> j) => DataAnak(
        id: j['id']?.toString(),
        kodeQr: j['kode_qr']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        nik: j['nik']?.toString() ?? '',
        tglLahir: dariApi(j['tanggal_lahir']),
        jk: j['jenis_kelamin']?.toString() ?? '',
        beratLahir: angka(j['berat_lahir_kg']),
        panjangLahir: angka(j['panjang_lahir_cm']),
      );
}

class DataKeluarga {
  // Ibu / wali
  bool tanpaIbu;
  String namaIbu, nikIbu, tglLahirIbu, noHpIbu, pekerjaanIbu;
  String alamat, rt, rw;
  // Suami / ayah
  bool tanpaAyah;
  String namaAyah, nikAyah, tglLahirAyah, noHpAyah, pekerjaanAyah;
  // Anak (dikelola di halaman terpisah)
  List<DataAnak> anak;

  DataKeluarga({
    this.tanpaIbu = false,
    this.namaIbu = '',
    this.nikIbu = '',
    this.tglLahirIbu = '',
    this.noHpIbu = '',
    this.pekerjaanIbu = '',
    this.alamat = '',
    this.rt = '',
    this.rw = '',
    this.tanpaAyah = false,
    this.namaAyah = '',
    this.nikAyah = '',
    this.tglLahirAyah = '',
    this.noHpAyah = '',
    this.pekerjaanAyah = '',
    List<DataAnak>? anak,
  }) : anak = anak ?? [];

  bool get ibuLengkap =>
      tanpaIbu ||
      (tglLahirIbu.isNotEmpty && alamat.trim().isNotEmpty && rw.trim().isNotEmpty);

  bool get ayahLengkap => tanpaAyah || namaAyah.trim().isNotEmpty;
  bool get anakLengkap => anak.isNotEmpty;

  // Kelengkapan data orang tua (ibu + ayah). Data anak terpisah.
  int get langkahSelesai => (ibuLengkap ? 1 : 0) + (ayahLengkap ? 1 : 0);
  bool get lengkap => langkahSelesai == 2;
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------
final Options opsiApi = Options(receiveTimeout: const Duration(seconds: 15));

Map<String, dynamic>? _peta(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

class KeluargaApi {
  /// GET /keluarga -> { data: { keluarga, ibu, ayah, anak, status } }
  static Future<Map<String, dynamic>> ambil() async {
    final r = await ApiClient.dio.get('/keluarga', options: opsiApi);
    return Map<String, dynamic>.from(r.data['data'] as Map);
  }

  static DataKeluarga keModel(Map<String, dynamic> data, {Map<String, dynamic>? user}) {
    final k = _peta(data['keluarga']);
    final ibu = _peta(data['ibu']);
    final ayah = _peta(data['ayah']);
    final anak = ((data['anak'] as List?) ?? [])
        .map((e) => DataAnak.fromApi(Map<String, dynamic>.from(e as Map)))
        .toList();
    return DataKeluarga(
      namaIbu: (user?['nama'] ?? ibu?['nama'] ?? '').toString(),
      nikIbu: (user?['nik'] ?? ibu?['nik'] ?? '').toString(),
      noHpIbu: (user?['no_hp'] ?? ibu?['no_hp'] ?? '').toString(),
      tglLahirIbu: dariApi(ibu?['tanggal_lahir']),
      pekerjaanIbu: (ibu?['pekerjaan'] ?? '').toString(),
      alamat: (k?['alamat'] ?? '').toString(),
      rt: (k?['rt'] ?? '').toString(),
      rw: (k?['rw'] ?? '').toString(),
      tanpaAyah: k?['tanpa_ayah'] == true,
      namaAyah: (ayah?['nama'] ?? '').toString(),
      nikAyah: (ayah?['nik'] ?? '').toString(),
      tglLahirAyah: dariApi(ayah?['tanggal_lahir']),
      noHpAyah: (ayah?['no_hp'] ?? '').toString(),
      pekerjaanAyah: (ayah?['pekerjaan'] ?? '').toString(),
      anak: anak,
    );
  }
}

String pesanError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server tidak merespons. Periksa koneksi dan alamat server.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server.';
      default:
        return 'Terjadi kesalahan (kode ${e.response?.statusCode ?? '-'}).';
    }
  }
  return 'Terjadi kesalahan: $e';
}

// ---------------------------------------------------------------------------
// HELPER
// ---------------------------------------------------------------------------
DateTime? parseTgl(String s) {
  final p = s.split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

String fmtTgl(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// "2026-10-01T00:00:00Z" -> "01/10/2026"
String dariApi(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  if (s.length < 10) return '';
  final p = s.substring(0, 10).split('-');
  if (p.length != 3) return '';
  return '${p[2]}/${p[1]}/${p[0]}';
}

// "01/10/2026" -> "2026-10-01"
String keApi(String tgl) {
  final d = parseTgl(tgl);
  if (d == null) return '';
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String angka(dynamic v) {
  if (v == null) return '';
  final n = double.tryParse(v.toString());
  if (n == null) return '';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

double? keDouble(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

String usiaAnak(String tgl) {
  final l = parseTgl(tgl);
  if (l == null) return '-';
  final n = DateTime.now();
  var bln = (n.year - l.year) * 12 + (n.month - l.month);
  if (n.day < l.day) bln--;
  if (bln < 0) bln = 0;
  return bln >= 12 ? '${bln ~/ 12} th ${bln % 12} bln' : '$bln bln';
}

InputDecoration dekorInput(String label, {String? hint, IconData? icon, Widget? suffix, String? counter}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: counter,
    prefixIcon: icon == null ? null : Icon(icon, color: Colors.grey.shade600),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.isiField,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

Widget jarak() => const SizedBox(height: 12);

void snackDi(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}