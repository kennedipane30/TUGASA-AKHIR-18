import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/utils/posyandu.dart';
import '../../core/pages/checkin/qr_checkin_page.dart';
import '../OrangTua/pendaftaran/pendaftaran_page.dart';
import '../../core/pages/balita/semua_balita_page.dart';
import '../auth/auth_provider.dart';
import 'pendataan/pendataan_page.dart';
import 'riwayat/riwayat_page.dart';
import 'rekap/balita_tidak_hadir_page.dart';
import 'vaksin/vaksin_page.dart';
import 'keluarga/keluarga_page.dart';
import 'daftarkan_anak/daftarkan_anak_page.dart';

// Warna tampilan
const _hijauTua = Color(0xFF065F46);
const _teksGelap = Color(0xFF0F172A);
const _teksAbu = Color(0xFF64748B);
const _teksBiru = Color(0xFF7C8DA6);

class KaderHome extends StatefulWidget {
  const KaderHome({super.key});

  @override
  State<KaderHome> createState() => _KaderHomeState();
}

class _KaderHomeState extends State<KaderHome> {
  JadwalTerdekatData? _jadwal;
  List<AntreanKader> _antrean = [];
  bool _memuat = true;
  String? _gagal;

  bool _sinkronBerjalan = false;
  int _tertunda = 0;
  String _sinkronTerakhir = 'baru saja';

