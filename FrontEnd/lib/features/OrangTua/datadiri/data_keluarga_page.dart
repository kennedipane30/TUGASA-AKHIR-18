import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'data_anak_page.dart';
import 'data_orang_tua_page.dart';

export 'data_orang_tua_page.dart' show DataAnak, DataKeluarga, KeluargaApi;

// ---------------------------------------------------------------------------
// KARTU LENGKAPI DATA KELUARGA
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

  /// Kartu kuning bila data orang tua belum lengkap.
  Widget _belumLengkap(int selesai) {
    return KartuKeluarga(
      color: AppColors.kuningMuda,
      title: 'Data Keluarga',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Text('$selesai/2',
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.kuning)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lengkapi data diri ibu dan data suami/ayah agar jadwal, kartu digital, dan grafik pertumbuhan dapat digunakan.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: selesai / 2,
              minHeight: 7,
              backgroundColor: Colors.white,
              color: kHijauGelap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tombol({
    required String judul,
    required String sub,
    required bool terisi,
    required VoidCallback onTap,
  }) {
    final fg = terisi ? Colors.white : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: terisi ? kHijauTua : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kHijauTua, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16, color: fg)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: terisi
                        ? const Color(0xFFA8F0C6)
                        : AppColors.teksRedup)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selesai = _selesai;

    if (selesai == null) {
      if (!_gagal) return const SizedBox.shrink();
      return KartuKeluarga(
        color: AppColors.kuningMuda,
        child: Row(
          children: [
            const Expanded(
              child: Text('Gagal memuat data keluarga',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15.5)),
            ),
            TextButton(onPressed: _muat, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_lengkap) _belumLengkap(selesai),
        KartuKeluarga(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kelola Data Keluarga',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: kHijauTua)),
              const SizedBox(height: 2),
              const Text('Pilih berkas profil yang ingin diperbarui',
                  style:
                      TextStyle(fontSize: 15.5, color: AppColors.teksRedup)),
              if (_lengkap) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F6EC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFE5D0)),
                  ),
                  child: const Text('Data keluarga sudah lengkap',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.5,
                          color: kHijauTua)),
                ),
              ],
              const SizedBox(height: 14),
              _tombol(
                judul: 'Data Orang Tua',
                sub: 'Ibu & Ayah / Wali',
                terisi: true,
                onTap: _bukaOrtu,
              ),
              const SizedBox(height: 10),
              _tombol(
                judul:
                    _jumlahAnak > 0 ? 'Data Anak ($_jumlahAnak)' : 'Data Anak',
                sub: 'Balita & Tumbuh Kembang',
                terisi: false,
                onTap: _bukaAnak,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// HALAMAN LENGKAPI DATA KELUARGA
// ---------------------------------------------------------------------------
class DataKeluargaPage extends StatelessWidget {
  const DataKeluargaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      body: Column(
        children: [
          const HeaderKeluarga(judul: 'Data Keluarga'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: const [
                KartuLengkapiKeluarga(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}