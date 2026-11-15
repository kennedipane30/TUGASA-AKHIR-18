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

// Warna tampilan
const _hijauTua = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);
const _teksAbu = Color(0xFF64748B);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Garis pemisah lembut.
const _garisLembut = Color(0xFFE5E7EB);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = [
  BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 3)),
];

const _namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

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

  @override
  void initState() {
    super.initState();
    _muat();
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
        borderRadius: BorderRadius.circular(16),
        border: border == null ? null : Border.all(color: border),
        boxShadow: _bayangan,
      ),
      child: child,
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
          color: _teksGelap,
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

        if (_memuat)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_gagal != null)
          _kartuGagal()
        else if (j == null)
          _tanpaJadwal()
        else
          _sesiTerdekat(j),

        // Layanan utama kader
        _layananUtama(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Sesi posyandu: kartu putih berbayang, ringkas dan rapi
  // -------------------------------------------------------------------------

  /// Keterangan waktu sesi: "Hari ini", "Besok", "3 hari lagi", atau "Selesai".
  (String, Color) _statusSesi(DateTime tanggal) {
    final n = DateTime.now();
    final hari = DateTime(n.year, n.month, n.day);
    final t = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final selisih = t.difference(hari).inDays;
    if (selisih == 0) return ('Hari ini', _hijauTua);
    if (selisih == 1) return ('Besok', _aksen);
    if (selisih > 1) return ('$selisih hari lagi', _teksAbu);
    return ('Selesai', _teksAbu);
  }

  Widget _barisKet(IconData ikon, String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(ikon, size: 18, color: _aksen),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label : ',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _teksGelap),
                  ),
                  TextSpan(
                    text: nilai.isEmpty ? '-' : nilai,
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 15.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Satu angka ringkasan antrean (angka besar, label kecil di bawahnya).
  Widget _angka(String nilai, String label, Color warna) {
    return Expanded(
      child: Column(
        children: [
          Text(nilai,
              style: TextStyle(fontSize: 22, height: 1.1, fontWeight: FontWeight.w700, color: warna)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _teksAbu)),
        ],
      ),
    );
  }

  Widget _pemisahTegak() => Container(width: 1, height: 36, color: _garisLembut);

  Widget _sesiTerdekat(JadwalTerdekatData j) {
    final (status, warnaStatus) = _statusSesi(j.tanggal);
    final checkin = _antrean.length;
    final diukur = _antrean.where((a) => a.sudahDiukur).length;
    final menunggu = checkin - diukur;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kepala: label kecil, hari & tanggal, status di kanan
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SESI POSYANDU',
                          style: TextStyle(
                              fontSize: 13.5,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: _aksen)),
                      const SizedBox(height: 4),
                      Text(_namaHari[j.tanggal.weekday - 1].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 18,
                              height: 1.2,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w700,
                              color: _teksGelap)),
                      Text(formatTanggal(j.tanggal),
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(status,
                    style: TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700, color: warnaStatus)),
              ],
            ),
          ),
          Container(height: 3, color: _aksen),

          // Waktu & lokasi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                _barisKet(Icons.schedule, 'Waktu', j.jam.isEmpty ? '' : '${j.jam} WIB'),
                _barisKet(Icons.location_on_outlined, 'Lokasi', j.lokasi),
              ],
            ),
          ),

          // Ringkasan antrean
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _garisLembut)),
            ),
            child: Row(
              children: [
                _angka('$checkin', 'Check-in', _teksGelap),
                _pemisahTegak(),
                _angka('$diukur', 'Sudah diukur', _hijauTua),
                _pemisahTegak(),
                _angka('$menunggu', 'Menunggu', menunggu > 0 ? AppColors.kuning : _teksAbu),
              ],
            ),
          ),

          // Tautan ke antrean pendataan
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _bukaAntrean,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Lihat antrean',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _aksen,
                      decoration: TextDecoration.underline,
                      decorationColor: _aksen,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu bila belum ada jadwal aktif.
  Widget _tanpaJadwal() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text('SESI POSYANDU',
                style: TextStyle(
                    fontSize: 16.5,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w700,
                    color: _teksGelap)),
          ),
          Container(height: 3, color: _aksen),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(
              'Belum ada jadwal aktif untuk posyandu Anda. Antrean pendataan muncul setelah admin menerbitkan jadwal.',
              style: TextStyle(fontSize: 15.5, color: _teksAbu, height: 1.4),
            ),
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

  Widget _gridAset(String judul, List<Widget> item) {
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
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...baris,
        ],
      ),
    );
  }

  Widget _layananUtama() {
    return _gridAset('Layanan Kader', [
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
    ]);
  }
}