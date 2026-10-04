import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../auth/auth_provider.dart';

// ---------------------------------------------------------------------------
// Daftar posyandu contoh. Ganti dengan data dari API (tabel posyandu).
// ---------------------------------------------------------------------------
const _daftarPosyandu = <String>[
  'Posyandu Melati 1',
  'Posyandu Melati 2',
  'Posyandu Mawar',
];

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class DataAnak {
  String nama, nik, tglLahir, jk, beratLahir, panjangLahir;

  DataAnak({
    this.nama = '',
    this.nik = '',
    this.tglLahir = '',
    this.jk = '',
    this.beratLahir = '',
    this.panjangLahir = '',
  });

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'nik': nik,
        'tglLahir': tglLahir,
        'jk': jk,
        'beratLahir': beratLahir,
        'panjangLahir': panjangLahir,
      };

  factory DataAnak.fromJson(Map<String, dynamic> j) => DataAnak(
        nama: j['nama'] ?? '',
        nik: j['nik'] ?? '',
        tglLahir: j['tglLahir'] ?? '',
        jk: j['jk'] ?? '',
        beratLahir: j['beratLahir'] ?? '',
        panjangLahir: j['panjangLahir'] ?? '',
      );
}

class DataKeluarga {
  // Ibu / wali
  String namaIbu, nikIbu, tglLahirIbu, noHpIbu, pekerjaanIbu;
  String alamat, rt, rw, wilayah;
  // Suami / ayah
  bool tanpaAyah;
  String namaAyah, nikAyah, tglLahirAyah, noHpAyah, pekerjaanAyah;
  // Anak
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
    this.wilayah = '',
    this.tanpaAyah = false,
    this.namaAyah = '',
    this.nikAyah = '',
    this.tglLahirAyah = '',
    this.noHpAyah = '',
    this.pekerjaanAyah = '',
    List<DataAnak>? anak,
  }) : anak = anak ?? [];

  bool get ibuLengkap =>
      namaIbu.trim().isNotEmpty &&
      tglLahirIbu.isNotEmpty &&
      alamat.trim().isNotEmpty &&
      rw.trim().isNotEmpty &&
      wilayah.isNotEmpty;

  bool get ayahLengkap => tanpaAyah || namaAyah.trim().isNotEmpty;
  bool get anakLengkap => anak.isNotEmpty;

  int get langkahSelesai =>
      (ibuLengkap ? 1 : 0) + (ayahLengkap ? 1 : 0) + (anakLengkap ? 1 : 0);
  bool get lengkap => langkahSelesai == 3;

  Map<String, dynamic> toJson() => {
        'namaIbu': namaIbu,
        'nikIbu': nikIbu,
        'tglLahirIbu': tglLahirIbu,
        'noHpIbu': noHpIbu,
        'pekerjaanIbu': pekerjaanIbu,
        'alamat': alamat,
        'rt': rt,
        'rw': rw,
        'wilayah': wilayah,
        'tanpaAyah': tanpaAyah,
        'namaAyah': namaAyah,
        'nikAyah': nikAyah,
        'tglLahirAyah': tglLahirAyah,
        'noHpAyah': noHpAyah,
        'pekerjaanAyah': pekerjaanAyah,
        'anak': anak.map((e) => e.toJson()).toList(),
      };

  factory DataKeluarga.fromJson(Map<String, dynamic> j) => DataKeluarga(
        namaIbu: j['namaIbu'] ?? '',
        nikIbu: j['nikIbu'] ?? '',
        tglLahirIbu: j['tglLahirIbu'] ?? '',
        noHpIbu: j['noHpIbu'] ?? '',
        pekerjaanIbu: j['pekerjaanIbu'] ?? '',
        alamat: j['alamat'] ?? '',
        rt: j['rt'] ?? '',
        rw: j['rw'] ?? '',
        wilayah: j['wilayah'] ?? '',
        tanpaAyah: j['tanpaAyah'] ?? false,
        namaAyah: j['namaAyah'] ?? '',
        nikAyah: j['nikAyah'] ?? '',
        tglLahirAyah: j['tglLahirAyah'] ?? '',
        noHpAyah: j['noHpAyah'] ?? '',
        pekerjaanAyah: j['pekerjaanAyah'] ?? '',
        anak: ((j['anak'] ?? []) as List)
            .map((e) => DataAnak.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Penyimpanan sementara di perangkat (per akun).
/// Ganti dengan API keluarga/anak + database lokal saat endpoint sudah dibuat.
class KeluargaStorage {
  static const _s = FlutterSecureStorage();
  static String _key(String uid) => 'keluarga_$uid';

  static Future<DataKeluarga> baca(String uid) async {
    final raw = await _s.read(key: _key(uid));
    if (raw == null) return DataKeluarga();
    try {
      return DataKeluarga.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return DataKeluarga();
    }
  }

  static Future<void> simpan(String uid, DataKeluarga d) =>
      _s.write(key: _key(uid), value: jsonEncode(d.toJson()));
}

String _idPengguna(BuildContext c) =>
    c.read<AuthProvider>().user?['id']?.toString() ?? 'anon';

// ---------------------------------------------------------------------------
// FUNGSI BANTU
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
  late final String _uid;
  bool _memuat = true;
  bool _menyimpan = false;

  // Ibu / wali
  final _namaIbu = TextEditingController();
  final _nikIbu = TextEditingController();
  final _tglIbu = TextEditingController();
  final _hpIbu = TextEditingController();
  final _kerjaIbu = TextEditingController();
  final _alamat = TextEditingController();
  final _rt = TextEditingController();
  final _rw = TextEditingController();
  String? _wilayah;

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
    _uid = _idPengguna(context);
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
    final d = await KeluargaStorage.baca(_uid);
    final user = context.read<AuthProvider>().user;

    _namaIbu.text = d.namaIbu.isNotEmpty ? d.namaIbu : (user?['nama'] ?? '').toString();
    _nikIbu.text = d.nikIbu.isNotEmpty ? d.nikIbu : (user?['nik'] ?? '').toString();
    _hpIbu.text = d.noHpIbu.isNotEmpty ? d.noHpIbu : (user?['no_hp'] ?? '').toString();
    _tglIbu.text = d.tglLahirIbu;
    _kerjaIbu.text = d.pekerjaanIbu;
    _alamat.text = d.alamat;
    _rt.text = d.rt;
    _rw.text = d.rw;
    _wilayah = _daftarPosyandu.contains(d.wilayah) ? d.wilayah : null;

    _tanpaAyah = d.tanpaAyah;
    _namaAyah.text = d.namaAyah;
    _nikAyah.text = d.nikAyah;
    _tglAyah.text = d.tglLahirAyah;
    _hpAyah.text = d.noHpAyah;
    _kerjaAyah.text = d.pekerjaanAyah;

    _anak = d.anak;

    for (final c in _semua) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    if (mounted) setState(() => _memuat = false);
  }

  DataKeluarga _ambil() => DataKeluarga(
        namaIbu: _namaIbu.text.trim(),
        nikIbu: _nikIbu.text.trim(),
        tglLahirIbu: _tglIbu.text.trim(),
        noHpIbu: _hpIbu.text.trim(),
        pekerjaanIbu: _kerjaIbu.text.trim(),
        alamat: _alamat.text.trim(),
        rt: _rt.text.trim(),
        rw: _rw.text.trim(),
        wilayah: _wilayah ?? '',
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

  Future<void> _simpan() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _menyimpan = true);
    try {
      await KeluargaStorage.simpan(_uid, _ambil());
      if (!mounted) return;
      _snack('Data keluarga disimpan');
      Navigator.pop(context, true);
    } catch (_) {
      _snack('Gagal menyimpan data');
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
    if (ya == true) setState(() => _anak = [..._anak]..removeAt(i));
  }

  // ----------------------------------------------------------------- tampilan
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
                  TextFormField(
                    controller: _namaIbu,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dekor('Nama lengkap', icon: Icons.person_outline),
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
                    decoration: _dekor('Tanggal lahir',
                        hint: 'dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                  ),
                  _jarak(),
                  TextFormField(
                    controller: _hpIbu,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dekor('No. WhatsApp', icon: Icons.phone_outlined),
                    validator: (v) => (v != null && v.isNotEmpty && v.length < 10)
                        ? 'No. WhatsApp tidak valid'
                        : null,
                  ),
                  _jarak(),
                  TextFormField(
                    controller: _kerjaIbu,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dekor('Pekerjaan (opsional)', icon: Icons.work_outline),
                  ),
                  _jarak(),
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
                  _jarak(),
                  DropdownButtonFormField<String>(
                    value: _wilayah,
                    isExpanded: true,
                    decoration: _dekor('Posyandu terdekat', icon: Icons.location_on_outlined),
                    items: _daftarPosyandu
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _wilayah = v),
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
// FORM TAMBAH / UBAH ANAK (bottom sheet)
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

  void _simpan() {
    final ok = _key.currentState!.validate();
    setState(() => _jkError = _jk.isEmpty);
    if (!ok || _jk.isEmpty) return;
    Navigator.pop(
      context,
      DataAnak(
        nama: _nama.text.trim(),
        nik: _nik.text.trim(),
        tglLahir: _tgl.text.trim(),
        jk: _jk,
        beratLahir: _berat.text.trim(),
        panjangLahir: _panjang.text.trim(),
      ),
    );
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton('Batal',
                        filled: false, onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: AppButton('Simpan', icon: Icons.check, onPressed: _simpan)),
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
// KARTU PENGINGAT DI BERANDA
// ---------------------------------------------------------------------------
class KartuLengkapiKeluarga extends StatefulWidget {
  const KartuLengkapiKeluarga({super.key});

  @override
  State<KartuLengkapiKeluarga> createState() => _KartuLengkapiKeluargaState();
}

class _KartuLengkapiKeluargaState extends State<KartuLengkapiKeluarga> {
  DataKeluarga? _data;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = _idPengguna(context);
    _muat();
  }

  Future<void> _muat() async {
    final d = await KeluargaStorage.baca(_uid);
    if (mounted) setState(() => _data = d);
  }

  Future<void> _buka() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LengkapiKeluargaPage()),
    );
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return const SizedBox.shrink();

    if (d.lengkap) {
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
      trailing: Pill('${d.langkahSelesai}/3', bg: Colors.white, fg: AppColors.kuning),
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
              value: d.langkahSelesai / 3,
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