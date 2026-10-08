import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../auth/auth_provider.dart';
import 'data_anak_page.dart';
import 'keluarga_common.dart';

export 'keluarga_common.dart' show DataAnak, DataKeluarga, KeluargaApi;

// ---------------------------------------------------------------------------
// HALAMAN LENGKAPI DATA KELUARGA (khusus ibu / wali dan suami / ayah)
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

  Future<void> _pilihTanggal(TextEditingController c, {int tahunMin = 90, int tahunMaks = 15}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: parseTgl(c.text) ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - tahunMin),
      lastDate: DateTime(now.year - tahunMaks, 12, 31),
    );
    if (d != null) c.text = fmtTgl(d);
  }

  // Body untuk PUT /keluarga (service.ProfilInput)
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: d.langkahSelesai / 2,
                      minHeight: 8,
                      backgroundColor: AppColors.isiField,
                      color: AppColors.hijau,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${d.langkahSelesai} dari 2 bagian lengkap. Data boleh disimpan bertahap.',
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
                      decoration: dekorInput('Nama lengkap (dari akun)', icon: Icons.person_outline),
                    ),
                    jarak(),
                    TextFormField(
                      controller: _nikIbu,
                      readOnly: true,
                      decoration: dekorInput('NIK (dari akun)', icon: Icons.badge_outlined),
                    ),
                    jarak(),
                    TextFormField(
                      controller: _tglIbu,
                      readOnly: true,
                      onTap: () => _pilihTanggal(_tglIbu),
                      decoration: dekorInput('Tanggal lahir', hint: 'dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                    ),
                    jarak(),
                    TextFormField(
                      controller: _hpIbu,
                      readOnly: true,
                      decoration: dekorInput('No. WhatsApp (dari akun)', icon: Icons.phone_outlined),
                    ),
                    jarak(),
                    TextFormField(
                      controller: _kerjaIbu,
                      textCapitalization: TextCapitalization.words,
                      decoration: dekorInput('Pekerjaan (opsional)', icon: Icons.work_outline),
                    ),
                    jarak(),
                  ],
                  TextFormField(
                    controller: _alamat,
                    maxLines: 2,
                    decoration: dekorInput('Alamat tempat tinggal', icon: Icons.home_outlined),
                  ),
                  jarak(),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rt,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 3,
                          decoration: dekorInput('RT', counter: ''),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _rw,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 3,
                          decoration: dekorInput('RW', counter: ''),
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
                      decoration: dekorInput('Nama lengkap', icon: Icons.person_outline),
                    ),
                    jarak(),
                    TextFormField(
                      controller: _nikAyah,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: dekorInput('NIK (opsional)',
                          icon: Icons.badge_outlined, counter: '${_nikAyah.text.length}/16'),
                      validator: (v) => (v != null && v.isNotEmpty && v.length != 16)
                          ? 'NIK harus 16 digit'
                          : null,
                    ),
                    jarak(),
                    TextFormField(
                      controller: _tglAyah,
                      readOnly: true,
                      onTap: () => _pilihTanggal(_tglAyah),
                      decoration: dekorInput('Tanggal lahir',
                          hint: 'dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                    ),
                    jarak(),
                    TextFormField(
                      controller: _hpAyah,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: dekorInput('No. HP (opsional)', icon: Icons.phone_outlined),
                      validator: (v) => (v != null && v.isNotEmpty && v.length < 10)
                          ? 'No. HP tidak valid'
                          : null,
                    ),
                    jarak(),
                    TextFormField(
                      controller: _kerjaAyah,
                      textCapitalization: TextCapitalization.words,
                      decoration: dekorInput('Pekerjaan (opsional)', icon: Icons.work_outline),
                    ),
                  ],
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
// KARTU DATA KELUARGA (halaman Data Keluarga): status + 2 tombol
//   - Data Orang Tua  -> form lengkapi data diri ibu / ayah
//   - Data Anak       -> halaman / form data anak
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
  int _jumlahAnak = 0;
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
        _jumlahAnak = m.anak.length;
        _gagal = false;
      });
    } catch (_) {
      if (mounted) setState(() => _gagal = true);
    }
  }

  Future<void> _bukaOrtu() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LengkapiKeluargaPage()),
    );
    _muat();
    widget.onKembali?.call();
  }

  Future<void> _bukaAnak() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DataAnakPage()),
    );
    _muat();
    widget.onKembali?.call();
  }

  Widget _status(int selesai) {
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
          ],
        ),
      );
    }
    return SectionCard(
      color: AppColors.kuningMuda,
      title: 'Lengkapi Data Keluarga',
      icon: Icons.assignment_ind_outlined,
      trailing: Pill('$selesai/2', bg: Colors.white, fg: AppColors.kuning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lengkapi data diri ibu dan data suami/ayah agar jadwal, kartu digital, dan grafik pertumbuhan dapat digunakan.',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: selesai / 2,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppColors.hijau,
            ),
          ),
        ],
      ),
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _status(selesai),
        SectionCard(
          title: 'Kelola Data Keluarga',
          icon: Icons.family_restroom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: AppButton('Data Orang Tua',
                    icon: Icons.people_outline, onPressed: _bukaOrtu),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                    _jumlahAnak > 0 ? 'Data Anak ($_jumlahAnak)' : 'Data Anak',
                    icon: Icons.child_care,
                    filled: false,
                    onPressed: _bukaAnak),
              ),
            ],
          ),
        ),
      ],
    );
  }
}