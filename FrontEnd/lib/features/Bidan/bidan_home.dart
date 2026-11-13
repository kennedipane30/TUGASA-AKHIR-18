import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/utils/posyandu.dart';
import '../../core/pages/balita/semua_balita_page.dart';
import '../../core/pages/rekap/rekap_posyandu_page.dart';
import '../../service/balita_service.dart';
import '../auth/auth_provider.dart';
import 'balita/balita_berisiko_page.dart';
import 'riwayat/riwayat_page.dart';

// Warna tampilan
const _hijauTeks = Color(0xFF065F46);
const _teksGelap = Color(0xFF0F172A);
const _teksAbu = Color(0xFF64748B);
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

  Widget _sapaan(String nama) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
      child: Text(
        'Hi, $nama',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 21,
          height: 1.2,
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final pos = (user?['posyandu'] ?? '').toString();
    final lokasi = pos.isEmpty
        ? 'Posyandu belum ditetapkan, hubungi admin'
        : 'Wilayah kerja Posyandu ${labelPosyandu(pos)}';

    return HomeShell(
      peran: 'Bidan',
      lokasi: lokasi,
      notif: 4,
      children: [
        _sapaan(_namaSapaan(user)),
        _pencarian(),
        const SizedBox(height: 14),
        _menuGrid(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Pencarian
  // -------------------------------------------------------------------------
  Widget _pencarian() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAEF)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1E293B), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: _teksAbu, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              readOnly: true,
              onTap: () => soon(context, 'Pencarian anak'),
              decoration: const InputDecoration(
                hintText: 'Cari data balita, NIK, atau nama ibu...',
                hintStyle: TextStyle(fontSize: 16, color: _teksAbu),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.filter_alt_outlined, size: 18, color: _teksGelap),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Ikon menu dari assets (gaya sama dengan beranda orang tua)
  // -------------------------------------------------------------------------
  Widget _itemAset(String aset, IconData cadangan, Color warna, String judul,
      VoidCallback onTap, {int? badge, Color badgeWarna = const Color(0xFFE11D48)}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Image.asset(
                      aset,
                      width: 52,
                      height: 52,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Icon(cadangan, color: warna, size: 32),
                    ),
                  ),
                  if (badge != null && badge > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeWarna,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    judul,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      color: Color(0xFF0F2547),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridAset(String judul, String sub, List<Widget> item) {
    final baris = <Widget>[];
    for (var i = 0; i < item.length; i += 4) {
      final potong = item.sublist(i, i + 4 > item.length ? item.length : i + 4);
      baris.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...potong,
              for (var k = potong.length; k < 4; k++) const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    judul,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.2,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Layanan Utama',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.teksRedup,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
            child: Text(
              sub,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: AppColors.teksRedup,
              ),
            ),
          ),
          ...baris,
        ],
      ),
    );
  }

  Widget _menuGrid() {
    return _gridAset('Layanan Bidan', 'Pilih menu pelayanan dan pemantauan balita', [
      _itemAset('deteksi_dini.png', Icons.warning_amber_rounded, _merah, 'Deteksi\nDini',
          _bukaBerisiko, badge: _berisiko, badgeWarna: _merah),
      _itemAset('semua_balita.png', Icons.child_care, _hijauTeks, 'Semua\nBalita', _bukaBalita),
      _itemAset('antropometri.png', Icons.balance_outlined, _biru, 'Antropo-\nmetri',
          () => soon(context, 'Daftar verifikasi per sesi'), badge: 12, badgeWarna: _biru),
      _itemAset('imunisasi.png', Icons.vaccines_outlined, _hijauTeks, 'Imunisasi',
          () => soon(context, 'Pencatatan imunisasi'), badge: 8, badgeWarna: _hijauTeks),
      _itemAset('vitamin_pmt.png', Icons.medication_outlined, _ungu, 'Vitamin\n& PMT',
          () => soon(context, 'Pencatatan suplemen')),
      _itemAset('riwatar_pemeriksaan.png', Icons.history, _teal, 'Riwayat\nPemeriksaan',
          _bukaRiwayat),
      _itemAset('surat_rujukan.png', Icons.description_outlined, _kuning, 'Surat\nRujukan',
          () => soon(context, 'Surat rujukan')),
      _itemAset('rekap_skdn.png', Icons.assessment_outlined, _teal, 'Rekap\nPosyandu', _bukaRekap),
    ]);
  }
}