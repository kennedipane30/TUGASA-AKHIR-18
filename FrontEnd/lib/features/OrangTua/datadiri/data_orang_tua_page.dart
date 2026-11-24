import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/no_hp.dart';
import '../../auth/auth_provider.dart';

// ---------------------------------------------------------------------------
// WARNA & HEADER (dipakai bersama oleh halaman keluarga & anak)
// ---------------------------------------------------------------------------
const kHijauHeader = Color(0xFF065F46);
const kHijauTua = Color(0xFF0B3D2E);
const kHijauGelap = Color(0xFF14634A);
const kHijauAksen = Color(0xFF1F7A5C);
const kHijauTerang = Color(0xFF2BB59A);
const kOranye2 = Color(0xFFF97316);

/// Garis tepi field & kotak di dalam kartu: hitam lembut.
const kGarisKartu = Color(0xFFB8BEC6);
const kGarisInput = Color(0xFFB8BEC6);

const kTeksGelap = Color(0xFF1F2937);

/// Warna aksen kartu: hijau lembut senada header.
const kAksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const kBayangan = AppColors.bayanganKartu;

BoxDecoration dekorKartuKeluarga({Color warna = Colors.white}) => BoxDecoration(
      color: warna,
      borderRadius: BorderRadius.circular(16),
      boxShadow: kBayangan,
    );

/// Kepala kartu: judul kapital tebal di kiri, keterangan di kanan, garis aksen di bawah.
Widget kepalaKeluarga(String judul, {String? kanan, Color warnaKanan = kTeksGelap, Widget? aksi}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                judul.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: kTeksGelap,
                ),
              ),
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(kanan,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: warnaKanan)),
            ],
            if (aksi != null) aksi,
          ],
        ),
      ),
      Container(height: 3, color: kAksen),
    ],
  );
}

/// Baris "Label : nilai" (hitam tebal, nilai lanjut ke samping).
Widget infoKeluarga(String label, String nilai, {double lebar = 120}) {
  const gaya = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.35, color: kTeksGelap);
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: lebar, child: Text(label, style: gaya)),
        const Text(': ', style: gaya),
        Expanded(child: Text(nilai.isEmpty ? '-' : nilai, style: gaya)),
      ],
    ),
  );
}

/// Tautan kecil bergaris bawah (mis. "Ubah", "Hapus", "Buka").
Widget tautanKeluarga(String teks, {Color warna = kAksen}) => Text(
      teks,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: warna,
        decoration: TextDecoration.underline,
        decorationColor: warna,
      ),
    );

/// Judul lembar bawah (form): kapital + garis aksen.
Widget judulLembarKeluarga(String teks, {String? sub}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(teks.toUpperCase(),
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: kTeksGelap)),
        const SizedBox(height: 8),
        Container(height: 3, color: kAksen),
        if (sub != null) ...[
          const SizedBox(height: 8),
          Text(sub, style: const TextStyle(fontSize: 15.5, height: 1.4, color: AppColors.teksRedup)),
        ],
      ],
    );

Widget _isiTombolKeluarga(String label, IconData? ikon, bool memuat) => memuat
    ? const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      )
    : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[Icon(ikon, size: 20), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );

/// Tombol hijau penuh (tinggi 50, sudut 14).
Widget tombolHijauKeluarga(String label,
    {IconData? ikon, VoidCallback? onPressed, bool memuat = false}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: memuat ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kHijauHeader,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF7FAF9F),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
      ),
      child: _isiTombolKeluarga(label, ikon, memuat),
    ),
  );
}

/// Tombol bergaris (tinggi 50, sudut 14). Merah untuk Batal / Hapus.
Widget tombolGarisKeluarga(String label,
    {IconData? ikon, VoidCallback? onPressed, Color warna = kHijauHeader}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: warna,
        backgroundColor: Colors.white,
        side: BorderSide(color: warna, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
      ),
      child: _isiTombolKeluarga(label, ikon, false),
    ),
  );
}

/// Judul header (gaya teks sama dengan halaman lain).
Widget _judulTebal(String teks) {
  return Text(
    teks,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: Colors.white,
    ),
  );
}

class HeaderKeluarga extends StatelessWidget {
  final String judul;
  final bool sinkron;

