import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'jadwal/jadwal_page.dart';
import 'riwayat/riwayat_page.dart';
import '../../core/config/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/pages/checkin/qr_checkin_page.dart';
import '../auth/auth_provider.dart';
import 'akun/kelola_akun_page.dart';
import '../../core/pages/balita/semua_balita_page.dart';
import '../../core/pages/rekap/rekap_posyandu_page.dart';
import 'vaksin/vaksin_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  // Tugas tertunda (AD-02 reset sandi, AD-06 koreksi data).
  final List<(String, String, String)> _tugas = [
    ('Reset sandi', 'Ibu Rahmawati (orang tua) meminta reset kata sandi', 'Setujui'),
    ('Koreksi NIK', 'Aisyah Putri: pengajuan koreksi NIK dari orang tua', 'Periksa'),
  ];

  // Grafik kehadiran balita per jadwal.
  List<_TitikHadir> _hadir = [];
  bool _hadirMemuat = true;
  String? _hadirGagal;

  @override
  void initState() {
    super.initState();
    _muatHadir();
  }

  /// GET /sekretaris/jadwal/riwayat: jadwal yang sudah berjalan beserta jumlah
  /// pendaftar, check-in, dan tidak hadir. Diambil 6 jadwal terakhir.
  Future<void> _muatHadir() async {
    try {
      final r = await ApiClient.dio.get(
        '/sekretaris/jadwal/riwayat',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      final list = <_TitikHadir>[];
      if (d is List) {
        for (final e in d) {
          if (e is Map) list.add(_TitikHadir.dari(Map<String, dynamic>.from(e)));
        }
      }
      list.removeWhere((t) => t.tanggal == null);
      list.sort((a, b) => a.tanggal!.compareTo(b.tanggal!));
      if (!mounted) return;
      setState(() {
        _hadir = list.length > 6 ? list.sublist(list.length - 6) : list;
        _hadirGagal = null;
        _hadirMemuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hadirGagal = 'Grafik belum dapat dimuat';
        _hadirMemuat = false;
      });
    }
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
      MaterialPageRoute(builder: (_) => RekapPosyanduPage(prefix: '/sekretaris', tabAwal: tab)),
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

        // Grafik kehadiran balita per jadwal
        _kartuGrafikHadir(),

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
        ]),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Grafik garis: total balita, check-in, dan tidak check-in per jadwal
  // -------------------------------------------------------------------------
  Widget _kartuGrafikHadir() {
    Widget isi;
    if (_hadirMemuat) {
      isi = const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
    } else if (_hadirGagal != null) {
      isi = SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hadirGagal!,
                  style: const TextStyle(fontSize: 15, color: AppColors.teksRedup)),
              TextButton(
                onPressed: () {
                  setState(() => _hadirMemuat = true);
                  _muatHadir();
                },
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    } else if (_hadir.isEmpty) {
      isi = const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Belum ada jadwal yang sudah berjalan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.teksRedup),
          ),
        ),
      );
    } else {
      final akhir = _hadir.last;
      isi = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(painter: _GrafikHadirPainter(_hadir)),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legenda(_warnaTotal, 'Total balita'),
              _Legenda(_warnaCheckin, 'Check-in'),
              _Legenda(_warnaTidak, 'Tidak check-in'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Jadwal terakhir (${_tglPendek(akhir.tanggal!)}): '
            '${akhir.total} balita, ${akhir.checkin} check-in, ${akhir.tidak} tidak check-in.',
            style: const TextStyle(fontSize: 14.5, height: 1.4, color: AppColors.teksRedup),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kehadiran Balita per Jadwal',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          const Text(
            'Jumlah balita terdaftar dan yang check-in pada 6 jadwal terakhir',
            style: TextStyle(fontSize: 14, color: AppColors.teksRedup),
          ),
          const SizedBox(height: 12),
          isi,
        ],
      ),
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
}
// ---------------------------------------------------------------------------
// DATA & PELUKIS GRAFIK KEHADIRAN
// ---------------------------------------------------------------------------
const _warnaTotal = Color(0xFF475569); // abu gelap
const _warnaCheckin = Color(0xFF0EA5A4); // hijau toska
const _warnaTidak = Color(0xFFE11D48); // merah

const _bulanPendek = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String _tglPendek(DateTime d) => '${d.day} ${_bulanPendek[d.month - 1]}';

class _TitikHadir {
  final DateTime? tanggal;
  final int checkin;
  final int tidak; // sudah daftar tetapi tidak check-in

  _TitikHadir(this.tanggal, this.checkin, this.tidak);

  int get total => checkin + tidak;

  factory _TitikHadir.dari(Map<String, dynamic> j) {
    int n(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    final t = j['tanggal']?.toString() ?? '';
    final tgl = t.length >= 10 ? DateTime.tryParse(t.substring(0, 10)) : null;
    // Pendaftar yang belum check-in saat jadwal lewat dihitung tidak check-in.
    return _TitikHadir(
      tgl,
      n(j['jumlah_checkin']),
      n(j['jumlah_terdaftar']) + n(j['jumlah_tidak_hadir']),
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color warna;
  final String teks;

  const _Legenda(this.warna, this.teks);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(teks, style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
        ],
      );
}

class _GrafikHadirPainter extends CustomPainter {
  final List<_TitikHadir> data;

  _GrafikHadirPainter(this.data);

  void _teks(Canvas c, String s, Offset o, {double fs = 11, Color col = const Color(0xFF64748B), bool kanan = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: col)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = kanan ? o.dx - tp.width : o.dx - tp.width / 2;
    tp.paint(c, Offset(dx, o.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const kiri = 30.0, kanan = 12.0, atas = 10.0, bawah = 24.0;
    final w = size.width - kiri - kanan;
    final h = size.height - atas - bawah;
    if (w <= 0 || h <= 0 || data.isEmpty) return;

    // Skala sumbu Y: kelipatan rapi.
    final maks = data.map((e) => e.total).fold<int>(0, math.max);
    var langkah = 1;
    for (final l in [1, 2, 5, 10, 20, 50, 100]) {
      langkah = l;
      if (maks / l <= 5) break;
    }
    final atasY = math.max(langkah, ((maks + langkah - 1) ~/ langkah) * langkah);

    double px(int i) => data.length == 1 ? kiri + w / 2 : kiri + w * i / (data.length - 1);
    double py(int v) => atas + h - h * v / atasY;

    // Garis bantu horizontal + label Y
    final garis = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var v = 0; v <= atasY; v += langkah) {
      canvas.drawLine(Offset(kiri, py(v)), Offset(kiri + w, py(v)), garis);
      _teks(canvas, '$v', Offset(kiri - 6, py(v)), kanan: true);
    }

    // Label X (tanggal jadwal)
    for (var i = 0; i < data.length; i++) {
      _teks(canvas, _tglPendek(data[i].tanggal!), Offset(px(i), atas + h + 14));
    }

    void seri(int Function(_TitikHadir) nilai, Color warna) {
      final cat = Paint()
        ..color = warna
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final o = Offset(px(i), py(nilai(data[i])));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, cat);
      for (var i = 0; i < data.length; i++) {
        final o = Offset(px(i), py(nilai(data[i])));
        canvas.drawCircle(o, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
            o,
            4.5,
            Paint()
              ..color = warna
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }

    seri((t) => t.total, _warnaTotal);
    seri((t) => t.checkin, _warnaCheckin);
    seri((t) => t.tidak, _warnaTidak);
  }

  @override
  bool shouldRepaint(covariant _GrafikHadirPainter old) => old.data != data;
}