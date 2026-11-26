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
      trailing: Text('$selesai/2 lengkap',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.kuning)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lengkapi data diri ibu dan data suami/ayah agar jadwal, kartu digital, dan grafik pertumbuhan dapat digunakan.',
            style: TextStyle(fontSize: 15.5, height: 1.4, color: kTeksGelap),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: selesai / 2,
              minHeight: 7,
              backgroundColor: Colors.white,
              color: kHijauHeader,
            ),
          ),
        ],
      ),
    );
  }

  /// Pilihan menu: kotak putih bergaris lembut, judul tebal, tautan "Buka".
  Widget _tombol({
    required String judul,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kGarisKartu, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16, color: kTeksGelap)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(fontSize: 15, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              tautanKeluarga('Buka'),
            ],
          ),
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
            InkWell(onTap: _muat, child: tautanKeluarga('Coba lagi')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_lengkap) _belumLengkap(selesai),
        KartuKeluarga(
          title: 'Kelola Data Keluarga',
          trailing: _lengkap
              ? const Text('Lengkap',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: kHijauHeader))
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih data yang ingin diperbarui.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup)),
              const SizedBox(height: 12),
              _tombol(
                judul: 'Data Orang Tua',
                sub: 'Ibu & Ayah / Wali',
                onTap: _bukaOrtu,
              ),
              const SizedBox(height: 10),
              _tombol(
                judul: _jumlahAnak > 0 ? 'Data Anak ($_jumlahAnak)' : 'Data Anak',
                sub: 'Balita & Tumbuh Kembang',
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