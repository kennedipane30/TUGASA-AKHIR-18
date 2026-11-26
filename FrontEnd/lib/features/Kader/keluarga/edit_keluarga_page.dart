import 'package:flutter/material.dart';

import '../../../core/utils/no_hp.dart';
import 'form_balita.dart';
import 'keluarga.dart';

/// Edit data keluarga oleh kader.
///  - Data akun (nama, NIK, No. HP) hanya ditampilkan (tidak diubah di sini).
///  - Data keluarga (ibu, alamat, suami/ayah) dapat diubah lalu disimpan.
///  - Data balita dapat ditambah dan diubah (tidak dihapus, demi riwayat pemeriksaan).
///  - Hanya balita aktif yang ditampilkan. Balita arsip (pindah, meninggal, lulus balita)
///    dilihat dan dikelola di Semua Balita > Diarsipkan.
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
  List<IsianBalita> _balita = [];

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
      final balita = ((d['balita'] as List?) ?? [])
          .map((e) => IsianBalita.fromApi(Map<String, dynamic>.from(e as Map)))
          .where((a) => !a.diarsipkan)
          .toList();
      setState(() {
        _nama = (ibu?['nama'] ?? '').toString();
        _nik = (ibu?['nik'] ?? '').toString();
        _hp = (ibu?['no_hp'] ?? '').toString();
        _balita = balita;
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

  Future<void> _tambahBalita() async {
    final a = await bukaFormBalita(context);
    if (a == null || !mounted) return;
    try {
      await KeluargaAkunApi.tambahBalita(widget.keluargaId, a);
      if (!mounted) return;
      kkSnack(context, 'Data balita berhasil ditambahkan');
      await _muat(diam: true);
    } catch (e) {
      if (mounted) kkSnack(context, kkPesanError(e));
    }
  }

  Future<void> _ubahBalita(IsianBalita awal) async {
    final a = await bukaFormBalita(context, awal: awal);
    if (a == null || !mounted) return;
    try {
      await KeluargaAkunApi.ubahBalita(widget.keluargaId, a);
      if (!mounted) return;
      kkSnack(context, 'Data balita berhasil diubah');
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
              kkKartuPesan(_galat!),
              const SizedBox(height: 12),
              TextButton(onPressed: _muat, child: kkTautan('Coba lagi')),
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
                kkInfo('No. HP', formatNoHp(_hp)),
              ],
            ),
          ),
          Form(
            key: _key,
            child: FormDataKeluarga(isian: _keluarga, nikIbu: _nik),
          ),
          KartuBagian(
            judul: 'Data Balita',
            kanan: '${_balita.length} balita',
            child: Column(
              children: [
                for (final a in _balita) BarisBalita(balita: a, onUbah: () => _ubahBalita(a)),
                const SizedBox(height: 4),
                kkTombolGaris('Tambah Balita', ikon: Icons.add, onPressed: _tambahBalita),
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