import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../auth/auth_provider.dart';

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
        tglLahir: _dariApi(j['tanggal_lahir']),
        jk: j['jenis_kelamin']?.toString() ?? '',
        beratLahir: _angka(j['berat_lahir_kg']),
        panjangLahir: _angka(j['panjang_lahir_cm']),
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
  // Anak
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

  int get langkahSelesai =>
      (ibuLengkap ? 1 : 0) + (ayahLengkap ? 1 : 0) + (anakLengkap ? 1 : 0);
  bool get lengkap => langkahSelesai == 3;
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------
final Options _opsi = Options(receiveTimeout: const Duration(seconds: 15));

Map<String, dynamic>? _peta(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

class KeluargaApi {
  /// GET /keluarga -> { data: { keluarga, ibu, ayah, anak, status } }
  static Future<Map<String, dynamic>> ambil() async {
    final r = await ApiClient.dio.get('/keluarga', options: _opsi);
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
      tglLahirIbu: _dariApi(ibu?['tanggal_lahir']),
      pekerjaanIbu: (ibu?['pekerjaan'] ?? '').toString(),
      alamat: (k?['alamat'] ?? '').toString(),
      rt: (k?['rt'] ?? '').toString(),
      rw: (k?['rw'] ?? '').toString(),
      tanpaAyah: k?['tanpa_ayah'] == true,
      namaAyah: (ayah?['nama'] ?? '').toString(),
      nikAyah: (ayah?['nik'] ?? '').toString(),
      tglLahirAyah: _dariApi(ayah?['tanggal_lahir']),
      noHpAyah: (ayah?['no_hp'] ?? '').toString(),
      pekerjaanAyah: (ayah?['pekerjaan'] ?? '').toString(),
      anak: anak,
    );
  }
}

