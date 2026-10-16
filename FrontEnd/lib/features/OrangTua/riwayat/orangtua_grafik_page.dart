import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../datadiri/keluarga_common.dart';

// ---------------------------------------------------------------------------
// STANDAR LINGKAR KEPALA menurut umur (0-24 bulan): median per bulan dan SD.
// Nilai pendekatan dari tabel standar WHO. Sesuaikan dengan tabel resmi bila perlu.
// ---------------------------------------------------------------------------
const _medianLaki = <double>[
  34.5, 37.3, 39.1, 40.5, 41.6, 42.6, 43.3, 44.0, 44.5, 45.0, 45.4, 45.8, 46.1,
  46.3, 46.6, 46.8, 47.0, 47.2, 47.4, 47.5, 47.7, 47.8, 48.0, 48.1, 48.3,
];
const _medianPerempuan = <double>[
  33.9, 36.5, 38.3, 39.5, 40.6, 41.5, 42.2, 42.8, 43.4, 43.8, 44.2, 44.6, 44.9,
  45.2, 45.4, 45.7, 45.9, 46.1, 46.2, 46.4, 46.6, 46.7, 46.9, 47.0, 47.2,
];

const double _bulanMaks = 24;

double _median(bool laki, double bulan) {
  final t = laki ? _medianLaki : _medianPerempuan;
  final b = bulan.clamp(0, _bulanMaks).toDouble();
  final i = b.floor();
  if (i >= t.length - 1) return t.last;
  return t[i] + (t[i + 1] - t[i]) * (b - i);
}

double _sd(bool laki, double bulan) {
  final b = bulan.clamp(0, _bulanMaks).toDouble();
  return (laki ? 1.27 : 1.22) + 0.006 * b;
}

double _kurva(bool laki, double bulan, int sd) =>
    _median(laki, bulan) + sd * _sd(laki, bulan);

double _z(bool laki, double bulan, double nilai) =>
    (nilai - _median(laki, bulan)) / _sd(laki, bulan);

// ---------------------------------------------------------------------------
// MODEL DATA TERSIMPAN
// ---------------------------------------------------------------------------
class _Titik {
  final double bulan;
  final DateTime? tanggal;
  final double? lk;
  final double? bb;
  final double? tb;
  _Titik(this.bulan, this.tanggal, this.lk, this.bb, this.tb);
}

class _AnakGrafik {
  final String id;
  final String nama;
  final bool laki;
  final DateTime? lahir;
  final List<_Titik> titik;
  _AnakGrafik(this.id, this.nama, this.laki, this.lahir, this.titik);
}

String _pesan(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return 'Tidak dapat terhubung ke server.';
  }
  return 'Terjadi kesalahan: $e';
}

double? _d(dynamic v) => double.tryParse(v?.toString() ?? '');

// ---------------------------------------------------------------------------
// HALAMAN
// ---------------------------------------------------------------------------
class OrangTuaGrafikPage extends StatefulWidget {
  const OrangTuaGrafikPage({super.key});

  @override
  State<OrangTuaGrafikPage> createState() => _OrangTuaGrafikPageState();
}

