import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'jadwal/admin_jadwal_page.dart';
import 'riwayat/admin_riwayat_page.dart';
import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../core/qr_checkin_page.dart';
import '../auth/auth_provider.dart';
import 'akun/admin_kelola_akun_page.dart';
import '../../core/semua_balita_page.dart';
import '../../core/skdn_page.dart';
import '../../service/skdn_service.dart';
import 'rekap/admin_rekap_page.dart';
import 'vaksin/admin_vaksin_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  // Status sinkronisasi (AD-03 poin 5). Ganti dengan data dari service sinkron.
  bool _sinkronBerjalan = false;
  int _tertunda = 3;
  String _sinkronTerakhir = '10 menit lalu';

  // Tugas tertunda (AD-02 reset sandi, AD-06 koreksi data).
  final List<(String, String, String)> _tugas = [
    ('Reset sandi', 'Ibu Rahmawati (orang tua) meminta reset kata sandi', 'Setujui'),
    ('Koreksi NIK', 'Aisyah Putri: pengajuan koreksi NIK dari orang tua', 'Periksa'),
  ];

  // Ringkasan penimbangan (SKDN) bulan berjalan.
  SkdnData? _skdn;
  bool _skdnMemuat = true;

  @override
  void initState() {
    super.initState();
    _muatSkdn();
  }

  Future<void> _muatSkdn() async {
    try {
      final d = await const SkdnService('/sekretaris').hitung();
      if (!mounted) return;
      setState(() {
        _skdn = d;
        _skdnMemuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _skdnMemuat = false);
    }
  }

  Future<void> _bukaSkdn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SkdnPage(prefix: '/sekretaris')),
    );
    _muatSkdn();
  }

  Future<void> _sinkronkan() async {
    setState(() => _sinkronBerjalan = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _sinkronBerjalan = false;
      _tertunda = 0;
      _sinkronTerakhir = 'baru saja';
    });
  }

  void _selesaikanTugas(int i) {
    final judul = _tugas[i].$1;
    // Ganti dengan pemanggilan API (reset sandi / tinjau koreksi).
    setState(() => _tugas.removeAt(i));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$judul diproses (contoh tampilan)')));
  }

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminVaksinPage()),
    );
  }

  void _bukaRekap([int tab = 0]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminRekapPage(tabAwal: tab)),
    );
  }

  void _bukaBalita() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SemuaBalitaPage(prefix: '/sekretaris')),
    );
  }

  void _bukaJadwal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminJadwalPage()),
    );
  }

  void _bukaRiwayat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminRiwayatPage()),
    );
  }

  void _bukaAkun() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const AdminKelolaAkunPage(denganTombolKembali: true)),
    );
  }

  void _bukaQr() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrCheckinPage(role: 'sekretaris')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final nama = _namaSapaan(user);
    final desa = (user?['posyandu_nama'] ?? '').toString();
    final labelDesa = desa.isEmpty ? 'Posyandu' : 'Posyandu $desa';

    return HomeShell(
      peran: 'Sekretaris',
      lokasi: labelDesa,
      notif: _tugas.length,
      children: [
        // Sapaan
        _sapaan(nama),

        // Aksi cepat (ikon dari assets)
        _gridAset('Layanan Sekretaris', 'Kelola data, jadwal, dan laporan posyandu', [
          _itemAset('kelola_akun.png', Icons.manage_accounts, AppColors.hijau,
              'Kelola\nAkun', _bukaAkun),
          _itemAset('jadwal.png', Icons.calendar_month, AppColors.hijau,
              'Jadwal &\nAgenda', _bukaJadwal),
          _itemAset('riwatar_pemeriksaan.png', Icons.history, AppColors.hijau,
              'Riwayat\nPemeriksaan', _bukaRiwayat),
          _itemAset('qr_chekin.png', Icons.qr_code_2, AppColors.hijau,
              'QR\nCheck-in', _bukaQr),
          _itemAset('vaksin_anak.png', Icons.vaccines_outlined, AppColors.hijau,
              'Data\nVaksin', _bukaVaksin),
          _itemAset('pengumuman.png', Icons.campaign_outlined, AppColors.hijau,
              'Pengumuman', () => soon(context, 'Pengumuman')),
          _itemAset('semua_balita.png', Icons.child_care, AppColors.hijau,
              'Semua\nBalita', _bukaBalita),
          _itemAset('data_master.png', Icons.dataset_outlined, AppColors.hijau,
              'Data\nMaster', () => soon(context, 'Data master')),
          _itemAset('rekap_posyandu.png', Icons.summarize_outlined, AppColors.hijau,
              'Rekap\nPosyandu', () => _bukaRekap(0)),
          _itemAset('rekap_skdn.png', Icons.analytics_outlined, AppColors.hijau,
              'Ringkasan\nPenimbangan', _bukaSkdn),
        ]),
      ],
    );
  }

  /// Nama depan pengguna yang login, huruf kapital (mis. "KENNEDI").
  String _namaSapaan(Map? user) {
    final nama = (user?['nama'] ?? '').toString().trim();
    if (nama.isEmpty) return 'SEKRETARIS';
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
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
                  fontSize: 14,
                  height: 1.2,
                  color: Color(0xFF0F2547),
                  fontWeight: FontWeight.w600,
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
}