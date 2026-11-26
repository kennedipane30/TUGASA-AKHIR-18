import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/no_hp.dart';
import 'edit_keluarga_page.dart';
import 'keluarga.dart';
import 'tambah_keluarga_page.dart';

/// Menu kader "Data Keluarga":
/// daftar keluarga di posyandu kader + tombol "Tambahkan Akun".
/// Cari: nama ibu, NIK, No. HP, atau nama anak.
class KeluargaPage extends StatefulWidget {
  const KeluargaPage({super.key});

  @override
  State<KeluargaPage> createState() => _KeluargaPageState();
}

class _KeluargaPageState extends State<KeluargaPage> {
  final _cari = TextEditingController();
  Timer? _tunda;
  List<RingkasKeluarga> _data = [];
  bool _memuat = true;
  String? _galat;
  int _permintaan = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  @override
  void dispose() {
    _tunda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final no = ++_permintaan;
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final hasil = await KeluargaAkunApi.cari(_cari.text.trim());
      if (!mounted || no != _permintaan) return;
      setState(() => _data = hasil);
    } catch (e) {
      if (!mounted || no != _permintaan) return;
      setState(() => _galat = kkPesanError(e));
    } finally {
      if (mounted && no == _permintaan) setState(() => _memuat = false);
    }
  }

  void _ketik(String _) {
    _tunda?.cancel();
    _tunda = Timer(const Duration(milliseconds: 450), _muat);
    setState(() {});
  }

  Future<void> _tambah() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TambahKeluargaPage()),
    );
    if (ok == true) _muat();
  }

  Future<void> _buka(RingkasKeluarga k) async {
    if (!k.punyaAkun) {
      kkSnack(context, 'Keluarga ini belum memiliki akun orang tua.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditKeluargaPage(keluargaId: k.keluargaId)),
    );
    _muat();
  }

  Widget _kotakCari() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: TextField(
        controller: _cari,
        onChanged: _ketik,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _muat(),
        decoration: InputDecoration(
          hintText: 'Cari nama ibu, NIK, No. HP, atau nama anak',
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search, color: Colors.black54),
          suffixIcon: _cari.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: kkTeksAbu),
                  onPressed: () {
                    _cari.clear();
                    _muat();
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kkGaris, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kkGaris, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.black54, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _kartu(RingkasKeluarga k) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: kkDekorKartu(),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _buka(k),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kkKepala(k.namaIbu, kanan: '${k.jumlahAnak} anak'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      kkInfo('NIK', k.nik, lebar: 80),
                      kkInfo('No. HP', formatNoHp(k.noHp), lebar: 80),
                      kkInfo('Alamat', k.alamat, lebar: 80),
                      Align(
                        alignment: Alignment.centerRight,
                        child: kkTautan(k.punyaAkun ? 'Lihat detail' : 'Belum ada akun',
                            warna: k.punyaAkun ? kkAksen : kkTeksAbu),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _isi() {
    if (_memuat && _data.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: kkHijau));
    }
    if (_galat != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          kkKartuPesan(_galat!),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _muat, child: kkTautan('Coba lagi'))),
        ],
      );
    }
    if (_data.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          kkKartuPesan(
            _cari.text.trim().isEmpty
                ? 'Belum ada data keluarga.'
                : 'Keluarga tidak ditemukan.\nTambahkan akun bila orang tua belum terdaftar.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _data.length,
      itemBuilder: (_, i) => _kartu(_data[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kkLatar,
      appBar: kkAppBar('Data Keluarga'),
      body: Column(
        children: [
          _kotakCari(),
          if (_memuat && _data.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2, color: kkHijau),
          Expanded(
            child: RefreshIndicator(color: kkHijau, onRefresh: _muat, child: _isi()),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        // Tanpa latar footer: hanya tombol.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: kkTombolHijau('Tambahkan Akun', ikon: Icons.person_add_alt_1_outlined, onPressed: _tambah),
        ),
      ),
    );
  }
}