class _OrangTuaGrafikPageState extends State<OrangTuaGrafikPage> {
  List<_AnakGrafik> _anak = [];
  int _aktif = 0;
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final data = await KeluargaApi.ambil();
      final model = KeluargaApi.keModel(data);
      final r = await ApiClient.dio.get('/riwayat',
          options: Options(receiveTimeout: const Duration(seconds: 15)));
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];

      final perAnak = <String, List<Map<String, dynamic>>>{};
      if (d is List) {
        for (final e in d) {
          if (e is Map && e['pengukuran'] is Map) {
            perAnak
                .putIfAbsent(e['anak_id'].toString(), () => [])
                .add(Map<String, dynamic>.from(e));
          }
        }
      }

      final hasil = <_AnakGrafik>[];
      for (final a in model.anak) {
        final lahir = parseTgl(a.tglLahir);
        final titik = <_Titik>[];
        for (final e in perAnak[a.id] ?? const <Map<String, dynamic>>[]) {
          final u = Map<String, dynamic>.from(e['pengukuran'] as Map);
          final ts = e['tanggal']?.toString() ?? '';
          final tgl = ts.length >= 10 ? DateTime.tryParse(ts.substring(0, 10)) : null;
          double bulan = (_d(u['usia_bulan']) ?? 0);
          if (lahir != null && tgl != null) {
            bulan = tgl.difference(lahir).inDays / 30.4375;
          }
          titik.add(_Titik(bulan, tgl, _d(u['lingkar_kepala_cm']), _d(u['bb_kg']),
              _d(u['tb_cm'])));
        }
        titik.sort((x, y) => x.bulan.compareTo(y.bulan));
        hasil.add(_AnakGrafik(a.id ?? '', a.nama, a.jk != 'P', lahir, titik));
      }

      if (!mounted) return;
      setState(() {
        _anak = hasil;
        if (_aktif >= hasil.length) _aktif = 0;
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesan(e);
        _memuat = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Grafik Perkembangan',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_memuat)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_gagal != null)
              SectionCard(
                color: AppColors.kuningMuda,
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: AppColors.kuning),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_gagal!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13))),
                    TextButton(
                      onPressed: () {
                        setState(() => _memuat = true);
                        _muat();
                      },
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else if (_anak.isEmpty)
              const SectionCard(
                title: 'Belum ada data anak',
                icon: Icons.child_care,
                child: Text('Lengkapi data keluarga terlebih dahulu.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup)),
              )
            else
              ..._isi(_anak[_aktif]),
          ],
        ),
      ),
    );
  }

  List<Widget> _isi(_AnakGrafik a) {
    final warna = a.laki ? const Color(0xFFD6ECFA) : const Color(0xFFF8D9EE);
    final aksen = a.laki ? const Color(0xFF1593D6) : const Color(0xFFC9379D);
    final titikLk = a.titik.where((t) => t.lk != null && t.bulan <= _bulanMaks).toList();
    final tanpaLk = a.titik.length - titikLk.length;

    String status = '-';
    Color sBg = AppColors.isiField, sFg = AppColors.teksRedup;
    if (titikLk.isNotEmpty) {
      final t = titikLk.last;
      final z = _z(a.laki, t.bulan, t.lk!);
      if (z > 2) {
        status = 'Makrosefali (> +2 SD)';
        sBg = AppColors.merahMuda;
        sFg = AppColors.merah;
      } else if (z < -2) {
        status = 'Mikrosefali (< -2 SD)';
        sBg = AppColors.merahMuda;
        sFg = AppColors.merah;
      } else {
        status = 'Normal (-2 SD s.d. +2 SD)';
        sBg = AppColors.hijauMuda;
        sFg = AppColors.hijau;
      }
    }

    return [
      if (_anak.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _anak.length; i++)
                ChoiceChip(
                  selected: i == _aktif,
                  selectedColor: AppColors.hijau,
                  backgroundColor: Colors.white,
                  label: Text(_anak[i].nama),
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: i == _aktif ? Colors.white : Colors.black87),
                  onSelected: (_) => setState(() => _aktif = i),
                ),
            ],
          ),
        ),
      SectionCard(
        title: 'Lingkar Kepala menurut Umur',
        icon: Icons.show_chart,
        trailing: Pill(a.laki ? 'Laki-laki' : 'Perempuan', bg: warna, fg: aksen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: warna,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
              child: SizedBox(
                height: 260,
                width: double.infinity,
                child: CustomPaint(
                  painter: _KurvaPainter(laki: a.laki, titik: titikLk, aksen: aksen),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const [
                _Leg(Colors.black, '+3 / -3 SD'),
                _Leg(Color(0xFFE53935), '+2 / -2 SD'),
                _Leg(Color(0xFFF59E0B), '+1 / -1 SD'),
                _Leg(Color(0xFF2E9E4F), 'Median (0)'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Status terakhir: ',
                    style: TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                Pill(status, bg: sBg, fg: sFg),
              ],
            ),
            if (titikLk.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Belum ada data lingkar kepala yang tersimpan untuk anak ini. Titik grafik muncul setelah kader mengukur dan bidan menyimpan catatan.',
                  style: TextStyle(fontSize: 12, color: AppColors.teksRedup),
                ),
              ),
            if (tanpaLk > 0 && titikLk.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '$tanpaLk kunjungan tidak ditampilkan (lingkar kepala kosong atau usia di atas 24 bulan).',
                    style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
              ),
          ],
        ),
      ),
      SectionCard(
        title: 'Riwayat Pengukuran Tersimpan',
        icon: Icons.history,
        child: a.titik.isEmpty
            ? const Text('Belum ada pengukuran.',
                style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup))
            : Column(
                children: [
                  for (final t in a.titik.reversed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.latar,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.tanggal == null ? '-' : formatTanggal(t.tanggal!),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800, fontSize: 12.5)),
                                Text('Usia ${t.bulan.toStringAsFixed(1)} bln',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.teksRedup)),
                              ],
                            ),
                          ),
                          _kecil('LK', t.lk),
                          _kecil('BB', t.bb),
                          _kecil('TB', t.tb),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    ];
  }

  Widget _kecil(String l, double? v) => Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          children: [
            Text(l, style: const TextStyle(fontSize: 10, color: AppColors.teksRedup)),
            Text(v == null ? '-' : v.toString(),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ],
        ),
      );
}

