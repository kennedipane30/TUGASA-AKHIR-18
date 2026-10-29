import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../auth/auth_provider.dart';
import 'bagian_ayah.dart';
import 'bagian_ibu.dart';
import 'keluarga_common.dart';
import 'keluarga_widgets.dart';

export 'keluarga_common.dart' show DataAnak, DataKeluarga, KeluargaApi;
export 'kartu_lengkapi_keluarga.dart';

class LengkapiKeluargaPage extends StatefulWidget {
  const LengkapiKeluargaPage({super.key});

  @override
  State<LengkapiKeluargaPage> createState() => _LengkapiKeluargaPageState();
}

class _LengkapiKeluargaPageState extends State<LengkapiKeluargaPage> {
  static const _judulHeader = 'Lengkapi Data\nKeluarga';

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
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
      return Scaffold(
        backgroundColor: AppColors.latar,
        body: const Column(
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