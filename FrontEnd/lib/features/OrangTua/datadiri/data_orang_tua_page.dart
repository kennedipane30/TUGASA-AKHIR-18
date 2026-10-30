import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
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

const kGarisKartu = Color(0xFFE6ECE8);
const kGarisInput = Color(0xFFD7E6DD);

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
                  child: Text(
                    judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
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

// ---------------------------------------------------------------------------
// WIDGET BERSAMA
// ---------------------------------------------------------------------------
InputDecoration dekorKeluarga(String hint,
    {IconData? icon, String? counter, bool terkunci = false}) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: Colors.black45),
    counterText: counter ?? '',
    filled: true,
    fillColor: terkunci ? const Color(0xFFF1F5F3) : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(kGarisInput),
    enabledBorder: b(terkunci ? Colors.transparent : kGarisInput),
    focusedBorder: b(kHijauTua),
    errorBorder: b(AppColors.merah),
    focusedErrorBorder: b(AppColors.merah),
  );
}

Widget labelKeluarga(String teks, {String? ket}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        if (ket != null)
          TextSpan(
              text: ' $ket',
              style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
      ])),
    );

Widget gapKeluarga() => const SizedBox(height: 14);

Widget centangKeluarga(bool nilai, String teks, ValueChanged<bool?> onChanged) =>
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: kHijauGelap,
      value: nilai,
      title: Text(teks, style: const TextStyle(fontSize: 13)),
      onChanged: onChanged,
    );

Widget pillStatusKeluarga(bool lengkap) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: lengkap ? AppColors.hijauMuda : AppColors.kuningMuda,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(lengkap ? 'Lengkap' : 'Belum lengkap',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: lengkap ? kHijauTua : AppColors.kuning)),
    );

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGarisKartu),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7F0E3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: kHijauGelap),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: kHijauTua)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class StepperKeluarga extends StatelessWidget {
  final DataKeluarga data;
  const StepperKeluarga({super.key, required this.data});

  Widget _bulat(String no, bool selesai) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
              color: selesai ? kHijauGelap : Colors.grey.shade400, width: 1.6),
        ),
        child: selesai
            ? const Icon(Icons.check, size: 18, color: kHijauGelap)
            : Text(no,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: no == '1' ? kHijauGelap : Colors.grey)),
      );

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              _bulat('1', d.ibuLengkap),
              const SizedBox(height: 4),
              const Text('Data Diri',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 15, left: 8, right: 8),
                child: Divider(height: 2, thickness: 2, color: Colors.grey.shade300),
              ),
            ),
            Column(children: [
              _bulat('2', d.ayahLengkap),
              const SizedBox(height: 4),
              const Text('Suami / Ayah',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: d.langkahSelesai / 2,
            minHeight: 7,
            backgroundColor: const Color(0xFFE6EEEA),
            color: kHijauGelap,
          ),
        ),
        const SizedBox(height: 8),
        Text('${d.langkahSelesai} dari 2 bagian lengkap. Data boleh disimpan bertahap.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BAGIAN IBU
// ---------------------------------------------------------------------------
class BagianIbu extends StatelessWidget {
  final DataKeluarga data;
  final bool tanpaIbu;
  final ValueChanged<bool?> onTanpaIbu;
  final TextEditingController nama, nik, tgl, hp, kerja, alamat, rt, rw;
  final VoidCallback onPilihTanggal;

  const BagianIbu({
    super.key,
    required this.data,
    required this.tanpaIbu,
    required this.onTanpaIbu,
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
      title: '1. Data Diri Ibu / Wali',
      icon: Icons.person_outline,
      trailing: pillStatusKeluarga(data.ibuLengkap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          centangKeluarga(tanpaIbu, 'Tidak ada data ibu', onTanpaIbu),
          if (!tanpaIbu) ...[
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
                  dekorKeluarga('dd/mm/yyyy', icon: Icons.calendar_today_outlined),
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
          ],
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
                      decoration: dekorKeluarga('RT'),
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
                      decoration: dekorKeluarga('RW'),
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
      title: '2. Data Suami / Ayah',
      icon: Icons.man_outlined,
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
                  dekorKeluarga('dd/mm/yyyy', icon: Icons.calendar_today_outlined),
            ),
            gapKeluarga(),
            labelKeluarga('No. HP', ket: '(opsional)'),
            TextFormField(
              controller: hp,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  dekorKeluarga('No. HP (opsional)', icon: Icons.phone_outlined),
              validator: (v) => (v != null && v.isNotEmpty && v.length < 10)
                  ? 'No. HP tidak valid'
                  : null,
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

  bool _tanpaIbu = false;
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
      _hpIbu.text = m.noHpIbu;

      _tanpaIbu = false;
      _tglIbu.text = m.tglLahirIbu;
      _kerjaIbu.text = m.pekerjaanIbu;
      _alamat.text = m.alamat;
      _rt.text = m.rt;
      _rw.text = m.rw;

      _tanpaAyah = m.tanpaAyah;
      _namaAyah.text = m.namaAyah;
      _nikAyah.text = m.nikAyah;
      _tglAyah.text = m.tglLahirAyah;
      _hpAyah.text = m.noHpAyah;
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
        tanpaIbu: _tanpaIbu,
        namaIbu: _namaIbu.text.trim(),
        nikIbu: _nikIbu.text.trim(),
        tglLahirIbu: _tglIbu.text.trim(),
        noHpIbu: _hpIbu.text.trim(),
        pekerjaanIbu: _kerjaIbu.text.trim(),
        alamat: _alamat.text.trim(),
        rt: _rt.text.trim(),
        rw: _rw.text.trim(),
        tanpaAyah: _tanpaAyah,
        namaAyah: _namaAyah.text.trim(),
        nikAyah: _nikAyah.text.trim(),
        tglLahirAyah: _tglAyah.text.trim(),
        noHpAyah: _hpAyah.text.trim(),
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
        'tanpa_ibu': _tanpaIbu,
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
                'no_hp': _hpAyah.text.trim(),
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

  Widget _tombolSimpan() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kHijauTua,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _menyimpan ? null : _simpan,
            icon: _menyimpan
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_alt_outlined),
            label: Text(_menyimpan ? 'Menyimpan...' : 'Simpan Data Keluarga',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
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
                      const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_gagal!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _memuat = true);
                          _muat();
                        },
                        child: const Text('Coba lagi'),
                      ),
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
                  KartuKeluarga(child: StepperKeluarga(data: d)),
                  BagianIbu(
                    data: d,
                    tanpaIbu: _tanpaIbu,
                    onTanpaIbu: (v) => setState(() => _tanpaIbu = v ?? false),
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