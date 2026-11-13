import 'package:flutter/material.dart';

import 'form_anak.dart';
import 'keluarga.dart';

/// Edit data keluarga oleh kader.
///  - Data akun (nama, NIK, No. HP) hanya ditampilkan (tidak diubah di sini).
///  - Data keluarga (ibu, alamat, suami/ayah) dapat diubah lalu disimpan.
///  - Data anak dapat ditambah dan diubah (tidak dihapus, demi riwayat pemeriksaan).
class EditKeluargaPage extends StatefulWidget {
  final String keluargaId;
  const EditKeluargaPage({super.key, required this.keluargaId});

  @override
  State<EditKeluargaPage> createState() => _EditKeluargaPageState();
}

class _EditKeluargaPageState extends State<EditKeluargaPage> {
  final _key = GlobalKey<FormState>();
  final _keluarga = IsianKeluarga();

  bool _memuat = true;
  bool _menyimpan = false;
  String? _galat;

  String _nama = '', _nik = '', _hp = '';
  List<IsianAnak> _anak = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  @override
  void dispose() {
    _keluarga.dispose();
    super.dispose();
  }

  Future<void> _muat({bool diam = false}) async {
    if (!diam) {
      setState(() {
        _memuat = true;
        _galat = null;
      });
    }
    try {
      final d = await KeluargaAkunApi.detail(widget.keluargaId);
      if (!mounted) return;
      final ibu = d['ibu'] is Map ? Map<String, dynamic>.from(d['ibu']) : null;
      final anak = ((d['anak'] as List?) ?? [])
          .map((e) => IsianAnak.fromApi(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _nama = (ibu?['nama'] ?? '').toString();
        _nik = (ibu?['nik'] ?? '').toString();
        _hp = (ibu?['no_hp'] ?? '').toString();
        _anak = anak;
        if (!diam) _keluarga.isiDari(d);
      });
    } catch (e) {
      if (!mounted) return;
      if (diam) {
        kkSnack(context, kkPesanError(e));
      } else {
        setState(() => _galat = kkPesanError(e));
      }
    } finally {
      if (mounted && !diam) setState(() => _memuat = false);
    }
  }

  Future<void> _simpanProfil() async {
    FocusScope.of(context).unfocus();
    if (!_key.currentState!.validate()) return;
    setState(() => _menyimpan = true);
    try {
      await KeluargaAkunApi.ubahProfil(widget.keluargaId, _keluarga.toJson());
      if (!mounted) return;
      kkSnack(context, 'Data keluarga berhasil disimpan');
    } catch (e) {
      if (mounted) kkSnack(context, kkPesanError(e));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _tambahAnak() async {
    final a = await bukaFormAnak(context);
    if (a == null || !mounted) return;
    try {
      await KeluargaAkunApi.tambahAnak(widget.keluargaId, a);
      if (!mounted) return;
      kkSnack(context, 'Data anak berhasil ditambahkan');
      await _muat(diam: true);
    } catch (e) {
      if (mounted) kkSnack(context, kkPesanError(e));
    }
  }

  Future<void> _ubahAnak(IsianAnak awal) async {
    final a = await bukaFormAnak(context, awal: awal);
    if (a == null || !mounted) return;
    try {
      await KeluargaAkunApi.ubahAnak(widget.keluargaId, a);
      if (!mounted) return;
      kkSnack(context, 'Data anak berhasil diubah');
      await _muat(diam: true);
    } catch (e) {
      if (mounted) kkSnack(context, kkPesanError(e));
    }
  }

  Widget _isi() {
    if (_memuat) {
      return const Center(child: CircularProgressIndicator(color: kkHijau));
    }
    if (_galat != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_galat!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: kkTeksAbu)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _muat,
                child: const Text('Coba lagi',
                    style: TextStyle(color: kkHijau, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          KartuBagian(
            judul: 'Data Akun',
            sub: 'Data akun tidak dapat diubah dari menu ini.',
            child: Column(
              children: [
                kkInfo('Nama', _nama),
                kkInfo('NIK', _nik),
                kkInfo('No. HP', _hp),
              ],
            ),
          ),
          Form(
            key: _key,
            child: FormDataKeluarga(isian: _keluarga, nikIbu: _nik),
          ),
          KartuBagian(
            judul: 'Data Anak',
            sub: '${_anak.length} anak terdaftar',
            child: Column(
              children: [
                for (final a in _anak) BarisAnak(anak: a, onUbah: () => _ubahAnak(a)),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _tambahAnak,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Anak',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kkHijau,
                      side: const BorderSide(color: kkHijau),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final siap = !_memuat && _galat == null;
    return Scaffold(
      backgroundColor: kkLatar,
      appBar: kkAppBar('Edit Data Keluarga'),
      body: _isi(),
      bottomNavigationBar: siap
          ? BarAksi(
              labelKiri: 'Kembali',
              labelKanan: 'Simpan',
              memuat: _menyimpan,
              onKiri: () => Navigator.pop(context),
              onKanan: _simpanProfil,
            )
          : null,
    );
  }
}