  final _cariCtrl = TextEditingController();
  String _kata = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  void _bersihkanCari() {
    _cariCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() => _kata = '');
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      final list = j == null ? <AntreanKader>[] : await AntreanKader.ambil(j.id);
      if (!mounted) return;
      setState(() {
        _jadwal = j;
        _antrean = list;
        _gagal = null;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gagal = 'Gagal memuat data antrean dari server.';
        _memuat = false;
      });
    }
  }

  Future<void> _sinkronkan() async {
    setState(() => _sinkronBerjalan = true);
    await _muat();
    if (!mounted) return;
    setState(() {
      _sinkronBerjalan = false;
      _tertunda = 0;
      _sinkronTerakhir = 'baru saja';
    });
  }

  Future<void> _bukaAntrean() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderPendataanPage()),
    );
    _muat();
  }

  void _bukaQr() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrCheckinPage(role: 'kader')),
    );
  }

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderVaksinPage()),
    );
  }

  void _bukaBalita() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SemuaBalitaPage(prefix: '/kader')),
    );
  }

  void _bukaTidakHadir() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderTidakHadirPage()),
    );
  }

  Future<void> _bukaKeluarga() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KeluargaPage()),
    );
    _muat();
  }

  Future<void> _bukaDaftarkanAnak() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DaftarkanAnakPage()),
    );
    _muat();
  }

  void _bukaRiwayat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderRiwayatPage()),
    );
  }

  // -------------------------------------------------------------------------
  // Komponen umum
  // -------------------------------------------------------------------------
  Widget _kartuPutih({required Widget child, EdgeInsets? padding, Color? color, Color? border}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: border == null ? null : Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E293B), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _kepalaKartu(IconData ikon, String judul, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: Color(0xFFE6F8EF), shape: BoxShape.circle),
          child: Icon(ikon, size: 18, color: _hijauTua),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(judul,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: _teksGelap)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _kartuGagal() {
    return _kartuPutih(
      color: AppColors.kuningMuda,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.kuning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_gagal!,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16.5)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _memuat = true);
              _muat();
            },
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Pencarian
  // -------------------------------------------------------------------------
  Widget _pencarian() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              controller: _cariCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _kata = v.trim()),
              decoration: const InputDecoration(
                hintText: 'Cari nama balita...',
                hintStyle: TextStyle(fontSize: 16, color: _teksAbu),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_kata.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _bersihkanCari,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close_rounded, size: 18, color: _teksGelap),
              ),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _bukaBalita,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.filter_alt_outlined, size: 18, color: _teksGelap),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hasilPencarian() {
    final q = _kata.toLowerCase();
    final hasil = _antrean.where((a) => a.nama.toLowerCase().contains(q)).toList();

    return _kartuPutih(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_search_rounded, size: 22, color: _hijauTua),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Hasil pencarian "$_kata"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w600, color: _teksGelap)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F8EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${hasil.length} anak',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: _hijauTua)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_memuat)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (hasil.isEmpty)
            const Text('Tidak ditemukan di antrean hari ini.',
                style: TextStyle(fontSize: 16.5, height: 1.4, color: _teksBiru))
          else
            for (final a in hasil) _barisHasil(a),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _hijauTua,
                side: const BorderSide(color: Color(0xFFB9EBD2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _bukaBalita,
              icon: const Icon(Icons.child_care, size: 20),
              label: const Text('Cari di Semua Balita',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisHasil(AntreanKader a) {
    final usia = a.usiaBulan >= 12
        ? '${a.usiaBulan ~/ 12} th ${a.usiaBulan % 12} bln'
        : '${a.usiaBulan} bln';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _bukaAntrean,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9EEF3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE6F8EF),
              child: Text(a.nomor?.toString() ?? '-',
                  style: const TextStyle(color: _hijauTua, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16, color: _teksGelap)),
                  const SizedBox(height: 2),
                  Text('${a.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · $usia',
                      style: const TextStyle(fontSize: 15.5, color: _teksAbu)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: a.sudahDiukur ? const Color(0xFFE6F5EC) : const Color(0xFFFFEFDD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(a.sudahDiukur ? 'Sudah diukur' : 'Menunggu',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: a.sudahDiukur ? _hijauTua : const Color(0xFFB45309))),
            ),
          ],
        ),
      ),
    );
  }

  /// Nama depan pengguna yang login, huruf kapital (mis. "KENNEDI").
  String _namaSapaan(Map? user) {
    final nama = (user?['nama'] ?? '').toString().trim();
    if (nama.isEmpty) return 'KADER';
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
        : 'Posyandu ${labelPosyandu(pos)}';

    final j = _jadwal;

    return HomeShell(
      peran: 'Kader',
      lokasi: lokasi,
      notif: 3,
      children: [
        // Sapaan
        _sapaan(_namaSapaan(user)),

        // Pencarian
        _pencarian(),
        if (_kata.isNotEmpty) _hasilPencarian(),

        if (_memuat)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_gagal != null)
          _kartuGagal()
        else if (j == null)
          _kartuPutih(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kepalaKartu(Icons.event_busy, 'Jadwal $lokasi'),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada jadwal aktif untuk posyandu Anda. Antrean pendataan muncul setelah admin menerbitkan jadwal.',
                  style: TextStyle(fontSize: 16, color: _teksAbu, height: 1.4),
                ),
              ],
            ),
          )
        else
          _sesiTerdekat(j),

        // Layanan utama kader
        _layananUtama(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Sesi terdekat
  // -------------------------------------------------------------------------
  Widget _sesiTerdekat(JadwalTerdekatData j) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9FBF3), Color(0xFFD7F7E8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB9EBD2)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month_outlined,
                color: _hijauTua, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SESI POSYANDU TERDEKAT',
                    style: TextStyle(
                        fontSize: 15,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                        color: _hijauTua)),
                const SizedBox(height: 2),
                Text(formatTanggal(j.tanggal),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600, color: _teksGelap)),
                if (j.lokasi.isNotEmpty)
                  Text(j.lokasi,
                      style: const TextStyle(fontSize: 16, color: _teksAbu)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(j.jam.replaceAll(' - ', ' -\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: _teksGelap)),
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

  Widget _layananUtama() {
    return _gridAset('Layanan Kader', 'Pilih menu pendataan balita di posyandu', [
      _itemAset('qr_chekin.png', Icons.qr_code_2_rounded, const Color(0xFF1D6FD6),
          'QR\nCheck-in', _bukaQr),
      _itemAset('ukur_data.png', Icons.calendar_view_week_rounded, const Color(0xFF0B6B55),
          'Ukur Data\nBB TB LiLA', _bukaAntrean),
      _itemAset('semua_balita.png', Icons.child_care, const Color(0xFFEA580C),
          'Semua\nBalita', _bukaBalita),
      _itemAset('riwatar_pemeriksaan.png', Icons.history, const Color(0xFF0E8F7E),
          'Riwayat\nPemeriksaan', _bukaRiwayat),
      _itemAset('balita_tidak_hadir.png', Icons.person_search_outlined,
          const Color(0xFFB45309), 'Balita\nTidak Hadir', _bukaTidakHadir),
      _itemAset('vaksin_anak.png', Icons.vaccines_outlined, const Color(0xFF0B7FBF),
          'Vaksin\nAnak', _bukaVaksin),
      _itemAset('data_keluarga.png', Icons.family_restroom_outlined,
          const Color(0xFF7C3AED), 'Data\nKeluarga', _bukaKeluarga),
      _itemAset('daftarkan_anak.png', Icons.how_to_reg_outlined, const Color(0xFF0E7490),
          'Daftarkan\nAnak', _bukaDaftarkanAnak),
    ]);
  }
}