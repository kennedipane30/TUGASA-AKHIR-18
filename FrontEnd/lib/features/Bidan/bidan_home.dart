import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/common_widgets.dart';
import '../../core/utils/posyandu.dart';
import '../../core/pages/balita/semua_balita_page.dart';
import '../../core/pages/rekap/rekap_posyandu_page.dart';
import 'laporan_bulanan/laporan_bulanan_page.dart';
import '../../service/balita_service.dart';
import '../auth/auth_provider.dart';
import 'balita/balita_berisiko_page.dart';
import 'riwayat/riwayat_page.dart';
import 'rujukan/rujukan_page.dart';

// Warna tampilan
const _hijauTeks = Color(0xFF065F46);
const _merah = Color(0xFFE11D48);
const _biru = Color(0xFF2563EB);
const _ungu = Color(0xFF9333EA);
const _kuning = Color(0xFFD97706);
const _teal = Color(0xFF0F766E);

class BidanHome extends StatefulWidget {
  const BidanHome({super.key});

  @override
  State<BidanHome> createState() => _BidanHomeState();
}

class _BidanHomeState extends State<BidanHome> {
  int? _berisiko;

  @override
  void initState() {
    super.initState();
    _muatBerisiko();
  }

  void _bukaRekap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RekapPosyanduPage(prefix: '/bidan')),
    );
  }

  void _bukaRujukan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BidanRujukanPage()),
    );
  }

  void _bukaLaporanBulanan() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const BidanLaporanBulananPage()),
    );
  }

  Future<void> _muatBerisiko() async {
    try {
      final d = await const BalitaService('/bidan').berisiko();
      if (!mounted) return;
      setState(() => _berisiko = d.ringkas.total);
    } catch (_) {}
  }

  Future<void> _bukaBerisiko() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BalitaBerisikoPage()),
    );
    _muatBerisiko();
  }

  void _bukaBalita() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SemuaBalitaPage(prefix: '/bidan', bisaKelolaVaksin: true),
      ),
    );
  }

  void _bukaRiwayat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BidanRiwayatPage()),
    );
  }

  /// Nama depan pengguna yang login, huruf kapital (mis. "KENNEDI").
  String _namaSapaan(Map? user) {
    final nama = (user?['nama'] ?? '').toString().trim();
    if (nama.isEmpty) return 'BIDAN';
    return nama.split(RegExp(r'\s+')).first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final pos = (user?['posyandu'] ?? '').toString();
    final lokasi = pos.isEmpty
        ? 'Posyandu belum ditetapkan'
        : 'Posyandu ${labelPosyandu(pos)}';

    return HomeShell(
      peran: 'Bidan',
      lokasi: lokasi,
      sapaan: _namaSapaan(user),
      kartuUtama: _kartuDeteksiDini(lokasi),
      children: [
        _menuGrid(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // KARTU STATUS: ringkasan balita yang perlu perhatian bidan
  // -------------------------------------------------------------------------
  Widget _kartuDeteksiDini(String lokasi) {
    final n = _berisiko;

    if (n == null) {
      return const KartuHome(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final aman = n == 0;
    return KartuHome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KepalaKartuHome(
            ikon: Icons.monitor_heart_outlined,
            judul: 'Deteksi Dini',
            lencana: aman
                ? const LencanaStatusHome(teks: 'Aman')
                : LencanaStatusHome.jenis('bahaya', 'Perlu tindakan'),
          ),
          const SizedBox(height: 16),
          BarisInfoHome(
            Icons.warning_amber_rounded,
            'Berisiko',
            aman ? 'Tidak ada balita berisiko' : '$n balita perlu perhatian',
            warnaNilai: aman ? null : _merah,
          ),
          BarisInfoHome(Icons.place_outlined, 'Wilayah', lokasi),
          BarisInfoHome(Icons.today_rounded, 'Diperbarui', 'Saat halaman dibuka'),
          const SizedBox(height: 4),
          TombolUtamaHome(
            label: aman ? 'Lihat Semua Balita' : 'Lihat Balita Berisiko',
            ikon: aman ? Icons.child_care : Icons.priority_high_rounded,
            onTap: aman ? _bukaBalita : _bukaBerisiko,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // GRID LAYANAN (ikon memakai gambar yang sudah ada)
  // -------------------------------------------------------------------------
  Widget _menuGrid() {
    return GridLayananHome(
      judul: 'Layanan Bidan',
      item: [
        ItemLayananHome(
          aset: 'deteksi_dini.png',
          cadangan: Icons.warning_amber_rounded,
          warna: _merah,
          judul: 'Deteksi\nDini',
          onTap: _bukaBerisiko,
          badge: _berisiko,
          badgeWarna: _merah,
        ),
        ItemLayananHome(
          aset: 'semua_balita.png',
          cadangan: Icons.child_care,
          warna: _hijauTeks,
          judul: 'Semua\nBalita',
          onTap: _bukaBalita,
        ),
        ItemLayananHome(
          aset: 'antropometri.png',
          cadangan: Icons.balance_outlined,
          warna: _biru,
          judul: 'Antropo-\nmetri',
          onTap: () => soon(context, 'Daftar verifikasi per sesi'),
        ),
        ItemLayananHome(
          aset: 'imunisasi.png',
          cadangan: Icons.vaccines_outlined,
          warna: _hijauTeks,
          judul: 'Imunisasi',
          onTap: () => soon(context, 'Pencatatan imunisasi'),
        ),
        ItemLayananHome(
          aset: 'vitamin_pmt.png',
          cadangan: Icons.medication_outlined,
          warna: _ungu,
          judul: 'Vitamin\n& PMT',
          onTap: () => soon(context, 'Pencatatan suplemen'),
        ),
        ItemLayananHome(
          aset: 'riwatar_pemeriksaan.png',
          cadangan: Icons.history,
          warna: _teal,
          judul: 'Riwayat\nPemeriksaan',
          onTap: _bukaRiwayat,
        ),
        ItemLayananHome(
          aset: 'surat_rujukan.png',
          cadangan: Icons.description_outlined,
          warna: _kuning,
          judul: 'Surat\nRujukan',
          onTap: _bukaRujukan,
        ),
        ItemLayananHome(
          aset: 'rekap_skdn.png',
          cadangan: Icons.assessment_outlined,
          warna: _teal,
          judul: 'Rekap\nPosyandu',
          onTap: _bukaRekap,
        ),
        ItemLayananHome(
          aset: 'laporan_bulanan.png',
          cadangan: Icons.picture_as_pdf_outlined,
          warna: _teal,
          judul: 'Laporan\nBulanan',
          onTap: _bukaLaporanBulanan,
        ),
      ],
    );
  }
}