  const HeaderKeluarga({super.key, required this.judul, this.sinkron = true});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        width: double.infinity,
        color: kHijauHeader,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: _judulTebal(judul),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child:
                          Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class DataAnak {
  String? id; // UUID
  String kodeQr;
  String nama, nik, tglLahir, jk, beratLahir, panjangLahir; // tglLahir: dd/mm/yyyy
  // belum_ditanya | belum_pernah | dilaporkan | perlu_ditanyakan | dikonfirmasi
  String statusRiwayatVaksin;

  /// aktif | arsip (diarsipkan kader: pindah / meninggal, atau otomatis: lulus balita)
  String status;
  String tglArsip; // dd/mm/yyyy
  String alasanArsip;

  bool get diarsipkan => status == 'arsip';

  DataAnak({
    this.id,
    this.kodeQr = '',
    this.nama = '',
    this.nik = '',
    this.tglLahir = '',
    this.jk = '',
    this.beratLahir = '',
    this.panjangLahir = '',
    this.statusRiwayatVaksin = 'belum_ditanya',
    this.status = 'aktif',
    this.tglArsip = '',
    this.alasanArsip = '',
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
        statusRiwayatVaksin: (j['status_riwayat_vaksin']?.toString() ?? '').isEmpty
            ? 'belum_ditanya'
            : j['status_riwayat_vaksin'].toString(),
        status: j['status']?.toString() ?? 'aktif',
        tglArsip: dariApi(j['tanggal_arsip']),
        alasanArsip: j['alasan_arsip']?.toString() ?? '',
      );
}

class DataKeluarga {
  // Ibu / wali (pemilik akun)
  String namaIbu, nikIbu, tglLahirIbu, noHpIbu, pekerjaanIbu;
  String alamat, rt, rw;
  // Suami / ayah
  bool tanpaAyah;
  String namaAyah, nikAyah, tglLahirAyah, noHpAyah, pekerjaanAyah;
  // Anak (dikelola di halaman terpisah)
  List<DataAnak> anak;

  DataKeluarga({
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
      tglLahirIbu.isNotEmpty && alamat.trim().isNotEmpty && rw.trim().isNotEmpty;

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

  static DataKeluarga keModel(Map<String, dynamic> data,
      {Map<String, dynamic>? user}) {
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

InputDecoration dekorInput(String label,
    {String? hint, IconData? icon, Widget? suffix, String? counter}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: counter,
    prefixIcon: icon == null ? null : Icon(icon, color: kAksen),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kGarisInput, width: 1.2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kGarisInput, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kHijauHeader, width: 1.6),
    ),
  );
}

Widget jarak() => const SizedBox(height: 12);

void snackDi(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

// ---------------------------------------------------------------------------
// WIDGET BERSAMA
// ---------------------------------------------------------------------------
InputDecoration dekorKeluarga(String hint,
    {IconData? icon, String? counter, bool terkunci = false}) {
  OutlineInputBorder b(Color c, [double w = 1.2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 15.5, color: Colors.black38),
    prefixIcon: icon == null ? null : Icon(icon, size: 22, color: kAksen),
    counterText: counter ?? '',
    filled: true,
    fillColor: terkunci ? const Color(0xFFF1F5F3) : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(kGarisInput),
    enabledBorder: b(kGarisInput),
    disabledBorder: b(kGarisInput),
    focusedBorder: b(kHijauHeader, 1.6),
    errorBorder: b(AppColors.merah),
    focusedErrorBorder: b(AppColors.merah),
  );
}

Widget labelKeluarga(String teks, {String? ket}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: teks,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: kTeksGelap)),
        if (ket != null)
          TextSpan(
              text: ' $ket',
              style: const TextStyle(fontSize: 14.5, color: AppColors.teksRedup)),
      ])),
    );

Widget gapKeluarga() => const SizedBox(height: 14);

Widget centangKeluarga(bool nilai, String teks, ValueChanged<bool?> onChanged) =>
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: kHijauHeader,
      value: nilai,
      title: Text(teks,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: kTeksGelap)),
      onChanged: onChanged,
    );

/// Status kelengkapan (teks biasa, tanpa pill).
Widget pillStatusKeluarga(bool lengkap) => Text(lengkap ? 'Lengkap' : 'Belum lengkap',
    style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: lengkap ? kHijauHeader : AppColors.kuning));

