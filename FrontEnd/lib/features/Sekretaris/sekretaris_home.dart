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
import '../../core/pages/anak/semua_anak_page.dart';
import '../../core/pages/rekap/rekap_posyandu_page.dart';
import 'imunisasi/imunisasi_page.dart';
import 'log_aktivitas/log_aktivitas_page.dart';
import 'laporan_bulanan/laporan_bulanan_page.dart';

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

  // Grafik kehadiran anak per jadwal.
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

  void _bukaImunisasi() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminImunisasiPage()),
    );
  }

  void _bukaRekap([int tab = 0]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RekapPosyanduPage(prefix: '/sekretaris', tabAwal: tab)),
    );
  }

  void _bukaAnak() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SemuaAnakPage(prefix: '/sekretaris')),
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

  void _bukaLaporanBulanan() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const AdminLaporanBulananPage()),
    );
  }

  void _bukaLogAktivitas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogAktivitasPage()),
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
    final desa = (user?['posyandu_nama'] ?? '').toString();
    final labelDesa = desa.isEmpty ? 'Posyandu' : 'Posyandu $desa';

    return HomeShell(
      peran: 'Sekretaris',
      lokasi: labelDesa,
      sapaan: _namaSapaan(user),
      notif: _tugas.length,
      kartuUtama: _kartuGrafikHadir(),
      children: [
        _menuGrid(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // KARTU STATUS: kehadiran anak pada beberapa jadwal terakhir
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
                  style: const TextStyle(fontSize: 14, color: warnaTeksVarianHome)),
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
            style: TextStyle(fontSize: 14, color: warnaTeksVarianHome),
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
          const SizedBox(height: 12),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legenda(_warnaTotal, 'Total anak'),
              _Legenda(_warnaCheckin, 'Check-in'),
              _Legenda(_warnaTidak, 'Tidak check-in'),
            ],
          ),
          const SizedBox(height: 12),
          BarisInfoHome(
            Icons.event_rounded,
            'Terakhir',
            _tglPendek(akhir.tanggal!),
          ),
          BarisInfoHome(
            Icons.groups_outlined,
            'Anak',
            '${akhir.total} terdaftar',
          ),
          BarisInfoHome(
            Icons.how_to_reg_outlined,
            'Check-in',
            '${akhir.checkin} hadir  ·  ${akhir.tidak} tidak hadir',
          ),
          const SizedBox(height: 4),
          TombolUtamaHome(
            label: 'Lihat Rekap Posyandu',
            ikon: Icons.summarize_outlined,
            onTap: () => _bukaRekap(0),
          ),
        ],
      );
    }

    return KartuHome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KepalaKartuHome(
            ikon: Icons.insert_chart_outlined_rounded,
            judul: 'Kehadiran Anak',
          ),
          const SizedBox(height: 12),
          const Text(
            'Jumlah anak terdaftar dan yang check-in pada 6 jadwal terakhir.',
            style: TextStyle(fontSize: 13.5, height: 1.4, color: warnaTeksVarianHome),
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

  // -------------------------------------------------------------------------
  // GRID LAYANAN (ikon memakai gambar yang sudah ada)
  // -------------------------------------------------------------------------
  Widget _menuGrid() {
    return GridLayananHome(
      judul: 'Layanan Sekretaris',
      item: [
        ItemLayananHome(
          aset: 'kelola_akun.png',
          cadangan: Icons.manage_accounts,
          warna: AppColors.hijau,
          judul: 'Kelola\nAkun',
          onTap: _bukaAkun,
        ),
        ItemLayananHome(
          aset: 'jadwal.png',
          cadangan: Icons.calendar_month,
          warna: AppColors.hijau,
          judul: 'Jadwal &\nAgenda',
          onTap: _bukaJadwal,
        ),
        ItemLayananHome(
          aset: 'riwatar_pemeriksaan.png',
          cadangan: Icons.history,
          warna: AppColors.hijau,
          judul: 'Riwayat\nPemeriksaan',
          onTap: _bukaRiwayat,
        ),
        ItemLayananHome(
          aset: 'qr_chekin.png',
          cadangan: Icons.qr_code_2,
          warna: AppColors.hijau,
          judul: 'QR\nCheck-in',
          onTap: _bukaQr,
        ),
        ItemLayananHome(
          aset: 'imunisasi_anak.png',
          cadangan: Icons.vaccines_outlined,
          warna: AppColors.hijau,
          judul: 'Imunisasi\nAnak',
          onTap: _bukaImunisasi,
        ),
        ItemLayananHome(
          aset: 'pengumuman.png',
          cadangan: Icons.campaign_outlined,
          warna: AppColors.hijau,
          judul: 'Pengumuman',
          onTap: () => soon(context, 'Pengumuman'),
        ),
        ItemLayananHome(
          aset: 'semua_anak.png',
          cadangan: Icons.child_care,
          warna: AppColors.hijau,
          judul: 'Semua\nAnak',
          onTap: _bukaAnak,
        ),
        ItemLayananHome(
          aset: 'laporan_bulanan.png',
          cadangan: Icons.picture_as_pdf_outlined,
          warna: AppColors.hijau,
          judul: 'Laporan\nBulanan',
          onTap: _bukaLaporanBulanan,
        ),
        ItemLayananHome(
          aset: 'rekap_posyandu.png',
          cadangan: Icons.summarize_outlined,
          warna: AppColors.hijau,
          judul: 'Rekap\nPosyandu',
          onTap: () => _bukaRekap(0),
        ),
        ItemLayananHome(
          aset: 'log_aktivitas.png',
          cadangan: Icons.history_edu_outlined,
          warna: AppColors.hijau,
          judul: 'Log\nAktivitas',
          onTap: _bukaLogAktivitas,
        ),
      ],
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