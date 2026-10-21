// ===========================================================================
// FILE 1: orangtua_grafik_page.dart
// ===========================================================================
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../datadiri/keluarga_common.dart';
import 'orangtua_grafik_panduan_page.dart';

// Warna tampilan
const _latar = Color(0xFFF3F6FB);
const _teksGelap = Color(0xFF1E293B);
const _teksAbu = Color(0xFF64748B);
const _hijauTua = Color(0xFF065F46);
const _hijauMuda = Color(0xFFE6F8EF);

// ---------------------------------------------------------------------------
// STANDAR PERTUMBUHAN (0-24 bulan), nilai pendekatan tabel WHO.
// ---------------------------------------------------------------------------
const _lkLaki = <double>[
  34.5, 37.3, 39.1, 40.5, 41.6, 42.6, 43.3, 44.0, 44.5, 45.0, 45.4, 45.8, 46.1,
  46.3, 46.6, 46.8, 47.0, 47.2, 47.4, 47.5, 47.7, 47.8, 48.0, 48.1, 48.3,
];
const _lkPerempuan = <double>[
  33.9, 36.5, 38.3, 39.5, 40.6, 41.5, 42.2, 42.8, 43.4, 43.8, 44.2, 44.6, 44.9,
  45.2, 45.4, 45.7, 45.9, 46.1, 46.2, 46.4, 46.6, 46.7, 46.9, 47.0, 47.2,
];
const _bbLaki = <double>[
  3.3, 4.5, 5.6, 6.4, 7.0, 7.5, 7.9, 8.3, 8.6, 8.9, 9.2, 9.4, 9.6,
  9.9, 10.1, 10.3, 10.5, 10.7, 10.9, 11.1, 11.3, 11.5, 11.8, 12.0, 12.2,
];
const _bbPerempuan = <double>[
  3.2, 4.2, 5.1, 5.8, 6.4, 6.9, 7.3, 7.6, 7.9, 8.2, 8.5, 8.7, 8.9,
  9.2, 9.4, 9.6, 9.8, 10.0, 10.2, 10.4, 10.6, 10.9, 11.1, 11.3, 11.5,
];
const _tbLaki = <double>[
  49.9, 54.7, 58.4, 61.4, 63.9, 65.9, 67.6, 69.2, 70.6, 72.0, 73.3, 74.5, 75.7,
  76.9, 78.0, 79.1, 80.2, 81.2, 82.3, 83.2, 84.2, 85.1, 86.0, 86.9, 87.8,
];
const _tbPerempuan = <double>[
  49.1, 53.7, 57.1, 59.8, 62.1, 64.0, 65.7, 67.3, 68.7, 70.1, 71.5, 72.8, 74.0,
  75.2, 76.4, 77.5, 78.6, 79.7, 80.7, 81.7, 82.7, 83.7, 84.6, 85.5, 86.4,
];

const double _bulanMaks = 24;

double _interp(List<double> t, double bulan) {
  final b = bulan.clamp(0, _bulanMaks).toDouble();
  final i = b.floor();
  if (i >= t.length - 1) return t.last;
  return t[i] + (t[i + 1] - t[i]) * (b - i);
}

enum _Jenis { lk, bb, tb }

class _Metrik {
  final _Jenis jenis;
  final String tab;
  final String judul;
  final String satuan;
  final double grid;
  final double labelStep;
  final IconData ikon;
  const _Metrik(this.jenis, this.tab, this.judul, this.satuan, this.grid,
      this.labelStep, this.ikon);

  double median(bool laki, double bulan) {
    switch (jenis) {
      case _Jenis.lk:
        return _interp(laki ? _lkLaki : _lkPerempuan, bulan);
      case _Jenis.bb:
        return _interp(laki ? _bbLaki : _bbPerempuan, bulan);
      case _Jenis.tb:
        return _interp(laki ? _tbLaki : _tbPerempuan, bulan);
    }
  }

  double sd(bool laki, double bulan) {
    final b = bulan.clamp(0, _bulanMaks).toDouble();
    switch (jenis) {
      case _Jenis.lk:
        return (laki ? 1.27 : 1.22) + 0.006 * b;
      case _Jenis.bb:
        return median(laki, b) * 0.115;
      case _Jenis.tb:
        return (laki ? 1.9 : 1.85) + 0.05 * b;
    }
  }

  double kurva(bool laki, double bulan, int s) =>
      median(laki, bulan) + s * sd(laki, bulan);

  double z(bool laki, double bulan, double nilai) =>
      (nilai - median(laki, bulan)) / sd(laki, bulan);

