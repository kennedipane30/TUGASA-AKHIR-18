import 'dart:async';

import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
          prefixIcon: const Icon(Icons.search, color: kkTeksAbu),
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
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kkGarisInput),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kkHijau, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _kartu(RingkasKeluarga k) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _buka(k),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kkGaris),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(k.namaIbu,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: kkTeksGelap)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kkHijauMuda,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${k.jumlahAnak} anak',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: kkHijau)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            kkInfo('NIK', k.nik),
            kkInfo('No. HP', k.noHp),
            kkInfo('Alamat', k.alamat),
          ],
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
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Text(_galat!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: kkTeksAbu)),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _muat,
              child: const Text('Coba lagi',
                  style: TextStyle(color: kkHijau, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }
    if (_data.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Text(
            _cari.text.trim().isEmpty
                ? 'Belum ada data keluarga.'
                : 'Keluarga tidak ditemukan.\nTambahkan akun bila orang tua belum terdaftar.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: kkTeksAbu, height: 1.4),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: kkGaris)),
          ),
          child: ElevatedButton(
            onPressed: _tambah,
            style: ElevatedButton.styleFrom(
              backgroundColor: kkHijau,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tambahkan Akun',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}