import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../core/posyandu.dart';
import '../auth/auth_provider.dart';

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
const _unguMuda = Color(0xFFF1E6FF);
const _kuning = Color(0xFFD97706);
const _kuningMuda = Color(0xFFFFF3D6);
const _teal = Color(0xFF0F766E);
const _tealMuda = Color(0xFFDDF6F2);

class _Menu {
  final IconData ikon;
  final String judul;
  final String sub;
  final Color bg;
  final Color fg;
  final int? badge;
  final Color badgeWarna;
  final VoidCallback onTap;
  const _Menu(this.ikon, this.judul, this.sub, this.bg, this.fg, this.badge,
      this.badgeWarna, this.onTap);
}

class BidanHome extends StatefulWidget {
  const BidanHome({super.key});

  @override
  State<BidanHome> createState() => _BidanHomeState();
}

class _BidanHomeState extends State<BidanHome> {
  final int _menunggu = 12;

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
        _judulMenu(),
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
                hintStyle: TextStyle(fontSize: 13, color: _teksAbu),
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
                                fontSize: 10.5,
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
                                fontSize: 11.5,
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
                          color: Color(0xFFD1FAE5), fontSize: 12, height: 1.5)),
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
                              fontWeight: FontWeight.w800, fontSize: 14)),
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
  // Menu & layanan
  // -------------------------------------------------------------------------
  Widget _judulMenu() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text('MENU & LAYANAN BIDAN',
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: _teksAbu)),
          ),
          Text('Akses Cepat',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: _teksGelap)),
        ],
      ),
    );
  }

  Widget _menuGrid() {
    final menu = <_Menu>[
      _Menu(Icons.warning_amber_rounded, 'Deteksi Dini', 'Stunting & Gizi',
          _merahMuda, _merah, 10, _merah,
          () => soon(context, 'Daftar prioritas anak berisiko')),
      _Menu(Icons.balance_outlined, 'Antropometri', 'Validasi BB/TB', _biruMuda,
          _biru, 12, _biru, () => soon(context, 'Daftar verifikasi per sesi')),
      _Menu(Icons.science_outlined, 'Imunisasi', '8 Terjadwal', _hijauMuda,
          _hijauTeks, 8, _hijauTeks, () => soon(context, 'Pencatatan imunisasi')),
      _Menu(Icons.science_outlined, 'Vitamin & PMT', 'Kapsul & Biskuit',
          _unguMuda, _ungu, null, _ungu,
          () => soon(context, 'Pencatatan suplemen')),
      _Menu(Icons.description_outlined, 'Surat Rujukan', 'Ke Puskesmas',
          _kuningMuda, _kuning, null, _kuning,
          () => soon(context, 'Surat rujukan')),
      _Menu(Icons.assessment_outlined, 'Rekap SKDN', 'Ekspor Data', _tealMuda,
          _teal, null, _teal, () => soon(context, 'Ekspor laporan bulanan')),
    ];

    final baris = <Widget>[];
    for (var i = 0; i < menu.length; i += 3) {
      final potong = menu.sublist(i, i + 3 > menu.length ? menu.length : i + 3);
      baris.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < potong.length; k++) ...[
                if (k > 0) const SizedBox(width: 10),
                Expanded(child: _itemMenu(potong[k])),
              ],
              for (var k = potong.length; k < 3; k++) ...[
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
              ],
            ],
          ),
        ),
      ));
    }
    return Column(children: baris);
  }

  Widget _itemMenu(_Menu m) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDF1F5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E293B), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: m.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 14),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: m.bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(m.ikon, color: m.fg, size: 26),
                    ),
                    const SizedBox(height: 12),
                    Text(m.judul,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _teksGelap)),
                    const SizedBox(height: 3),
                    Text(m.sub,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10.5, color: _teksBiru)),
                  ],
                ),
              ),
              if (m.badge != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.badgeWarna,
                      shape: m.badge! < 10 ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius:
                          m.badge! < 10 ? null : BorderRadius.circular(12),
                    ),
                    child: Text('${m.badge}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Indikator kinerja (SKDN)
  // -------------------------------------------------------------------------
  Widget _indikatorKinerja() {
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
                child: Text('Indikator Kinerja Posyandu (SKDN)',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _teksGelap)),
              ),
              const Text('Bulan Ini',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _teksAbu)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _skdn('348', 'S', 'Sasaran', const Color(0xFFF6F8FB),
                    _teksGelap, const Color(0xFFE9EEF3)),
                const SizedBox(width: 8),
                _skdn('348', 'K', 'Punya KMS', const Color(0xFFF6F8FB),
                    _teksGelap, const Color(0xFFE9EEF3)),
                const SizedBox(width: 8),
                _skdn('308', 'D', 'Ditimbang', const Color(0xFFE6F8EF),
                    _hijauTeks, const Color(0xFFBDEBD3)),
                const SizedBox(width: 8),
                _skdn('274', 'N', 'Naik BB', const Color(0xFFE9F0FF), _biru,
                    const Color(0xFFC7D8FA)),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
                          fontSize: 12.5,
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

  Widget _skdn(String nilai, String huruf, String label, Color bg, Color fg,
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
                    fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: _teksBiru)),
          ],
        ),
      ),
    );
  }
}