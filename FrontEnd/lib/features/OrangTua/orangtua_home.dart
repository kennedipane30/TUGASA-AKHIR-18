import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../core/posyandu.dart';
import '../../core/status_gizi_widget.dart';
import '../auth/auth_provider.dart';
import 'bukupanduan/buku_panduan_page.dart';
import 'datadiri/data_keluarga_page.dart';
import 'pendaftaran/orangtua_pendaftaran_page.dart';
import 'riwayat/orangtua_grafik_page.dart';
import 'riwayat/orangtua_pemeriksaan_page.dart';
import 'vaksin/orangtua_vaksin_page.dart';

const _mint = Color(0xFF8CF0CB);
const _hijauTeks = Color(0xFF065F46);
const _aset = '';

// Warna kartu jadwal
const _kartuAwal = Color(0xFF0D5C48);
const _kartuAkhir = Color(0xFF0A3A36);
const _kuningLabel = Color(0xFFFDE68A);
const _kuningTitik = Color(0xFFFACC15);
const _merahLabel = Color(0xFFFECDD3);
const _tombolAwal = Color(0xFFF7821B);
const _tombolAkhir = Color(0xFFD4A51C);

DateTime _tambahBulan(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final akhir = DateTime.utc(y, m + 1, 0).day;
  return DateTime.utc(y, m, d.day > akhir ? akhir : d.day);
}

/// Usia detail dari tanggal lahir "dd/mm/yyyy":
/// "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan", "2 tahun".
String _usiaAnak(String tgl) {
  final p = tgl.split('/');
  if (p.length != 3) return '-';

  final d = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return '-';

  final n = DateTime.now();
  final a = DateTime.utc(y, m, d);
  final b = DateTime.utc(n.year, n.month, n.day);
  if (b.isBefore(a)) return '0 hari';

  var bulan = (b.year - a.year) * 12 + b.month - a.month;
  if (_tambahBulan(a, bulan).isAfter(b)) bulan--;
  final hari = b.difference(_tambahBulan(a, bulan)).inDays;
  final tahun = bulan ~/ 12;
  final sisa = bulan % 12;

  if (bulan == 0) return '$hari hari';
  if (tahun == 0) return hari == 0 ? '$bulan bulan' : '$bulan bulan $hari hari';
  return sisa == 0 ? '$tahun tahun' : '$tahun tahun $sisa bulan';
}

String _kapital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _namaHari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

class OrangTuaHome extends StatefulWidget {
  const OrangTuaHome({super.key});

  @override
  State<OrangTuaHome> createState() => _OrangTuaHomeState();
}

class _OrangTuaHomeState extends State<OrangTuaHome> {
  int _aktif = 0;
  List<DataAnak> _daftar = [];
  bool _memuat = true;
  String? _gagal;
  JadwalTerdekatData? _jadwal;
  final _kunciGizi = GlobalKey<KartuPeringatanGiziState>();

  DataAnak? get _anak => _daftar.isEmpty ? null : _daftar[_aktif];

  AnakStatusJadwal? _statusAnakDari(DataAnak a) {
    final j = _jadwal;
    if (j == null) return null;

    for (final s in j.anak) {
      if (s.anakId == a.id) return s;
    }
    return null;
  }

  AnakStatusJadwal? get _statusAnak {
    final a = _anak;
    if (a == null) return null;
    return _statusAnakDari(a);
  }

  String get _hadir => _statusAnak?.status ?? 'belum_daftar';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    _kunciGizi.currentState?.muatUlang();
    JadwalTerdekatData? jadwal;
    try {
      jadwal = await JadwalTerdekatData.ambil();
    } catch (_) {
      jadwal = null;
    }

