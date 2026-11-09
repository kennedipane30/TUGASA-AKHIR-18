import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../core/posyandu.dart';
import '../../core/semua_balita_page.dart';
import '../../core/skdn_page.dart';
import '../../service/balita_service.dart';
import '../../service/skdn_service.dart';
import '../auth/auth_provider.dart';
import 'balita/balita_berisiko_page.dart';
import 'riwayat/bidan_riwayat_page.dart';

// Warna tampilan
const _hijauTua = Color(0xFF0F5A43);
const _hijauGelap = Color(0xFF0B4A38);
const _hijauTeks = Color(0xFF065F46);
const _mint = Color(0xFF8CF0CB);
const _oranye = Color(0xFFFF7A1A);
const _teksGelap = Color(0xFF0F172A);
const _teksAbu = Color(0xFF64748B);
const _teksBiru = Color(0xFF94A3B8);
const _merah = Color(0xFFE11D48);
const _merahMuda = Color(0xFFFFE9ED);
const _biru = Color(0xFF2563EB);
const _biruMuda = Color(0xFFE3EDFF);
const _hijauMuda = Color(0xFFE3F8EE);
const _ungu = Color(0xFF9333EA);
const _kuning = Color(0xFFD97706);
const _teal = Color(0xFF0F766E);

class BidanHome extends StatefulWidget {
  const BidanHome({super.key});

  @override
  State<BidanHome> createState() => _BidanHomeState();
}

class _BidanHomeState extends State<BidanHome> {
  final int _menunggu = 12;
  int? _berisiko;
  SkdnData? _skdn;

  @override
  void initState() {
    super.initState();
    _muatBerisiko();
    _muatSkdn();
  }

  Future<void> _muatSkdn() async {
    try {
      final d = await const SkdnService('/bidan').hitung();
      if (!mounted) return;
      setState(() => _skdn = d);
    } catch (_) {}
  }

  Future<void> _bukaSkdn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SkdnPage(prefix: '/bidan')),
    );
    _muatSkdn();
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
        _pencarian(),
        const SizedBox(height: 14),
        _tugasUtama(),
        const SizedBox(height: 18),
        _menuGrid(),
        const SizedBox(height: 6),
        _indikatorKinerja(),
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
                hintStyle: TextStyle(fontSize: 15, color: _teksAbu),
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
  // Tugas utama
  // -------------------------------------------------------------------------
  Widget _tugasUtama() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_hijauTua, _hijauGelap],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x26054D3A), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              bottom: -48,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('TUGAS UTAMA BIDAN',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$_menunggu Balita Menunggu',
                            style: const TextStyle(
                                color: _mint,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Verifikasi & Kunci Data Antropometri',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                      'Konfirmasi klinis hasil pengukuran kader sebelum disinkronkan ke database nasional.',
                      style: TextStyle(
                          color: Color(0xFFD1FAE5), fontSize: 14, height: 1.5)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x55FF7A1A),
                            blurRadius: 12,
                            offset: Offset(0, 5)),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _oranye,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => soon(context, 'Daftar verifikasi per sesi'),
                      icon: const Icon(Icons.assignment_turned_in_outlined, size: 20),
                      label: Text('Buka Verifikasi ($_menunggu Data)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      aset,
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Icon(cadangan, color: warna, size: 38),
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                judul,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: Color(0xFF0F2547),
                  fontWeight: FontWeight.w800,
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
                      fontSize: 20,
                      height: 1.2,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Layanan Utama',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
                fontSize: 12,
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
      _itemAset('rekap_skdn.png', Icons.assessment_outlined, _teal, 'Rekap\nSKDN', _bukaSkdn),
    ]);
  }

  // -------------------------------------------------------------------------
  // Indikator kinerja (SKDN)
  // -------------------------------------------------------------------------
  String _persen(double v) =>
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}%';

  Widget _indikatorKinerja() {
    final d = _skdn;
    final b = d?.bulan;
    String angka(int? v) => v == null ? '-' : '$v';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDF1F5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E293B), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Color(0xFFE6F8EF), shape: BoxShape.circle),
                child: const Icon(Icons.bar_chart_rounded,
                    size: 19, color: _hijauTeks),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Ringkasan Penimbangan (SKDN)',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: _teksGelap)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => tampilkanPenjelasanSkdn(context),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.info_outline, size: 20, color: _biru),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(b == null ? 'Bulan ini' : b.label,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: _teksAbu)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kotakSkdn(angka(b?.s), 'S', 'Seluruh balita', const Color(0xFFF6F8FB),
                    _teksGelap, const Color(0xFFE9EEF3)),
                const SizedBox(width: 8),
                _kotakSkdn(angka(b?.k), 'K', 'Punya Buku KIA', const Color(0xFFF6F8FB),
                    _teksGelap, const Color(0xFFE9EEF3)),
                const SizedBox(width: 8),
                _kotakSkdn(angka(b?.d), 'D', 'Datang ditimbang', const Color(0xFFE6F8EF),
                    _hijauTeks, const Color(0xFFBDEBD3)),
                const SizedBox(width: 8),
                _kotakSkdn(angka(b?.n), 'N', 'Berat badan naik', const Color(0xFFE9F0FF), _biru,
                    const Color(0xFFC7D8FA)),
              ],
            ),
          ),
          if (b != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chipSkdn('Kehadiran ${_persen(b.persenDS)}',
                    d!.capaiTarget ? _hijauMuda : _merahMuda,
                    d.capaiTarget ? _hijauTeks : _merah),
                _chipSkdn('Tumbuh baik ${_persen(b.persenND)}', _biruMuda, _biru),
                if (d.perluRujuk.isNotEmpty)
                  _chipSkdn('${d.perluRujuk.length} perlu dirujuk', _merahMuda, _merah),
              ],
            ),
          ],
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _bukaSkdn,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F8EF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBDEBD3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 18, color: _hijauTeks),
                  SizedBox(width: 8),
                  Text('Lihat Ringkasan Lengkap',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _hijauTeks)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => soon(context, 'Ekspor laporan bulanan'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download_outlined, size: 18, color: _teksGelap),
                  SizedBox(width: 8),
                  Text('Ekspor Laporan PDF / Excel',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _teksGelap)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipSkdn(String teks, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(teks,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _kotakSkdn(String nilai, String huruf, String label, Color bg, Color fg,
      Color border) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text(nilai,
                style: const TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: _teksGelap)),
            const SizedBox(height: 4),
            Text(huruf,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _teksBiru)),
          ],
        ),
      ),
    );
  }
}