  double? ambil(_Titik t) {
    switch (jenis) {
      case _Jenis.lk:
        return t.lk;
      case _Jenis.bb:
        return t.bb;
      case _Jenis.tb:
        return t.tb;
    }
  }
}

const _daftarMetrik = <_Metrik>[
  _Metrik(_Jenis.lk, 'Lingkar Kepala', 'Lingkar Kepala menurut Umur', 'cm', 1, 2,
      Icons.show_chart),
  _Metrik(_Jenis.bb, 'Berat Badan', 'Berat Badan menurut Umur', 'kg', 1, 2,
      Icons.monitor_weight_outlined),
  _Metrik(_Jenis.tb, 'Tinggi Badan', 'Tinggi Badan menurut Umur', 'cm', 5, 10,
      Icons.height),
];

// ---------------------------------------------------------------------------
// MODEL
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

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();

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
  int _tab = 0;
  bool _semuaRiwayat = false;
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

  void _bukaPanduan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrangTuaGrafikPanduanPage()),
    );
  }

  Widget _kartu({required Widget child, Color color = Colors.white}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E293B), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _latar,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _muat,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back, color: _teksGelap, size: 26),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Grafik Perkembangan',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _teksGelap)),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(46, 2, 0, 14),
                child: Text('Pemantauan kurva standar WHO untuk tumbuh kembang optimal anak',
                    style: TextStyle(fontSize: 12, color: _teksAbu, height: 1.3)),
              ),
              if (_memuat)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_gagal != null)
                _kartu(
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
                _kartu(
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Belum ada data anak',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _teksGelap)),
                      SizedBox(height: 6),
                      Text('Lengkapi data keluarga terlebih dahulu.',
                          style: TextStyle(fontSize: 12.5, color: _teksAbu)),
                    ],
                  ),
                )
              else
                ..._isi(_anak[_aktif]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabPill(int i) {
    final aktif = _tab == i;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: aktif ? _hijauTua : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: aktif ? _hijauTua : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (aktif) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.6),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(_daftarMetrik[i].tab,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: aktif ? Colors.white : _teksGelap)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _isi(_AnakGrafik a) {
    final m = _daftarMetrik[_tab];
    final warna = a.laki ? const Color(0xFFDCEEFB) : const Color(0xFFF8DDEE);
    final aksen = a.laki ? const Color(0xFF1593D6) : const Color(0xFFC9379D);
    final titikData = a.titik
        .where((t) => m.ambil(t) != null && t.bulan <= _bulanMaks)
        .toList();
    final tanpaData = a.titik.length - titikData.length;

    String status = '-';
    Color sBg = AppColors.isiField, sFg = AppColors.teksRedup;
    bool abnormal = false;
    String peringatan = '';
    if (titikData.isNotEmpty) {
      final t = titikData.last;
      final z = m.z(a.laki, t.bulan, m.ambil(t)!);
      if (z < -2) {
        abnormal = true;
        sBg = const Color(0xFFFFE4E6);
        sFg = const Color(0xFFDC2626);
        switch (m.jenis) {
          case _Jenis.lk:
            status = 'Mikrosefali (< -2 SD)';
            peringatan =
                'Ukuran lingkar kepala di bawah garis -2 SD. Dianjurkan konsultasi segera dengan dokter spesialis anak / bidan Posyandu.';
            break;
          case _Jenis.bb:
            status = 'BB Kurang (< -2 SD)';
            peringatan =
                'Berat badan di bawah garis -2 SD. Dianjurkan konsultasi gizi dengan bidan Posyandu atau dokter.';
            break;
          case _Jenis.tb:
            status = 'Pendek (< -2 SD)';
            peringatan =
                'Tinggi badan di bawah garis -2 SD. Dianjurkan konsultasi segera dengan bidan Posyandu untuk evaluasi stunting.';
            break;
        }
      } else if (z > 2) {
        abnormal = true;
        sBg = const Color(0xFFFFE4E6);
        sFg = const Color(0xFFDC2626);
        switch (m.jenis) {
          case _Jenis.lk:
            status = 'Makrosefali (> +2 SD)';
            peringatan =
                'Ukuran lingkar kepala di atas garis +2 SD. Dianjurkan konsultasi dengan dokter spesialis anak / bidan Posyandu.';
            break;
          case _Jenis.bb:
            status = 'BB Lebih (> +2 SD)';
            peringatan =
                'Berat badan di atas garis +2 SD. Dianjurkan konsultasi gizi dengan bidan Posyandu.';
            break;
          case _Jenis.tb:
            status = 'Tinggi (> +2 SD)';
            peringatan =
                'Tinggi badan di atas garis +2 SD. Dianjurkan konsultasi dengan bidan Posyandu.';
            break;
        }
      } else {
        status = 'Normal (-2 SD s.d. +2 SD)';
        sBg = _hijauMuda;
        sFg = _hijauTua;
      }
    }

    final riwayat = a.titik.reversed.toList();
    final tampil = _semuaRiwayat ? riwayat : riwayat.take(1).toList();

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
                  selectedColor: _hijauTua,
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  showCheckmark: false,
                  label: Text(_anak[i].nama),
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: i == _aktif ? Colors.white : _teksGelap),
                  onSelected: (_) => setState(() => _aktif = i),
                ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [for (var i = 0; i < _daftarMetrik.length; i++) _tabPill(i)]),
        ),
      ),

      // Kartu grafik
      _kartu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                      color: _hijauMuda, shape: BoxShape.circle),
                  child: Icon(m.ikon, size: 18, color: _hijauTua),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.judul,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _teksGelap)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: warna,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(a.laki ? 'Laki-laki' : 'Perempuan',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w800, color: aksen)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: warna.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(4, 10, 8, 4),
              child: SizedBox(
                height: 280,
                width: double.infinity,
                child: CustomPaint(
                  painter: _KurvaPainter(
                    metrik: m,
                    laki: a.laki,
                    titik: [
                      for (final t in titikData) Offset(t.bulan, m.ambil(t)!)
                    ],
                    aksen: aksen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _Leg(Colors.black, '+3 / -3 SD (Ekstrem)'),
                _Leg(Color(0xFFE53935), '+2 / -2 SD (Peringatan)'),
                _Leg(Color(0xFFF59E0B), '+1 / -1 SD'),
                _Leg(Color(0xFF2E9E4F), 'Median (0 Normal)'),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE9EEF3)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Status terakhir:',
                    style: TextStyle(fontSize: 12, color: _teksAbu)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (titikData.isNotEmpty) ...[
                        Icon(abnormal ? Icons.error : Icons.check_circle,
                            size: 15, color: sFg),
                        const SizedBox(width: 6),
                      ],
                      Text(status,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800, color: sFg)),
                    ],
                  ),
                ),
              ],
            ),
            if (abnormal)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFBE3A0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(peringatan,
                          style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.45,
                              color: Color(0xFF92400E))),
                    ),
                  ],
                ),
              ),
            if (titikData.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Belum ada data ${m.tab.toLowerCase()} yang tersimpan untuk anak ini. Titik grafik muncul setelah kader mengukur dan bidan menyimpan catatan.',
                  style: const TextStyle(fontSize: 12, color: _teksAbu, height: 1.4),
                ),
              ),
            if (tanpaData > 0 && titikData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                    '$tanpaData kunjungan tidak ditampilkan (data kosong atau usia di atas 24 bulan).',
                    style: const TextStyle(fontSize: 11, color: _teksAbu)),
              ),
          ],
        ),
      ),

      // Riwayat
      _kartu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                      color: _hijauMuda, shape: BoxShape.circle),
                  child: const Icon(Icons.history, size: 18, color: _hijauTua),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Riwayat Pengukuran Tersimpan',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _teksGelap)),
                ),
                if (riwayat.length > 1)
                  InkWell(
                    onTap: () => setState(() => _semuaRiwayat = !_semuaRiwayat),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(_semuaRiwayat ? 'Ringkas' : 'Lihat Semua',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _teksGelap)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (riwayat.isEmpty)
              const Text('Belum ada pengukuran.',
                  style: TextStyle(fontSize: 12.5, color: _teksAbu))
            else
              for (final t in tampil)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9EEF3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                t.tanggal == null ? '-' : formatTanggal(t.tanggal!),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: _teksGelap)),
                            const SizedBox(height: 4),
                            Text('Usia ${_fmt(double.parse(t.bulan.toStringAsFixed(1)))} bln',
                                style: const TextStyle(
                                    fontSize: 11, color: _teksAbu)),
                          ],
                        ),
                      ),
                      _kecil('LK', t.lk, 'cm', _hijauTua),
                      _kecil('BB', t.bb, 'kg', _teksAbu),
                      _kecil('TB', t.tb, 'cm', _teksAbu),
                    ],
                  ),
                ),
          ],
        ),
      ),

      // Panduan
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEBFBF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCDEFDD)),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined, color: _hijauTua, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Panduan Standar WHO',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _teksGelap)),
                  SizedBox(height: 2),
                  Text('Pelajari arti kurva Z-score pada anak Anda',
                      style: TextStyle(fontSize: 11, color: _teksAbu)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hijauTua,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _bukaPanduan,
              child: const Text('Baca',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _kecil(String l, double? v, String satuan, Color warna) => Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(l,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: warna)),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: v == null ? '-' : _fmt(v),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _teksGelap)),
                  if (v != null)
                    TextSpan(
                        text: ' $satuan',
                        style: const TextStyle(fontSize: 10, color: _teksAbu)),
                ],
              ),
            ),
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
          Container(
            width: 16,
            height: 4,
            decoration: BoxDecoration(
                color: warna, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(teks,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: _teksGelap)),
        ],
      );
}