class _Leg extends StatelessWidget {
  final Color warna;
  final String teks;
  const _Leg(this.warna, this.teks);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 16, height: 3, color: warna),
          const SizedBox(width: 5),
          Text(teks, style: const TextStyle(fontSize: 10.5)),
        ],
      );
}

// ---------------------------------------------------------------------------
// PELUKIS GRAFIK
// ---------------------------------------------------------------------------
class _KurvaPainter extends CustomPainter {
  final bool laki;
  final List<_Titik> titik;
  final Color aksen;
  _KurvaPainter({required this.laki, required this.titik, required this.aksen});

  static const _warnaSd = {
    3: Colors.black,
    2: Color(0xFFE53935),
    1: Color(0xFFF59E0B),
    0: Color(0xFF2E9E4F),
  };

  void _teks(Canvas c, String s, Offset o, {double fs = 9, Color col = Colors.black54, bool tengah = true}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: col)),
      textDirection: TextDirection.ltr,
    )..layout();
    c.save();
    c.translate(tengah ? o.dx - tp.width / 2 : o.dx, o.dy - tp.height / 2);
    tp.paint(c, Offset.zero);
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const kiri = 28.0, kanan = 24.0, bawah = 22.0, atas = 6.0;
    final w = size.width - kiri - kanan;
    final h = size.height - bawah - atas;

    double minY = _kurva(laki, 0, -3).floorToDouble() - 1;
    double maxY = _kurva(laki, _bulanMaks, 3).ceilToDouble() + 1;
    for (final t in titik) {
      if (t.lk! < minY) minY = t.lk!.floorToDouble() - 1;
      if (t.lk! > maxY) maxY = t.lk!.ceilToDouble() + 1;
    }

    double px(double b) => kiri + b / _bulanMaks * w;
    double py(double v) => atas + h - (v - minY) / (maxY - minY) * h;

    // area plot
    canvas.drawRect(Rect.fromLTWH(kiri, atas, w, h), Paint()..color = Colors.white.withOpacity(0.55));

    // grid
    final tipis = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.6;
    final tebal = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    for (var b = 0; b <= _bulanMaks; b++) {
      canvas.drawLine(Offset(px(b.toDouble()), atas), Offset(px(b.toDouble()), atas + h),
          b % 6 == 0 ? tebal : tipis);
      if (b % 2 == 0) {
        _teks(canvas, '$b', Offset(px(b.toDouble()), atas + h + 9));
      }
    }
    for (var v = minY.ceil(); v <= maxY.floor(); v++) {
      canvas.drawLine(Offset(kiri, py(v.toDouble())), Offset(kiri + w, py(v.toDouble())),
          v % 5 == 0 ? tebal : tipis);
      if (v % 2 == 0) {
        _teks(canvas, '$v', Offset(kiri - 12, py(v.toDouble())));
        _teks(canvas, '$v', Offset(kiri + w + 11, py(v.toDouble())));
      }
    }
    _teks(canvas, 'Bulan', Offset(kiri + w - 10, atas + h + 18), fs: 8);

    // kurva SD
    for (var sd = -3; sd <= 3; sd++) {
      final p = Path();
      for (var i = 0; i <= 48; i++) {
        final b = i / 48 * _bulanMaks;
        final o = Offset(px(b), py(_kurva(laki, b, sd)));
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      final col = _warnaSd[sd.abs()]!;
      canvas.drawPath(
        p,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = sd == 0 ? 1.8 : 1.4,
      );
      _teks(canvas, sd == 0 ? '0' : (sd > 0 ? '$sd' : '$sd'),
          Offset(kiri + w + 4, py(_kurva(laki, _bulanMaks, sd)) - 8),
          fs: 9, col: col, tengah: false);
    }

    // data anak
    if (titik.isEmpty) return;
    final garis = Paint()
      ..color = aksen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final jalur = Path();
    for (var i = 0; i < titik.length; i++) {
      final o = Offset(px(titik[i].bulan), py(titik[i].lk!));
      i == 0 ? jalur.moveTo(o.dx, o.dy) : jalur.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(jalur, garis);
    for (final t in titik) {
      final o = Offset(px(t.bulan), py(t.lk!));
      canvas.drawCircle(o, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(o, 4, Paint()..color = aksen);
      _teks(canvas, t.lk!.toString(), Offset(o.dx, o.dy - 11), fs: 9, col: aksen);
    }
  }

  @override
  bool shouldRepaint(covariant _KurvaPainter old) =>
      old.titik != titik || old.laki != laki;
}