String _pesanError(Object e) {
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
DateTime? _parseTgl(String s) {
  final p = s.split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

String _fmtTgl(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// "2026-10-01T00:00:00Z" -> "01/10/2026"
String _dariApi(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  if (s.length < 10) return '';
  final p = s.substring(0, 10).split('-');
  if (p.length != 3) return '';
  return '${p[2]}/${p[1]}/${p[0]}';
}

// "01/10/2026" -> "2026-10-01"
String _keApi(String tgl) {
  final d = _parseTgl(tgl);
  if (d == null) return '';
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _angka(dynamic v) {
  if (v == null) return '';
  final n = double.tryParse(v.toString());
  if (n == null) return '';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

double? _keDouble(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

String _usia(String tgl) {
  final l = _parseTgl(tgl);
  if (l == null) return '-';
  final n = DateTime.now();
  var bln = (n.year - l.year) * 12 + (n.month - l.month);
  if (n.day < l.day) bln--;
  if (bln < 0) bln = 0;
  return bln >= 12 ? '${bln ~/ 12} th ${bln % 12} bln' : '$bln bln';
}

InputDecoration _dekor(String label, {String? hint, IconData? icon, Widget? suffix, String? counter}) {
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

Widget _jarak() => const SizedBox(height: 12);

// ---------------------------------------------------------------------------
// HALAMAN LENGKAPI DATA KELUARGA
// ---------------------------------------------------------------------------
class LengkapiKeluargaPage extends StatefulWidget {
  const LengkapiKeluargaPage({super.key});

  @override
  State<LengkapiKeluargaPage> createState() => _LengkapiKeluargaPageState();
}

class _LengkapiKeluargaPageState extends State<LengkapiKeluargaPage> {
  final _key = GlobalKey<FormState>();
  bool _memuat = true;
  bool _menyimpan = false;
  String? _gagal;

  // Ibu / wali
  bool _tanpaIbu = false;
  final _namaIbu = TextEditingController();
  final _nikIbu = TextEditingController();
  final _tglIbu = TextEditingController();
  final _hpIbu = TextEditingController();
  final _kerjaIbu = TextEditingController();
  final _alamat = TextEditingController();
  final _rt = TextEditingController();
  final _rw = TextEditingController();

  // Suami / ayah
  bool _tanpaAyah = false;
  final _namaAyah = TextEditingController();
  final _nikAyah = TextEditingController();
  final _tglAyah = TextEditingController();
  final _hpAyah = TextEditingController();
  final _kerjaAyah = TextEditingController();

  // Anak
  List<DataAnak> _anak = [];

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

  // Ambil data dari server (GET /keluarga)
  Future<void> _muat() async {
    final user = context.read<AuthProvider>().user;
    try {
      final data = await KeluargaApi.ambil();
      final m = KeluargaApi.keModel(data, user: user == null ? null : Map<String, dynamic>.from(user));

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

      _anak = m.anak;

      setState(() {
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesanError(e);
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
        anak: _anak,
      );

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pilihTanggal(TextEditingController c, {int tahunMin = 90, int tahunMaks = 15}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _parseTgl(c.text) ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - tahunMin),
      lastDate: DateTime(now.year - tahunMaks, 12, 31),
    );
    if (d != null) c.text = _fmtTgl(d);
  }

  // Body untuk PUT /keluarga (service.ProfilInput)
  Map<String, dynamic> _bodyProfil() => {
        'tanpa_ibu': _tanpaIbu,
        'tgl_lahir_ibu': _keApi(_tglIbu.text),
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
                'tgl_lahir': _keApi(_tglAyah.text),
                'no_hp': _hpAyah.text.trim(),
                'pekerjaan': _kerjaAyah.text.trim(),
              },
      };

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (!_key.currentState!.validate()) return;
    setState(() => _menyimpan = true);

    try {
      await ApiClient.dio.put('/keluarga', data: _bodyProfil(), options: _opsi);
      if (!mounted) return;
      _snack('Data keluarga berhasil disimpan');
      Navigator.pop(context, true);
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _formAnak({DataAnak? awal, int? indeks}) async {
    final hasil = await showModalBottomSheet<DataAnak>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FormAnak(awal: awal),
    );
    if (hasil == null) return;
    setState(() {
      if (indeks == null) {
        _anak = [..._anak, hasil];
      } else {
        _anak = [..._anak]..[indeks] = hasil;
      }
    });
  }

  Future<void> _hapusAnak(int i) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data anak?'),
        content: Text('Data ${_anak[i].nama} akan dihapus dari daftar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.merah, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;

    final id = _anak[i].id;
    try {
      if (id != null) {
        await ApiClient.dio.delete('/keluarga/anak/$id', options: _opsi);
      }
      if (!mounted) return;
      setState(() => _anak = [..._anak]..removeAt(i));
      _snack('Data anak dihapus');
    } catch (e) {
      _snack(_pesanError(e));
    }
  }

  Widget _langkah(String label, bool selesai) => Expanded(
        child: Column(
          children: [
            Icon(selesai ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selesai ? AppColors.hijau : Colors.grey, size: 26),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selesai ? AppColors.hijau : AppColors.teksRedup)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_gagal != null) {
      return Scaffold(
        backgroundColor: AppColors.latar,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Lengkapi Data Keluarga',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ),
        body: Center(
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
      );
    }
    final d = _ambil();

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Lengkapi Data Keluarga',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hijau,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _menyimpan ? null : _simpan,
              icon: _menyimpan
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_menyimpan ? 'Menyimpan...' : 'Simpan Data Keluarga',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Progres
            SectionCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      _langkah('Data Diri', d.ibuLengkap),
                      _langkah('Suami / Ayah', d.ayahLengkap),
                      _langkah('Anak', d.anakLengkap),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: d.langkahSelesai / 3,
                      minHeight: 8,
                      backgroundColor: AppColors.isiField,
                      color: AppColors.hijau,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${d.langkahSelesai} dari 3 bagian lengkap. Data boleh disimpan bertahap.',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
                ],
              ),
            ),

            // 1. Data diri ibu / wali
            SectionCard(
              title: '1. Data Diri Ibu / Wali',
              icon: Icons.person_outline,
              trailing: d.ibuLengkap
                  ? const Pill('Lengkap', icon: Icons.check)
                  : const Pill('Belum lengkap', bg: AppColors.kuningMuda, fg: AppColors.kuning),
              child: Column(
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.hijau,
                    value: _tanpaIbu,
                    title: const Text('Tidak ada data ibu', style: TextStyle(fontSize: 13)),
                    onChanged: (v) => setState(() => _tanpaIbu = v ?? false),
                  ),

                  if (!_tanpaIbu) ...[
                    TextFormField(
                      controller: _namaIbu,
                      readOnly: true,
                      decoration: _dekor('Nama lengkap (dari akun)', icon: Icons.person_outline),
                    ),
                    _jarak(),
                    TextFormField(
                      controller: _nikIbu,
                      readOnly: true,
                      decoration: _dekor('NIK (dari akun)', icon: Icons.badge_outlined),
                    ),
                    _jarak(),
                    TextFormField(
                      controller: _tglIbu,
                      readOnly: true,
                      onTap: () => _pilihTanggal(_tglIbu),
                      decoration: _dekor('Tanggal lahir', hint: 'dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                    ),
                    _jarak(),
                    TextFormField(
                      controller: _hpIbu,
                      readOnly: true,
                      decoration: _dekor('No. WhatsApp (dari akun)', icon: Icons.phone_outlined),
                    ),
                    _jarak(),
                    TextFormField(
                      controller: _kerjaIbu,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dekor('Pekerjaan (opsional)', icon: Icons.work_outline),
                    ),
                    _jarak(),
                  ],
                  TextFormField(
                    controller: _alamat,
                    maxLines: 2,
                    decoration: _dekor('Alamat tempat tinggal', icon: Icons.home_outlined),
                  ),
                  _jarak(),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rt,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 3,
                          decoration: _dekor('RT', counter: ''),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _rw,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 3,
                          decoration: _dekor('RW', counter: ''),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Suami / ayah
            SectionCard(
              title: '2. Data Suami / Ayah',
              icon: Icons.man_outlined,
              trailing: d.ayahLengkap
                  ? const Pill('Lengkap', icon: Icons.check)
                  : const Pill('Belum lengkap', bg: AppColors.kuningMuda, fg: AppColors.kuning),
              child: Column(
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.hijau,
                    value: _tanpaAyah,
                    title: const Text('Tidak ada data suami / ayah yang diisi',
                        style: TextStyle(fontSize: 13)),
                    onChanged: (v) => setState(() => _tanpaAyah = v ?? false),
                  ),
                  if (!_tanpaAyah) ...[
                    TextFormField(
                      controller: _namaAyah,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dekor('Nama lengkap', icon: Icons.person_outline),
                    ),
                    _jarak(),
                    TextFormField(
                      controller: _nikAyah,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dekor('NIK (opsional)',
                          icon: Icons.badge_outlined, counter: '${_nikAyah.text.length}/16'),
                      validator: (v) => (v != null && v.isNotEmpty && v.length != 16)
                          ? 'NIK harus 16 digit'
                          : null,
                    ),
                    _jarak(),
                    TextFormField(
                      controller: _tglAyah,
                      readOnly: true,
                      onTap: () => _pilihTanggal(_tglAyah),
                      decoration: _dekor('Tanggal lahir',
                          hint: 'dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                    ),
                    _jarak(),
                    TextFormField(
                      controller: _hpAyah,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dekor('No. HP (opsional)', icon: Icons.phone_outlined),
                      validator: (v) => (v != null && v.isNotEmpty && v.length < 10)
                          ? 'No. HP tidak valid'
                          : null,
                    ),
                    _jarak(),
                    TextFormField(
                      controller: _kerjaAyah,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dekor('Pekerjaan (opsional)', icon: Icons.work_outline),
                    ),
                  ],
                ],
              ),
            ),

            // 3. Anak
            SectionCard(
              title: '3. Data Anak',
              icon: Icons.child_care,
              trailing: d.anakLengkap
                  ? Pill('${_anak.length} anak', icon: Icons.check)
                  : const Pill('Belum ada', bg: AppColors.kuningMuda, fg: AppColors.kuning),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_anak.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Tambahkan data anak balita Anda. Boleh dilengkapi nanti jika Buku KIA sedang tidak di dekat Anda.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                      ),
                    ),
                  for (var i = 0; i < _anak.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.latar,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.hijauMuda,
                            child: Icon(_anak[i].jk == 'P' ? Icons.female : Icons.male,
                                color: AppColors.hijau),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_anak[i].nama,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800, fontSize: 13.5)),
                                Text(
                                  '${_anak[i].jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${_usia(_anak[i].tglLahir)} · lahir ${_anak[i].tglLahir}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.teksRedup),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Ubah',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _formAnak(awal: _anak[i], indeks: i),
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: AppColors.merah),
                            onPressed: () => _hapusAnak(i),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton('Tambah Anak',
                        icon: Icons.add, filled: false, onPressed: () => _formAnak()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORM TAMBAH / UBAH ANAK (bottom sheet) - langsung menyimpan ke server
// ---------------------------------------------------------------------------
class _FormAnak extends StatefulWidget {
  final DataAnak? awal;
  const _FormAnak({this.awal});

  @override
  State<_FormAnak> createState() => _FormAnakState();
}

class _FormAnakState extends State<_FormAnak> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _nik;
  late final TextEditingController _tgl;
  late final TextEditingController _berat;
  late final TextEditingController _panjang;
  String _jk = '';
  bool _jkError = false;
  bool _menyimpan = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.awal;
    _nama = TextEditingController(text: a?.nama ?? '');
    _nik = TextEditingController(text: a?.nik ?? '');
    _tgl = TextEditingController(text: a?.tglLahir ?? '');
    _berat = TextEditingController(text: a?.beratLahir ?? '');
    _panjang = TextEditingController(text: a?.panjangLahir ?? '');
    _jk = a?.jk ?? '';
  }

  @override
  void dispose() {
    _nama.dispose();
    _nik.dispose();
    _tgl.dispose();
    _berat.dispose();
    _panjang.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _parseTgl(_tgl.text) ?? now,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
    );
    if (d != null) setState(() => _tgl.text = _fmtTgl(d));
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    final ok = _key.currentState!.validate();
    setState(() => _jkError = _jk.isEmpty);
    if (!ok || _jk.isEmpty) return;

    setState(() {
      _menyimpan = true;
      _error = null;
    });

    // Body sesuai service.AnakInput
    final body = {
      'nama': _nama.text.trim(),
      'nik': _nik.text.trim(),
      'tgl_lahir': _keApi(_tgl.text),
      'jk': _jk,
      'berat_lahir': _keDouble(_berat.text),
      'panjang_lahir': _keDouble(_panjang.text),
    };

    try {
      final id = widget.awal?.id;
      final r = id == null
          ? await ApiClient.dio.post('/keluarga/anak', data: body, options: _opsi)
          : await ApiClient.dio.put('/keluarga/anak/$id', data: body, options: _opsi);
      final hasil = DataAnak.fromApi(Map<String, dynamic>.from(r.data['data'] as Map));
      if (!mounted) return;
      Navigator.pop(context, hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _error = _pesanError(e);
      });
    }
  }

  String? _rentang(String? v, double min, double maks, String nama) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < min || n > maks) return '$nama tidak wajar ($min-$maks)';
    return null;
  }

  Widget _pilihJk(String kode, String teks, IconData icon) {
    final aktif = _jk == kode;
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: aktif ? AppColors.hijauMuda : AppColors.isiField,
          side: BorderSide(color: aktif ? AppColors.hijau : Colors.transparent),
          foregroundColor: aktif ? AppColors.hijau : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => setState(() {
          _jk = kode;
          _jkError = false;
        }),
        icon: Icon(icon, size: 18),
        label: Text(teks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.awal == null ? 'Tambah Data Anak' : 'Ubah Data Anak',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                decoration: _dekor('Nama lengkap anak', icon: Icons.child_care),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              _jarak(),
              TextFormField(
                controller: _tgl,
                readOnly: true,
                onTap: _pilihTanggal,
                decoration: _dekor('Tanggal lahir',
                    hint: 'dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Tanggal lahir wajib diisi' : null,
              ),
              _jarak(),
              const Text('Jenis kelamin', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _pilihJk('L', 'Laki-laki', Icons.male),
                  const SizedBox(width: 10),
                  _pilihJk('P', 'Perempuan', Icons.female),
                ],
              ),
              if (_jkError)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Pilih jenis kelamin',
                      style: TextStyle(color: AppColors.merah, fontSize: 12)),
                ),
              _jarak(),
              TextFormField(
                controller: _nik,
                keyboardType: TextInputType.number,
                maxLength: 16,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dekor('NIK anak (opsional)', icon: Icons.badge_outlined, counter: ''),
                validator: (v) => (v != null && v.isNotEmpty && v.length != 16)
                    ? 'NIK harus 16 digit'
                    : null,
              ),
              _jarak(),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _berat,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dekor('Berat lahir (kg)'),
                      validator: (v) => _rentang(v, 0.5, 7, 'Berat'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _panjang,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dekor('Panjang lahir (cm)'),
                      validator: (v) => _rentang(v, 30, 65, 'Panjang'),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.merah, fontSize: 12.5)),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton('Batal',
                        filled: false, onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(_menyimpan ? 'Menyimpan...' : 'Simpan',
                        icon: Icons.check, onPressed: _menyimpan ? () {} : _simpan),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KARTU DI BERANDA
// ---------------------------------------------------------------------------
class KartuLengkapiKeluarga extends StatefulWidget {
  final VoidCallback? onKembali;
  const KartuLengkapiKeluarga({super.key, this.onKembali});

  @override
  State<KartuLengkapiKeluarga> createState() => _KartuLengkapiKeluargaState();
}

class _KartuLengkapiKeluargaState extends State<KartuLengkapiKeluarga> {
  int? _selesai;
  bool _lengkap = false;
  bool _gagal = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final data = await KeluargaApi.ambil();
      final m = KeluargaApi.keModel(data);
      if (!mounted) return;
      setState(() {
        _selesai = m.langkahSelesai;
        _lengkap = m.lengkap;
        _gagal = false;
      });
    } catch (_) {
      if (mounted) setState(() => _gagal = true);
    }
  }

  Future<void> _buka() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LengkapiKeluargaPage()),
    );
    _muat();
    widget.onKembali?.call();
  }

  @override
  Widget build(BuildContext context) {
    final selesai = _selesai;

    if (selesai == null) {
      if (!_gagal) return const SizedBox.shrink();
      return SectionCard(
        color: AppColors.kuningMuda,
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: AppColors.kuning),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Gagal memuat data keluarga',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            TextButton(onPressed: _muat, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    if (_lengkap) {
      return SectionCard(
        color: AppColors.hijauMuda,
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.hijau),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Data keluarga sudah lengkap',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
            TextButton(onPressed: _buka, child: const Text('Ubah')),
          ],
        ),
      );
    }

    return SectionCard(
      color: AppColors.kuningMuda,
      title: 'Lengkapi Data Keluarga',
      icon: Icons.assignment_ind_outlined,
      trailing: Pill('$selesai/3', bg: Colors.white, fg: AppColors.kuning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lengkapi data diri, data suami/ayah, dan data anak agar jadwal, kartu digital, dan grafik pertumbuhan dapat digunakan.',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: selesai / 3,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppColors.hijau,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton('Lengkapi Sekarang', icon: Icons.edit_note, onPressed: _buka),
          ),
        ],
      ),
    );
  }
}