// ---------------------------------------------------------------------------
// PELUKIS GRAFIK
// ---------------------------------------------------------------------------
class _KurvaPainter extends CustomPainter {
  final _Metrik metrik;
  final bool laki;
  final List<Offset> titik; // dx = bulan, dy = nilai
  final Color aksen;
  _KurvaPainter({
    required this.metrik,
    required this.laki,
    required this.titik,
    required this.aksen,
  });

  static const _warnaSd = {
    3: Colors.black,
    2: Color(0xFFE53935),
    1: Color(0xFFF59E0B),
    0: Color(0xFF2E9E4F),
  };

  void _teks(Canvas c, String s, Offset o,
      {double fs = 9, Color col = Colors.black54, bool tengah = true}) {
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
    const kiri = 28.0, kanan = 26.0, bawah = 24.0, atas = 8.0;
    final w = size.width - kiri - kanan;
    final h = size.height - bawah - atas;
    final g = metrik.grid;

    double minY = (metrik.kurva(laki, 0, -3) / g).floorToDouble() * g - g;
    double maxY = (metrik.kurva(laki, _bulanMaks, 3) / g).ceilToDouble() * g + g;
    for (final t in titik) {
      if (t.dy < minY) minY = (t.dy / g).floorToDouble() * g - g;
      if (t.dy > maxY) maxY = (t.dy / g).ceilToDouble() * g + g;
    }

    double px(double b) => kiri + b / _bulanMaks * w;
    double py(double v) => atas + h - (v - minY) / (maxY - minY) * h;

    canvas.drawRect(Rect.fromLTWH(kiri, atas, w, h),
        Paint()..color = Colors.white.withOpacity(0.6));

    final tipis = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.6;
    final tebal = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    for (var b = 0; b <= _bulanMaks; b++) {
      canvas.drawLine(Offset(px(b.toDouble()), atas),
          Offset(px(b.toDouble()), atas + h), b % 6 == 0 ? tebal : tipis);
      if (b % 6 == 0 || b == 0) {
        _teks(canvas, '$b', Offset(px(b.toDouble()), atas + h + 9));
      }
    }

    final k0 = (minY / g).ceil();
    final k1 = (maxY / g).floor();
    for (var k = k0; k <= k1; k++) {
      final v = k * g;
      final tebalGaris = (v / metrik.labelStep) == (v / metrik.labelStep).roundToDouble();
      canvas.drawLine(Offset(kiri, py(v)), Offset(kiri + w, py(v)),
          tebalGaris ? tebal : tipis);
      if (tebalGaris) {
        final label = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
        _teks(canvas, label, Offset(kiri - 12, py(v)), fs: 8.5);
      }
    }
    _teks(canvas, 'Bulan', Offset(kiri + w - 8, atas + h + 18), fs: 8);

    for (var sd = -3; sd <= 3; sd++) {
      final p = Path();
      for (var i = 0; i <= 48; i++) {
        final b = i / 48 * _bulanMaks;
        final o = Offset(px(b), py(metrik.kurva(laki, b, sd)));
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      final col = _warnaSd[sd.abs()]!;
      canvas.drawPath(
        p,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = sd == 0 ? 2.2 : 1.6,
      );
      _teks(canvas, sd > 0 ? '+$sd' : '$sd',
          Offset(kiri + w + 3, py(metrik.kurva(laki, _bulanMaks, sd))),
          fs: 8.5, col: col, tengah: false);
    }

    if (titik.isEmpty) return;
    final garis = Paint()
      ..color = aksen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final jalur = Path();
    for (var i = 0; i < titik.length; i++) {
      final o = Offset(px(titik[i].dx), py(titik[i].dy));
      i == 0 ? jalur.moveTo(o.dx, o.dy) : jalur.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(jalur, garis);
    for (final t in titik) {
      final o = Offset(px(t.dx), py(t.dy));
      canvas.drawCircle(o, 7, Paint()..color = aksen.withOpacity(0.2));
      canvas.drawCircle(o, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(o, 4, Paint()..color = aksen);
      _teks(canvas, _fmt(t.dy), Offset(o.dx + 14, o.dy - 10), fs: 9, col: aksen);
    }
  }

  @override
  bool shouldRepaint(covariant _KurvaPainter old) =>
      old.titik != titik || old.laki != laki || old.metrik != metrik;
}