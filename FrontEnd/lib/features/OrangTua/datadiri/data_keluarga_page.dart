import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
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

  Widget _status(int selesai) {
    if (_lengkap) {
      return const KartuKeluarga(
        color: Color(0xFFE3F6EC),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: kHijauGelap),
            SizedBox(width: 10),
            Expanded(
              child: Text('Data keluarga sudah lengkap',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: kHijauTua)),
            ),
          ],
        ),
      );
    }
    return KartuKeluarga(
      color: AppColors.kuningMuda,
      title: 'Lengkapi Data Keluarga',
      icon: Icons.assignment_ind_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Text('$selesai/2',
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.kuning)),
      ),
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
    required IconData icon,
    required bool terisi,
    required VoidCallback onTap,
  }) {
    final fg = terisi ? Colors.white : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: terisi ? kHijauTua : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kHijauTua, width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: terisi
                    ? Colors.white.withOpacity(.15)
                    : const Color(0xFFD7F0E3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 22, color: terisi ? Colors.white : kHijauTua),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14, color: fg)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: terisi
                              ? const Color(0xFFA8F0C6)
                              : AppColors.teksRedup)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: terisi
                    ? Colors.white.withOpacity(.15)
                    : const Color(0xFFD7F0E3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right,
                  size: 18, color: terisi ? Colors.white : kHijauTua),
            ),
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
        KartuKeluarga(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_outline, size: 22, color: kHijauTua),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kelola Data Keluarga',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: kHijauTua)),
                      Text('Pilih berkas profil yang ingin diperbarui',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.teksRedup)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _tombol(
                judul: 'Data Orang Tua',
                sub: 'Ibu & Ayah / Wali',
                icon: Icons.person_add_alt_1_outlined,
                terisi: true,
                onTap: _bukaOrtu,
              ),
              const SizedBox(height: 10),
              _tombol(
                judul:
                    _jumlahAnak > 0 ? 'Data Anak ($_jumlahAnak)' : 'Data Anak',
                sub: 'Balita & Tumbuh Kembang',
                icon: Icons.sentiment_satisfied_alt_outlined,
                terisi: false,
                onTap: _bukaAnak,
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F6EC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFE5D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: kHijauGelap),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data keluarga tersimpan aman secara terenkripsi di perangkat Anda dan otomatis disinkronkan ke server Posyandu Care saat terhubung internet.',
                  style: TextStyle(fontSize: 11, color: kHijauGelap),
                ),
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
          const HeaderKeluarga(judul: 'Lengkapi Data Keluarga'),
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