/// Kartu putih berbayang. Bila [title] ada: kepala kapital + garis aksen.
/// [icon] dipertahankan agar pemanggil lama tetap jalan, tetapi tidak ditampilkan.
class KartuKeluarga extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;
  final Widget child;

  const KartuKeluarga({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: dekorKartuKeluarga(warna: color ?? Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) kepalaKeluarga(title!, aksi: trailing),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BAGIAN IBU
// ---------------------------------------------------------------------------
class BagianIbu extends StatelessWidget {
  final DataKeluarga data;
  final TextEditingController nama, nik, tgl, hp, kerja, alamat, rt, rw;
  final VoidCallback onPilihTanggal;

  const BagianIbu({
    super.key,
    required this.data,
    required this.nama,
    required this.nik,
    required this.tgl,
    required this.hp,
    required this.kerja,
    required this.alamat,
    required this.rt,
    required this.rw,
    required this.onPilihTanggal,
  });

  @override
  Widget build(BuildContext context) {
    return KartuKeluarga(
      title: 'Data Diri Ibu / Wali',
      trailing: pillStatusKeluarga(data.ibuLengkap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelKeluarga('Nama lengkap', ket: '(dari akun)'),
          TextFormField(
            controller: nama,
            readOnly: true,
            decoration:
                dekorKeluarga('Nama', icon: Icons.person_outline, terkunci: true),
          ),
          gapKeluarga(),
          labelKeluarga('NIK', ket: '(dari akun)'),
          TextFormField(
            controller: nik,
            readOnly: true,
            decoration:
                dekorKeluarga('NIK', icon: Icons.badge_outlined, terkunci: true),
          ),
          gapKeluarga(),
          labelKeluarga('Tanggal Lahir'),
          TextFormField(
            controller: tgl,
            readOnly: true,
            onTap: onPilihTanggal,
            decoration:
                dekorKeluarga('dd/mm/yyyy', icon: Icons.calendar_month_outlined),
          ),
          gapKeluarga(),
          labelKeluarga('No. WhatsApp', ket: '(dari akun)'),
          TextFormField(
            controller: hp,
            readOnly: true,
            decoration: dekorKeluarga('No. WhatsApp',
                icon: Icons.phone_outlined, terkunci: true),
          ),
          gapKeluarga(),
          labelKeluarga('Pekerjaan', ket: '(opsional)'),
          TextFormField(
            controller: kerja,
            textCapitalization: TextCapitalization.words,
            decoration:
                dekorKeluarga('Pekerjaan (opsional)', icon: Icons.work_outline),
          ),
          gapKeluarga(),
          labelKeluarga('Alamat Tempat Tinggal'),
          TextFormField(
            controller: alamat,
            maxLines: 3,
            decoration: dekorKeluarga('Alamat tempat tinggal lengkap...',
                icon: Icons.home_outlined),
          ),
          gapKeluarga(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelKeluarga('RT'),
                    TextFormField(
                      controller: rt,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 3,
                      decoration: dekorKeluarga('RT', icon: Icons.signpost_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelKeluarga('RW'),
                    TextFormField(
                      controller: rw,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 3,
                      decoration: dekorKeluarga('RW', icon: Icons.signpost_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BAGIAN AYAH
// ---------------------------------------------------------------------------
class BagianAyah extends StatelessWidget {
  final DataKeluarga data;
  final bool tanpaAyah;
  final ValueChanged<bool?> onTanpaAyah;
  final TextEditingController nama, nik, tgl, hp, kerja;
  final VoidCallback onPilihTanggal;

  const BagianAyah({
    super.key,
    required this.data,
    required this.tanpaAyah,
    required this.onTanpaAyah,
    required this.nama,
    required this.nik,
    required this.tgl,
    required this.hp,
    required this.kerja,
    required this.onPilihTanggal,
  });

  @override
  Widget build(BuildContext context) {
    return KartuKeluarga(
      title: 'Data Suami / Ayah',
      trailing: pillStatusKeluarga(data.ayahLengkap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          centangKeluarga(
              tanpaAyah, 'Tidak ada data suami / ayah yang diisi', onTanpaAyah),
          if (!tanpaAyah) ...[
            labelKeluarga('Nama lengkap'),
            TextFormField(
              controller: nama,
              textCapitalization: TextCapitalization.words,
              decoration: dekorKeluarga('Nama lengkap', icon: Icons.person_outline),
            ),
            gapKeluarga(),
            labelKeluarga('NIK', ket: '(opsional)'),
            TextFormField(
              controller: nik,
              keyboardType: TextInputType.number,
              maxLength: 16,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: dekorKeluarga('16 digit NIK',
                  icon: Icons.badge_outlined, counter: '${nik.text.length}/16'),
              validator: (v) => (v != null && v.isNotEmpty && v.length != 16)
                  ? 'NIK harus 16 digit'
                  : null,
            ),
            gapKeluarga(),
            labelKeluarga('Tanggal Lahir'),
            TextFormField(
              controller: tgl,
              readOnly: true,
              onTap: onPilihTanggal,
              decoration:
                  dekorKeluarga('dd/mm/yyyy', icon: Icons.calendar_month_outlined),
            ),
            gapKeluarga(),
            labelKeluarga('No. HP', ket: '(opsional)'),
            TextFormField(
              controller: hp,
              keyboardType: TextInputType.phone,
              inputFormatters: inputNoHp,
              decoration: denganAwalanNoHp(
                  dekorKeluarga('Contoh: $contohNoHp (opsional)', icon: Icons.phone_outlined)),
              validator: validasiNoHpOpsional,
            ),
            gapKeluarga(),
            labelKeluarga('Pekerjaan', ket: '(opsional)'),
            TextFormField(
              controller: kerja,
              textCapitalization: TextCapitalization.words,
              decoration:
                  dekorKeluarga('Pekerjaan (opsional)', icon: Icons.work_outline),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HALAMAN DATA ORANG TUA
// ---------------------------------------------------------------------------
class LengkapiKeluargaPage extends StatefulWidget {
  const LengkapiKeluargaPage({super.key});

  @override
  State<LengkapiKeluargaPage> createState() => _LengkapiKeluargaPageState();
}

class _LengkapiKeluargaPageState extends State<LengkapiKeluargaPage> {
  static const _judulHeader = 'Data Orang Tua';

  final _key = GlobalKey<FormState>();
  bool _memuat = true;
  bool _menyimpan = false;
  String? _gagal;

  final _namaIbu = TextEditingController();
  final _nikIbu = TextEditingController();
  final _tglIbu = TextEditingController();
  final _hpIbu = TextEditingController();
  final _kerjaIbu = TextEditingController();
  final _alamat = TextEditingController();
  final _rt = TextEditingController();
  final _rw = TextEditingController();

  bool _tanpaAyah = false;
  final _namaAyah = TextEditingController();
  final _nikAyah = TextEditingController();
  final _tglAyah = TextEditingController();
  final _hpAyah = TextEditingController();
  final _kerjaAyah = TextEditingController();

  late final List<TextEditingController> _semua = [
    _namaIbu, _nikIbu, _tglIbu, _hpIbu, _kerjaIbu, _alamat, _rt, _rw,
    _namaAyah, _nikAyah, _tglAyah, _hpAyah, _kerjaAyah,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _semua) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _muat();
  }

  @override
  void dispose() {
    for (final c in _semua) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    final user = context.read<AuthProvider>().user;
    try {
      final data = await KeluargaApi.ambil();
      final m = KeluargaApi.keModel(data,
          user: user == null ? null : Map<String, dynamic>.from(user));

      if (!mounted) return;

      _namaIbu.text = m.namaIbu;
      _nikIbu.text = m.nikIbu;
      _hpIbu.text = formatNoHp(m.noHpIbu); // hanya tampilan (dari akun)

      _tglIbu.text = m.tglLahirIbu;
      _kerjaIbu.text = m.pekerjaanIbu;
      _alamat.text = m.alamat;
      _rt.text = m.rt;
      _rw.text = m.rw;

      _tanpaAyah = m.tanpaAyah;
      _namaAyah.text = m.namaAyah;
      _nikAyah.text = m.nikAyah;
      _tglAyah.text = m.tglLahirAyah;
      _hpAyah.text = noHpKeIsian(m.noHpAyah);
      _kerjaAyah.text = m.pekerjaanAyah;

      setState(() {
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = pesanError(e);
        _memuat = false;
      });
    }
  }

  DataKeluarga _ambil() => DataKeluarga(
        namaIbu: _namaIbu.text.trim(),
        nikIbu: _nikIbu.text.trim(),
        tglLahirIbu: _tglIbu.text.trim(),
        noHpIbu: noHpKeServer(noHpKeIsian(_hpIbu.text)),
        pekerjaanIbu: _kerjaIbu.text.trim(),
        alamat: _alamat.text.trim(),
        rt: _rt.text.trim(),
        rw: _rw.text.trim(),
        tanpaAyah: _tanpaAyah,
        namaAyah: _namaAyah.text.trim(),
        nikAyah: _nikAyah.text.trim(),
        tglLahirAyah: _tglAyah.text.trim(),
        noHpAyah: noHpKeServer(_hpAyah.text),
        pekerjaanAyah: _kerjaAyah.text.trim(),
      );

  void _snack(String msg) {
    if (!mounted) return;
    snackDi(context, msg);
  }

  Future<void> _pilihTanggal(TextEditingController c,
      {int tahunMin = 90, int tahunMaks = 15}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: parseTgl(c.text) ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - tahunMin),
      lastDate: DateTime(now.year - tahunMaks, 12, 31),
    );
    if (d != null) c.text = fmtTgl(d);
  }

  Map<String, dynamic> _bodyProfil() => {
        'tgl_lahir_ibu': keApi(_tglIbu.text),
        'pekerjaan_ibu': _kerjaIbu.text.trim(),
        'alamat': _alamat.text.trim(),
        'rt': _rt.text.trim(),
        'rw': _rw.text.trim(),
        'tanpa_ayah': _tanpaAyah,
        'ayah': _tanpaAyah
            ? null
            : {
                'nama': _namaAyah.text.trim(),
                'nik': _nikAyah.text.trim(),
                'tgl_lahir': keApi(_tglAyah.text),
                'no_hp': noHpKeServer(_hpAyah.text),
                'pekerjaan': _kerjaAyah.text.trim(),
              },
      };

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (!_key.currentState!.validate()) return;
    setState(() => _menyimpan = true);

    try {
      await ApiClient.dio.put('/keluarga', data: _bodyProfil(), options: opsiApi);
      if (!mounted) return;
      _snack('Data keluarga berhasil disimpan');
      Navigator.pop(context, true);
    } catch (e) {
      _snack(pesanError(e));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  /// Tombol simpan berdiri sendiri (tanpa latar footer).
  Widget _tombolSimpan() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: tombolHijauKeluarga(
          _menyimpan ? 'Menyimpan...' : 'Simpan Data Keluarga',
          ikon: Icons.save_outlined,
          memuat: _menyimpan,
          onPressed: _simpan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(
        backgroundColor: AppColors.latar,
        body: Column(
          children: [
            HeaderKeluarga(judul: _judulHeader),
            Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }
    if (_gagal != null) {
      return Scaffold(
        backgroundColor: AppColors.latar,
        body: Column(
          children: [
            const HeaderKeluarga(judul: _judulHeader),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_gagal!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: kTeksGelap)),
                      const SizedBox(height: 16),
                      tombolHijauKeluarga('Coba Lagi', ikon: Icons.refresh, onPressed: () {
                        setState(() => _memuat = true);
                        _muat();
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final d = _ambil();

    return Scaffold(
      backgroundColor: AppColors.latar,
      bottomNavigationBar: _tombolSimpan(),
      body: Column(
        children: [
          const HeaderKeluarga(judul: _judulHeader),
          Expanded(
            child: Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  BagianIbu(
                    data: d,
                    nama: _namaIbu,
                    nik: _nikIbu,
                    tgl: _tglIbu,
                    hp: _hpIbu,
                    kerja: _kerjaIbu,
                    alamat: _alamat,
                    rt: _rt,
                    rw: _rw,
                    onPilihTanggal: () => _pilihTanggal(_tglIbu),
                  ),
                  BagianAyah(
                    data: d,
                    tanpaAyah: _tanpaAyah,
                    onTanpaAyah: (v) => setState(() => _tanpaAyah = v ?? false),
                    nama: _namaAyah,
                    nik: _nikAyah,
                    tgl: _tglAyah,
                    hp: _hpAyah,
                    kerja: _kerjaAyah,
                    onPilihTanggal: () => _pilihTanggal(_tglAyah),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}