    try {
      final data = await KeluargaApi.ambil();
      final daftar = ((data['anak'] as List?) ?? [])
          .map((e) => DataAnak.fromApi(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (!mounted) return;
      setState(() {
        _daftar = daftar;
        _jadwal = jadwal;
        if (_aktif >= daftar.length) _aktif = 0;
        _gagal = null;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gagal = 'Gagal memuat data anak dari server.';
        _memuat = false;
      });
    }
  }

  Future<void> _bukaPendaftaran() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrangTuaPendaftaranPage(),
      ),
    );
    _muat();
  }

  void _bukaBukuPanduan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BukuPanduanPage()),
    );
  }

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrangTuaVaksinPage()),
    );
  }

  void _bukaPemeriksaan() {
    final a = _anak;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaPemeriksaanPage(
          anakId: a?.id?.toString(),
        ),
      ),
    );
  }

  void _bukaPemeriksaanAnak(String anakId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaPemeriksaanPage(anakId: anakId),
      ),
    );
  }

  void _bukaGrafik() {
    final a = _anak;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaGrafikPage(
          anakId: a?.id?.toString(),
        ),
      ),
    );
  }

  Future<void> _bukaDataKeluarga() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DataKeluargaPage(),
      ),
    );
    _muat();
  }

  /// Nama depan pengguna yang login, huruf kapital (mis. "KENNEDI").
  String _namaSapaan(Map? user) {
    final nama = (user?['nama'] ?? '').toString().trim();
    if (nama.isEmpty) return 'BUNDA';
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
          fontSize: 20,
          height: 1.2,
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
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

    return HomeShell(
      peran: 'Orang Tua',
      lokasi: lokasi,
      notif: 2,
      children: [
        _sapaan(_namaSapaan(user)),
        if (_memuat)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_gagal != null)
          _kartuGagal()
        else if (_daftar.isEmpty)
          _kartuBelumAdaAnak()
        else ...[
          KartuPeringatanGizi(
            key: _kunciGizi,
            onLihat: _bukaPemeriksaanAnak,
          ),
          _jadwalPosyandu(),
          _layananPosyandu(),
          _tipsHariIni(),
        ],
      ],
    );
  }

  Widget _kartuGagal() {
    return SectionCard(
      color: AppColors.kuningMuda,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.kuning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _gagal!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
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

  Widget _kartuBelumAdaAnak() {
    return SectionCard(
      title: 'Data Anak',
      icon: Icons.child_care,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Belum ada data anak. Lengkapi data keluarga terlebih dahulu.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.teksRedup,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              'Lengkapi Data Keluarga',
              icon: Icons.family_restroom,
              onPressed: _bukaDataKeluarga,
            ),
          ),
        ],
      ),
    );
  }

  void _pilihAnakSheet() {
    if (_daftar.length < 2) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Pilih Anak',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < _daftar.length; i++)
              ListTile(
                leading: Icon(
                  i == _aktif
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: i == _aktif
                      ? AppColors.hijau
                      : AppColors.teksRedup,
                ),
                title: Text(
                  _daftar[i].nama,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_usiaAnak(_daftar[i].tglLahir)),
                onTap: () {
                  setState(() => _aktif = i);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // KARTU JADWAL POSYANDU TERDEKAT
  // -------------------------------------------------------------------------
  Widget _kartuGelap({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kartuAwal, _kartuAkhir],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40054D3A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x3334D399), Color(0x0034D399)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -70,
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x2267E8F9), Color(0x0067E8F9)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kotakDalam({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _pilKecil(
    String teks, {
    required Color bg,
    required Color border,
    required Color fg,
    Color? titik,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titik != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: titik, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            teks,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _judulKartu({required List<Widget> kanan}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: const Icon(
            Icons.calendar_today_outlined,
            color: _mint,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Jadwal Posyandu Terdekat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ...kanan,
      ],
    );
  }

  Widget _tombolDaftar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: const LinearGradient(
          colors: [_tombolAwal, _tombolAkhir],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44F7821B),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: _bukaPendaftaran,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Buka Pendaftaran & Check-in',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _jadwalPosyandu() {
    final j = _jadwal;
    final pos = (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();
    final (labelStatus, _, _) = labelStatusHadir(_hadir);
    final belumDaftar = _hadir == 'belum_daftar';

    final pilStatus = _pilKecil(
      labelStatus,
      bg: belumDaftar ? const Color(0x33F43F5E) : const Color(0x3334D399),
      border: belumDaftar ? const Color(0x55F43F5E) : const Color(0x5534D399),
      fg: belumDaftar ? _merahLabel : _mint,
    );

    if (j == null) {
      return _kartuGelap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judulKartu(kanan: const []),
            const SizedBox(height: 10),
            _kotakDalam(
              child: Text(
                pos.isEmpty
                    ? 'Belum ada jadwal posyandu mendatang.'
                    : 'Belum ada jadwal mendatang untuk Posyandu ${labelPosyandu(pos)}.',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final hariIni = DateTime.now();
    final selisih = DateTime(j.tanggal.year, j.tanggal.month, j.tanggal.day)
        .difference(DateTime(hariIni.year, hariIni.month, hariIni.day))
        .inDays;
    final hitung = selisih <= 0 ? 'Hari ini' : 'H-$selisih Hari';
    final hari = _namaHari[j.tanggal.weekday - 1];
    // Lokasi dan jadwal sesuai data yang dimasukkan sekretaris.
    final lokasi = j.lokasi.trim().isNotEmpty
        ? j.lokasi.trim()
        : (pos.isEmpty ? '' : 'Posyandu ${labelPosyandu(pos)}');
    final waktu = '$hari, ${formatTanggal(j.tanggal)} · ${j.jam.trim()} WIB';

    return _kartuGelap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _judulKartu(
            kanan: [
              _pilKecil(
                hitung,
                bg: const Color(0x33FACC15),
                border: const Color(0x66FACC15),
                fg: _kuningLabel,
                titik: _kuningTitik,
              ),
              const SizedBox(width: 4),
              pilStatus,
            ],
          ),
          const SizedBox(height: 10),

          // Tanggal, nama kegiatan, lokasi, jam
          _kotakDalam(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF34D399), Color(0xFF0E9F6E)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        bulanSingkat(j.tanggal).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${j.tanggal.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _daftar.length > 1 ? _pilihAnakSheet : null,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _kapital(_anak?.nama ?? '-'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_daftar.length > 1) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (lokasi.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: _mint, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lokasi,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: _mint, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              waktu,
                              style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (j.checkinBuka != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF93C5FD), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scan QR dibuka 1 jam sebelum mulai (${formatJam(j.checkinBuka!)})',
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _tombolDaftar(),
        ],
      ),
    );
  }

  Widget _layananPosyandu() {
    final menu = <(String, IconData, String, Color, VoidCallback)>[
      (
        '${_aset}pendaftaran.png',
        Icons.person_add_alt_1_rounded,
        'Pendaftaran\nPosyandu',
        const Color(0xFF0B6B55),
        _bukaPendaftaran,
      ),
      (
        '${_aset}hasil_pemeriksaan.png',
        Icons.assignment_rounded,
        'Hasil\nPemeriksaan',
        const Color(0xFF0369A1),
        _bukaPemeriksaan,
      ),
      (
        '${_aset}grafik_anak.png',
        Icons.show_chart_rounded,
        'Grafik\nAnak',
        const Color(0xFF0B6B55),
        _bukaGrafik,
      ),
      (
        '${_aset}vaksin_anak.png',
        Icons.vaccines_rounded,
        'Vaksin\nAnak',
        const Color(0xFF2563EB),
        _bukaVaksin,
      ),
      (
        '${_aset}buku_panduan.png',
        Icons.menu_book_rounded,
        'Buku\nPanduan',
        const Color(0xFF2563EB),
        _bukaBukuPanduan,
      ),
      (
        '${_aset}data_keluarga.png',
        Icons.family_restroom_rounded,
        'Data\nKeluarga',
        const Color(0xFF0B6B55),
        _bukaDataKeluarga,
      ),
    ];

    Widget item((String, IconData, String, Color, VoidCallback) m) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: m.$5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Image.asset(
                    m.$1,
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Icon(
                      m.$2,
                      color: m.$4,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  m.$3,
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

    final baris = <Widget>[];
    for (var i = 0; i < menu.length; i += 4) {
      final potong = menu.sublist(i, math.min(i + 4, menu.length));
      baris.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in potong) item(m),
              for (var k = potong.length; k < 4; k++)
                const Expanded(child: SizedBox()),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Layanan Posyandu',
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.2,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
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
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 14),
            child: Text(
              'Pilih menu layanan kesehatan balita',
              style: TextStyle(
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

  Widget _tipsHariIni() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEBFBF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCDEFDD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hijauTeks,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TIPS POSYANDU HARI INI',
                  style: TextStyle(
                    color: _hijauTeks,
                    fontSize: 12.5,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Bawalah buku KIA fisik jika ini kunjungan pertama, '
                  'dan pastikan bayi sudah cukup minum susu sebelum penimbangan.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}