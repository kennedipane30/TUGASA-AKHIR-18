import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../core/standar_who.dart';
import '../datadiri/data_orang_tua_page.dart' show KeluargaApi, parseTgl;
import 'orangtua_grafik_panduan_page.dart';

// Warna tampilan
const _latar = Color(0xFFF3F6FB);
const _teksGelap = Color(0xFF1E293B);
const _teksAbu = Color(0xFF64748B);
const _hijauTua = Color(0xFF065F46);
const _hijauMuda = Color(0xFFE6F8EF);

// ---------------------------------------------------------------------------
// METRIK GRAFIK (kurva dari tabel WHO di assets/standar_antropometri.csv)
// ---------------------------------------------------------------------------
enum _Jenis { bb, tb, bbtb, lk }

class _Metrik {
  final _Jenis jenis;
  final String tab;
  final String judul;
  final String satuan;
  final IconData ikon;

  const _Metrik(this.jenis, this.tab, this.judul, this.satuan, this.ikon);

  bool get berbasisUmur => jenis != _Jenis.bbtb;

  IndeksGizi get indeksGizi => switch (jenis) {
        _Jenis.bb => IndeksGizi.bbu,
        _Jenis.tb => IndeksGizi.tbu,
        _Jenis.bbtb => IndeksGizi.bbtb,
        _Jenis.lk => IndeksGizi.lku,
      };

  /// Kunci hasil perhitungan server di objek status_gizi.
  String get kunci => switch (jenis) {
        _Jenis.bb => 'bbu',
        _Jenis.tb => 'tbu',
        _Jenis.bbtb => 'bbtb',
        _Jenis.lk => 'lku',
      };

  double? y(_Titik t) => switch (jenis) {
        _Jenis.bb || _Jenis.bbtb => t.bb,
        _Jenis.tb => t.tbKoreksi,
        _Jenis.lk => t.lk,
      };

  double? x(_Titik t) => berbasisUmur ? t.bulan : t.tbKoreksi;

  /// Potongan kurva: (indeks standar, x awal, x akhir).
  /// PB/U dipakai sampai 24 bulan, lalu TB/U; BB/PB untuk < 24 bulan, BB/TB untuk >= 24 bulan.
  List<(String, double, double)> segmen(bool dibawah24) => switch (jenis) {
        _Jenis.bb => [('bbu', 0, 60)],
        _Jenis.tb => [('pbu', 0, 24), ('tbu', 24, 60)],
        _Jenis.bbtb => dibawah24 ? [('bbpb', 45, 110)] : [('bbtb', 65, 120)],
        _Jenis.lk => [('lku', 0, 60)],
      };

  /// Z-score dihitung di aplikasi (cadangan bila server belum mengirim status_gizi).
  double? zLokal(_Titik t, bool laki) {
    final w = StandarWho.instance;
    final umur = t.bulanPenuh.toDouble();
    if (t.bulanPenuh > 60) return null;
    switch (jenis) {
      case _Jenis.bb:
        final v = t.bb;
        return v == null ? null : w.cari('bbu', laki, umur)?.zScore(v, sesuaikan: true);
      case _Jenis.tb:
        final v = t.tbKoreksi;
        final idx = t.bulanPenuh < 24 ? 'pbu' : 'tbu';
        return v == null ? null : w.cari(idx, laki, umur)?.zScore(v);
      case _Jenis.bbtb:
        final v = t.bb, p = t.tbKoreksi;
        if (v == null || p == null) return null;
        final idx = t.bulanPenuh < 24 ? 'bbpb' : 'bbtb';
        return w.cari(idx, laki, (p * 2).roundToDouble() / 2)?.zScore(v, sesuaikan: true);
      case _Jenis.lk:
        final v = t.lk;
        return v == null ? null : w.cari('lku', laki, umur)?.zScore(v);
    }
  }

  String peringatan(String kategori, double z) {
    final bawah = z < 0;
    switch (jenis) {
      case _Jenis.bb:
        return bawah
            ? 'Berat badan di bawah garis -2 SD ($kategori). Dianjurkan konsultasi gizi dengan bidan Posyandu atau dokter.'
            : 'Berat badan di atas garis +1 SD ($kategori). Perhatikan pola makan dan konsultasikan dengan bidan Posyandu.';
      case _Jenis.tb:
        return bawah
            ? 'Panjang/tinggi badan di bawah garis -2 SD ($kategori). Dianjurkan konsultasi segera dengan bidan Posyandu untuk evaluasi stunting.'
            : 'Tinggi badan di atas garis +3 SD. Dianjurkan konsultasi dengan bidan Posyandu.';
      case _Jenis.bbtb:
        return bawah
            ? 'Berat badan tidak sebanding dengan panjang/tinggi badan ($kategori). Dianjurkan konsultasi gizi dengan bidan Posyandu.'
            : 'Berat badan melebihi standar untuk panjang/tinggi badannya ($kategori). Dianjurkan konsultasi gizi dengan bidan Posyandu.';
      case _Jenis.lk:
        return bawah
            ? 'Lingkar kepala di bawah garis -2 SD ($kategori). Dianjurkan konsultasi dengan dokter spesialis anak / bidan Posyandu.'
            : 'Lingkar kepala di atas garis +2 SD ($kategori). Dianjurkan konsultasi dengan dokter spesialis anak / bidan Posyandu.';
    }
  }
}

const _daftarMetrik = <_Metrik>[
  _Metrik(_Jenis.bb, 'Berat Badan', 'Berat Badan menurut Umur (BB/U)', 'kg',
      Icons.monitor_weight_outlined),
  _Metrik(_Jenis.tb, 'Tinggi Badan', 'Panjang/Tinggi Badan menurut Umur (PB/U, TB/U)',
      'cm', Icons.height),
  _Metrik(_Jenis.bbtb, 'BB/TB', 'Berat Badan menurut Panjang/Tinggi Badan', 'kg',
      Icons.accessibility_new),
  _Metrik(_Jenis.lk, 'Lingkar Kepala', 'Lingkar Kepala menurut Umur (LK/U)', 'cm',
      Icons.show_chart),
];

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class _Titik {
  final double bulan; // umur pecahan, untuk posisi titik di grafik
  final int bulanPenuh; // umur bulan penuh, untuk mencari baris standar
  final DateTime? tanggal;
  final double? lk;
  final double? bb;
  final double? tb; // hasil ukur
  final double? tbKoreksi; // setelah koreksi 0,7 cm
  final String caraUkur;
  final String usiaTeks;
  final Map<String, dynamic>? gizi; // status_gizi dari server
  final Map<String, dynamic>? nilai; // penilaian N/T (KBM) dari server

  _Titik(this.bulan, this.bulanPenuh, this.tanggal, this.lk, this.bb, this.tb,
      this.tbKoreksi, this.caraUkur, this.usiaTeks, this.gizi, [this.nilai]);

  String get statusNT => (nilai?['status'] ?? '').toString();
  bool get duaT => nilai?['dua_t'] == true;
  bool get bgm => nilai?['bgm'] == true;
}

/// Teks dan warna status penimbangan untuk orang tua.
(String, Color, Color) _gayaNT(String s) => switch (s) {
      'N' => ('Naik sesuai standar', _hijauTua, _hijauMuda),
      'T' => ('Belum naik sesuai standar', const Color(0xFFDC2626), const Color(0xFFFFE4E6)),
      'O' => ('Bulan lalu tidak ditimbang', const Color(0xFF1D4ED8), const Color(0xFFE0EAFF)),
      'B' => ('Penimbangan pertama', const Color(0xFF1D4ED8), const Color(0xFFE0EAFF)),
      _ => ('', _teksAbu, AppColors.isiField),
    };

class _AnakGrafik {
  final String id;
  final String nama;
  final bool laki;
  final DateTime? lahir;
  final List<_Titik> titik;

  _AnakGrafik(this.id, this.nama, this.laki, this.lahir, this.titik);

  int get usiaSekarang {
    final l = lahir;
    if (l == null) return titik.isEmpty ? 0 : titik.last.bulanPenuh;
    final n = DateTime.now();
    var b = (n.year - l.year) * 12 + n.month - l.month;
    if (n.day < l.day) b--;
    return math.max(0, b);
  }
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

/// Umur dalam bulan penuh pada tanggal [pada] (sama dengan perhitungan server).
int _usiaBulanPenuh(DateTime lahir, DateTime pada) {
  var b = (pada.year - lahir.year) * 12 + pada.month - lahir.month;
  if (pada.day < lahir.day) b--;
  return b < 0 ? 0 : b;
}

/// Teks usia: "12 hari", "5 bln", atau "1 th 3 bln".
String _teksUsia(DateTime lahir, DateTime pada) {
  final b = _usiaBulanPenuh(lahir, pada);
  if (b == 0) {
    final hari = DateTime(pada.year, pada.month, pada.day)
        .difference(DateTime(lahir.year, lahir.month, lahir.day))
        .inDays;
    return '${hari < 0 ? 0 : hari} hari';
  }
  return b >= 12 ? '${b ~/ 12} th ${b % 12} bln' : '$b bln';
}

String _fmtZ(double z) => '${z >= 0 ? '+' : ''}${z.toStringAsFixed(2)}';

(Color, Color) _warnaTingkat(String tingkat) => switch (tingkat) {
      'risiko' => (const Color(0xFFFFE4E6), const Color(0xFFDC2626)),
      'waspada' => (AppColors.kuningMuda, const Color(0xFFB45309)),
      _ => (_hijauMuda, _hijauTua),
    };

// ---------------------------------------------------------------------------
// HALAMAN
// ---------------------------------------------------------------------------
/// Judul header (gaya teks sama dengan halaman lain).
Widget _judulTebal(String teks) {
  return Text(
    teks,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: Colors.white,
    ),
  );
}

class OrangTuaGrafikPage extends StatefulWidget {
  final String? anakId;

  const OrangTuaGrafikPage({super.key, this.anakId});

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
      await StandarWho.instance.muat();
      final data = await KeluargaApi.ambil();
      final model = KeluargaApi.keModel(data);
      final r = await ApiClient.dio.get(
        '/riwayat',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

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
          var gizi = e['status_gizi'] is Map
              ? Map<String, dynamic>.from(e['status_gizi'] as Map)
              : null;
          final ts = (u['tanggal_ukur'] ?? e['tanggal'])?.toString() ?? '';
          final tgl =
              ts.length >= 10 ? DateTime.tryParse(ts.substring(0, 10)) : null;

          double bulan = _d(u['usia_bulan']) ?? 0;
          if (lahir != null && tgl != null) {
            bulan = tgl.difference(lahir).inDays / 30.4375;
          }
          // Usia selalu dihitung dari tanggal lahir anak dan tanggal ukur.
          final penuh = (lahir != null && tgl != null)
              ? _usiaBulanPenuh(lahir, tgl)
              : (_d(u['usia_bulan'])?.toInt() ?? bulan.floor());
          final usiaTeks = (lahir != null && tgl != null)
              ? _teksUsia(lahir, tgl)
              : (penuh >= 12 ? '${penuh ~/ 12} th ${penuh % 12} bln' : '$penuh bln');
          // Status dari server dihitung dengan usia lama: abaikan, hitung ulang di aplikasi.
          if (gizi != null && _d(gizi['usia_bulan'])?.toInt() != penuh) gizi = null;
          final cara = (u['cara_ukur'] ?? '').toString();
          final tb = _d(u['tb_cm']);
          final tbKoreksi = _d(gizi?['tb_koreksi_cm']) ??
              (tb == null ? null : koreksiPanjang(tb, penuh, cara));

          final nilai = e['penilaian'] is Map
              ? Map<String, dynamic>.from(e['penilaian'] as Map)
              : null;
          titik.add(_Titik(bulan, penuh, tgl, _d(u['lingkar_kepala_cm']),
              _d(u['bb_kg']), tb, tbKoreksi, cara, usiaTeks, gizi, nilai));
        }

        titik.sort((x, y) => x.bulan.compareTo(y.bulan));
        hasil.add(_AnakGrafik(a.id ?? '', a.nama, a.jk != 'P', lahir, titik));
      }

      var tampilAnak = hasil;
      if (widget.anakId != null && widget.anakId!.isNotEmpty) {
        final f = hasil.where((x) => x.id == widget.anakId).toList();
        if (f.isNotEmpty) tampilAnak = f;
      }

      if (!mounted) return;
      setState(() {
        _anak = tampilAnak;
        _aktif = 0;
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
          BoxShadow(
            color: Color(0x0F1E293B),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      color: _hijauTua,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                Center(child: _judulTebal('Grafik Perkembangan')),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: _bukaPanduan,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(color: Colors.white54),
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _latar,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
                      child: Text(
                        'Pemantauan kurva standar WHO (Permenkes No. 2 Tahun 2020) untuk tumbuh kembang optimal anak',
                        style: TextStyle(fontSize: 14.5, color: _teksAbu, height: 1.3),
                      ),
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
                              child: Text(
                                _gagal!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 15.5),
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
                      )
                    else if (_anak.isEmpty)
                      _kartu(
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Belum ada data anak',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _teksGelap,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Lengkapi data keluarga terlebih dahulu.',
                              style: TextStyle(fontSize: 15, color: _teksAbu),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._isi(_anak[_aktif]),
                  ],
                ),
              ),
            ),
          ],
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
            border: Border.all(
              color: aktif ? _hijauTua : const Color(0xFFE2E8F0),
            ),
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
              Text(
                _daftarMetrik[i].tab,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: aktif ? Colors.white : _teksGelap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rentang sumbu X grafik: (xMin, xMax, potongan kurva).
  (double, double, List<(String, double, double)>) _jendela(_Metrik m, _AnakGrafik a) {
    final usia = a.usiaSekarang;
    final seg = m.segmen(usia < 24);

    if (m.berbasisUmur) {
      final adaDiAtas24 = a.titik.any((t) => t.bulan > 24);
      final xMax = (usia <= 24 && !adaDiAtas24) ? 24.0 : 60.0;
      final potong = [
        for (final s in seg)
          if (s.$2 < xMax) (s.$1, s.$2, math.min(s.$3, xMax)),
      ];
      return (0, xMax, potong);
    }

    // BB/PB-BB/TB: sumbu X dalam cm, diperbesar di sekitar titik anak.
    final (idx, a0, a1) = seg.first;
    final xs = [
      for (final t in a.titik)
        if (t.tbKoreksi != null && t.bb != null) t.tbKoreksi!,
    ];
    var lo = a0, hi = a1;
    if (xs.isNotEmpty) {
      lo = math.max(a0, (xs.reduce(math.min) - 10).floorToDouble());
      hi = math.min(a1, (xs.reduce(math.max) + 10).ceilToDouble());
      while (hi - lo < 30) {
        if (lo > a0) lo = math.max(a0, lo - 5);
        if (hi < a1) hi = math.min(a1, hi + 5);
        if (lo <= a0 && hi >= a1) break;
      }
    }
    return (lo, hi, [(idx, lo, hi)]);
  }

  List<Widget> _isi(_AnakGrafik a) {
    final m = _daftarMetrik[_tab];
    final warna = a.laki ? const Color(0xFFDCEEFB) : const Color(0xFFF8DDEE);
    final aksen = a.laki ? const Color(0xFF1593D6) : const Color(0xFFC9379D);
    final (xMin, xMax, segmen) = _jendela(m, a);

    final titikData = [
      for (final t in a.titik)
        if (m.y(t) != null &&
            m.x(t) != null &&
            m.x(t)! >= xMin - 1e-6 &&
            m.x(t)! <= xMax + 1e-6)
          t,
    ];
    final tanpaData = a.titik.length - titikData.length;

    // Status terakhir: utamakan hasil server (status_gizi), cadangan hitung lokal.
    String status = '-';
    String tingkat = '';
    double? zAkhir;
    String peringatan = '';
    if (titikData.isNotEmpty) {
      final t = titikData.last;
      zAkhir = _d(t.gizi?['z_${m.kunci}']) ?? m.zLokal(t, a.laki);
      if (zAkhir != null) {
        final (kat, tk) = kategoriGizi(m.indeksGizi, zAkhir);
        status = (t.gizi?['kategori_${m.kunci}'] ?? '').toString();
        if (status.isEmpty) status = kat;
        tingkat = tk;
        if (tk != 'baik') peringatan = m.peringatan(status, zAkhir);
      }
    }
    final (sBg, sFg) = tingkat.isEmpty
        ? (AppColors.isiField, AppColors.teksRedup)
        : _warnaTingkat(tingkat);
    final abnormal = tingkat.isNotEmpty && tingkat != 'baik';

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
                    fontWeight: FontWeight.w500,
                    color: i == _aktif ? Colors.white : _teksGelap,
                  ),
                  onSelected: (_) => setState(() => _aktif = i),
                ),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            a.nama,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _hijauTua,
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _daftarMetrik.length; i++) _tabPill(i),
            ],
          ),
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
                    color: _hijauMuda,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(m.ikon, size: 18, color: _hijauTua),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.judul,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: _teksGelap,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: warna,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    a.laki ? 'Laki-laki' : 'Perempuan',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: aksen,
                    ),
                  ),
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
                    berbasisUmur: m.berbasisUmur,
                    segmen: segmen,
                    laki: a.laki,
                    xMin: xMin,
                    xMax: xMax,
                    titik: [
                      for (final t in titikData) Offset(m.x(t)!, m.y(t)!),
                    ],
                    label: [
                      for (final t in titikData) m.jenis == _Jenis.bb ? t.statusNT : '',
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
            if (m.jenis == _Jenis.tb)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Garis kurva bergeser di usia 24 bulan karena cara ukur berubah dari berbaring (PB) menjadi berdiri (TB).',
                  style: TextStyle(fontSize: 13.5, color: _teksAbu, height: 1.4),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE9EEF3)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  zAkhir == null ? 'Status terakhir:' : 'Status terakhir (Z ${_fmtZ(zAkhir)}):',
                  style: const TextStyle(fontSize: 14.5, color: _teksAbu),
                ),
                const Spacer(),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (zAkhir != null) ...[
                          Icon(
                            abnormal ? Icons.error : Icons.check_circle,
                            size: 15,
                            color: sFg,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: sFg,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        peringatan,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (m.jenis == _Jenis.bb && titikData.isNotEmpty)
              _kotakNT(titikData.last, _sebelum(a, titikData.last), a.nama),
            if (titikData.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Belum ada data ${m.tab.toLowerCase()} yang tersimpan untuk anak ini. Titik grafik muncul setelah kader mengukur dan bidan menyimpan catatan.',
                  style: const TextStyle(fontSize: 14.5, color: _teksAbu, height: 1.4),
                ),
              ),
            if (tanpaData > 0 && titikData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '$tanpaData kunjungan tidak ditampilkan (data kosong atau di luar rentang grafik).',
                  style: const TextStyle(fontSize: 14, color: _teksAbu),
                ),
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
                    color: _hijauMuda,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history, size: 18, color: _hijauTua),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Riwayat Pengukuran Tersimpan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _teksGelap,
                    ),
                  ),
                ),
                if (riwayat.length > 1)
                  InkWell(
                    onTap: () => setState(() => _semuaRiwayat = !_semuaRiwayat),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        _semuaRiwayat ? 'Ringkas' : 'Lihat Semua',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _teksGelap,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (riwayat.isEmpty)
              const Text(
                'Belum ada pengukuran.',
                style: TextStyle(fontSize: 15, color: _teksAbu),
              )
            else
              for (final t in tampil) _barisRiwayat(t, a.laki),
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
                  Text(
                    'Panduan Standar WHO',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: _teksGelap,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Pelajari arti kurva Z-score pada anak Anda',
                    style: TextStyle(fontSize: 14, color: _teksAbu),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hijauTua,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _bukaPanduan,
              child: const Text(
                'Baca',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Pengukuran tepat sebelum [t] (cadangan bila server belum mengirim data sebelumnya).
  _Titik? _sebelum(_AnakGrafik a, _Titik t) {
    final i = a.titik.indexOf(t);
    for (var j = i - 1; j >= 0; j--) {
      if (a.titik[j].bb != null) return a.titik[j];
    }
    return null;
  }

  /// Berat dalam kg dengan koma desimal: 2,6 / 3,05.
  String _kg(double v) {
    var s = v.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s.replaceAll('.', ',');
  }

  /// Kenaikan berat badan dibanding pengukuran SEBELUMNYA (bukan pengukuran pertama),
  /// beserta penilaian N/T dan saran bila 2T atau BGM.
  Widget _kotakNT(_Titik t, _Titik? prev, String nama) {
    final n = t.nilai;
    final status = t.statusNT.isNotEmpty ? t.statusNT : (prev == null ? 'B' : 'O');

    // Data pengukuran sebelumnya: utamakan hasil server, cadangan dari riwayat di aplikasi.
    final bbSebelum = _d(n?['bb_sebelumnya']) ?? prev?.bb;
    final tsSebelum = (n?['tanggal_sebelumnya'] ?? '').toString();
    final tglSebelum = (tsSebelum.length >= 10 ? DateTime.tryParse(tsSebelum.substring(0, 10)) : null) ??
        prev?.tanggal;
    final bbSekarang = t.bb;
    int? naik = int.tryParse(n?['kenaikan_gram']?.toString() ?? '');
    if (naik == null && bbSebelum != null && bbSekarang != null) {
      naik = ((bbSekarang - bbSebelum) * 1000).round();
    }
    final kbm = int.tryParse(n?['kbm_gram']?.toString() ?? '');
    final selisihBulan = int.tryParse(n?['selisih_bulan']?.toString() ?? '');
    final adaSebelum = bbSebelum != null && naik != null && status != 'B';
    final g = naik ?? 0;
    final bbLalu = bbSebelum ?? 0;

    // Judul dan warna kotak
    String judul;
    Color fg, bg;
    if (!adaSebelum) {
      judul = 'Penimbangan pertama';
      fg = const Color(0xFF1D4ED8);
      bg = const Color(0xFFE0EAFF);
    } else if (g > 0) {
      judul = 'Naik $g gram';
      if (status == 'T') {
        fg = const Color(0xFFB45309);
        bg = AppColors.kuningMuda;
      } else if (status == 'N') {
        fg = _hijauTua;
        bg = _hijauMuda;
      } else {
        fg = const Color(0xFF1D4ED8);
        bg = const Color(0xFFE0EAFF);
      }
    } else if (g == 0) {
      judul = 'Berat badan tetap';
      fg = const Color(0xFFB45309);
      bg = AppColors.kuningMuda;
    } else {
      judul = 'Turun ${g.abs()} gram';
      fg = const Color(0xFFDC2626);
      bg = const Color(0xFFFFE4E6);
    }

    // Rincian
    final rincian = <String>[];
    if (!adaSebelum) {
      if (bbSekarang != null) rincian.add('Berat badan saat ini ${_kg(bbSekarang)} kg.');
      rincian.add('Kenaikan berat badan akan dihitung dari penimbangan ini pada kunjungan berikutnya.');
    } else {
      final kapan = tglSebelum == null ? '' : ' (${formatTanggal(tglSebelum)})';
      rincian.add('Dibanding penimbangan sebelumnya$kapan: '
          '${_kg(bbLalu)} kg → ${bbSekarang == null ? '-' : '${_kg(bbSekarang)} kg'}.');
      switch (status) {
        case 'N':
          if (kbm != null) rincian.add('Sudah memenuhi kenaikan minimal $kbm gram untuk usianya.');
        case 'T':
          if (kbm != null) rincian.add('Kenaikan minimal untuk usianya $kbm gram.');
        case 'O':
          if (selisihBulan != null && selisihBulan <= 0) {
            rincian.add('Sudah ditimbang pada bulan yang sama.');
          } else {
            rincian.add('Bulan lalu tidak ditimbang, jadi naik/tidak naik sesuai standar belum dapat dinilai. '
                'Usahakan datang ke posyandu setiap bulan.');
          }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                child: !adaSebelum
                    ? const Icon(Icons.flag_rounded, color: Colors.white, size: 16)
                    : Icon(
                        g > 0
                            ? Icons.arrow_upward_rounded
                            : (g == 0 ? Icons.remove_rounded : Icons.arrow_downward_rounded),
                        color: Colors.white,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
                    if (adaSebelum && status.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(_gayaNT(status).$1,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg)),
                    ],
                    const SizedBox(height: 4),
                    Text(rincian.join(' '),
                        style: const TextStyle(fontSize: 14, height: 1.45, color: _teksGelap)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (t.duaT || t.bgm)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      if (t.duaT) 'Berat badan $nama belum naik sesuai standar selama 2 bulan berturut-turut.',
                      if (t.bgm) 'Berat badan $nama masih di bawah batas yang dianjurkan untuk usianya.',
                      'Silakan konsultasikan dengan bidan di posyandu atau puskesmas agar mendapat saran gizi yang tepat.',
                    ].join(' '),
                    style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF991B1B)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _barisRiwayat(_Titik t, bool laki) {
    final g = t.gizi;
    var kategoriTb = (g?['kategori_tbu'] ?? '').toString();
    var kategoriBb = (g?['kategori_bbtb'] ?? '').toString();
    var tingkat = (g?['tingkat'] ?? '').toString();
    if (g == null) {
      // Hitung di aplikasi bila status server tidak ada / tidak sesuai usia.
      final zTb = _daftarMetrik[1].zLokal(t, laki);
      final zBb = _daftarMetrik[2].zLokal(t, laki);
      final tk = <String>[];
      if (zTb != null) {
        final (k, x) = kategoriGizi(IndeksGizi.tbu, zTb);
        kategoriTb = k;
        tk.add(x);
      }
      if (zBb != null) {
        final (k, x) = kategoriGizi(IndeksGizi.bbtb, zBb);
        kategoriBb = k;
        tk.add(x);
      }
      tingkat = tk.contains('risiko')
          ? 'risiko'
          : (tk.contains('waspada') ? 'waspada' : (tk.isEmpty ? '' : 'baik'));
    }
    final (bg, fg) = _warnaTingkat(tingkat);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tanggal == null ? '-' : formatTanggal(t.tanggal!),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _teksGelap,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Usia ${t.usiaTeks}'
                      '${t.caraUkur.isEmpty ? '' : ' · diukur ${t.caraUkur}'}',
                      style: const TextStyle(fontSize: 14, color: _teksAbu),
                    ),
                  ],
                ),
              ),
              _kecil('LK', t.lk, 'cm', _hijauTua),
              _kecil('BB', t.bb, 'kg', _teksAbu),
              _kecil('TB', t.tb, 'cm', _teksAbu),
            ],
          ),
          if (kategoriTb.isNotEmpty || kategoriBb.isNotEmpty || t.statusNT.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (t.statusNT.isNotEmpty)
                  _chip('${t.statusNT} · ${_gayaNT(t.statusNT).$1}', _gayaNT(t.statusNT).$3, _gayaNT(t.statusNT).$2),
                if (t.duaT) _chip('2T', const Color(0xFFFFE4E6), const Color(0xFFDC2626)),
                if (t.bgm) _chip('BGM', const Color(0xFFFFE4E6), const Color(0xFFDC2626)),
                if (kategoriTb.isNotEmpty) _chip('TB/U: $kategoriTb', bg, fg),
                if (kategoriBb.isNotEmpty) _chip('BB/TB: $kategoriBb', bg, fg),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String teks, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          teks,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg),
        ),
      );

  Widget _kecil(String l, double? v, String satuan, Color warna) => Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: warna,
              ),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: v == null ? '-' : _fmt(v),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _teksGelap,
                    ),
                  ),
                  if (v != null)
                    TextSpan(
                      text: ' $satuan',
                      style: const TextStyle(fontSize: 13, color: _teksAbu),
                    ),
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
              color: warna,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            teks,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _teksGelap,
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// PELUKIS GRAFIK
// ---------------------------------------------------------------------------
class _KurvaPainter extends CustomPainter {
  final bool berbasisUmur;
  final List<(String, double, double)> segmen; // indeks standar, x awal, x akhir
  final bool laki;
  final double xMin;
  final double xMax;
  final List<Offset> titik; // dx = umur (bulan) atau panjang (cm), dy = nilai
  final List<String> label; // status N/T/O/B per titik (kosong = tanpa label)
  final Color aksen;

  _KurvaPainter({
    required this.berbasisUmur,
    required this.segmen,
    required this.laki,
    required this.xMin,
    required this.xMax,
    required this.titik,
    this.label = const [],
    required this.aksen,
  });

  static const _warnaSd = {
    3: Colors.black,
    2: Color(0xFFE53935),
    1: Color(0xFFF59E0B),
    0: Color(0xFF2E9E4F),
  };

  static const _sampel = 60;

  void _teks(
    Canvas c,
    String s,
    Offset o, {
    double fs = 9,
    Color col = Colors.black54,
    bool tengah = true,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: col)),
      textDirection: TextDirection.ltr,
    )..layout();

    c.save();
    c.translate(tengah ? o.dx - tp.width / 2 : o.dx, o.dy - tp.height / 2);
    tp.paint(c, Offset.zero);
    c.restore();
  }

  double? _kurva(String indeks, double x, int sd) =>
      StandarWho.instance.nilaiPada(indeks, laki, x, sd.toDouble());

  static double _langkahRapi(double rentang, int target) {
    final kasar = rentang / target;
    for (final l in [0.5, 1.0, 2.0, 5.0, 10.0, 20.0]) {
      if (l >= kasar) return l;
    }
    return 50;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const kiri = 30.0;
    const kanan = 26.0;
    const bawah = 24.0;
    const atas = 8.0;

    final w = size.width - kiri - kanan;
    final h = size.height - bawah - atas;
    if (w <= 0 || h <= 0 || xMax <= xMin) return;

    // Rentang Y dari kurva -3 SD / +3 SD dan titik anak.
    double minY = double.infinity, maxY = -double.infinity;
    for (final (idx, a, b) in segmen) {
      for (var i = 0; i <= _sampel; i++) {
        final x = a + (b - a) * i / _sampel;
        final lo = _kurva(idx, x, -3), hi = _kurva(idx, x, 3);
        if (lo != null) minY = math.min(minY, lo);
        if (hi != null) maxY = math.max(maxY, hi);
      }
    }
    for (final t in titik) {
      minY = math.min(minY, t.dy);
      maxY = math.max(maxY, t.dy);
    }
    if (!minY.isFinite || !maxY.isFinite) return;

    final langkahY = _langkahRapi(maxY - minY, 8);
    minY = (minY / langkahY).floorToDouble() * langkahY;
    maxY = (maxY / langkahY).ceilToDouble() * langkahY;

    double px(double x) => kiri + (x - xMin) / (xMax - xMin) * w;
    double py(double v) => atas + h - (v - minY) / (maxY - minY) * h;

    canvas.drawRect(
      Rect.fromLTWH(kiri, atas, w, h),
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    final tipis = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.6;
    final tebal = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    // Garis vertikal
    final double langkahX, labelX;
    if (berbasisUmur) {
      langkahX = xMax <= 24 ? 1 : 3;
      labelX = xMax <= 24 ? 6 : 12;
    } else {
      langkahX = 5;
      labelX = 10;
    }
    for (var x = (xMin / langkahX).ceilToDouble() * langkahX;
        x <= xMax + 1e-6;
        x += langkahX) {
      final berlabel = (x / labelX - (x / labelX).roundToDouble()).abs() < 1e-6;
      canvas.drawLine(
        Offset(px(x), atas),
        Offset(px(x), atas + h),
        berlabel ? tebal : tipis,
      );
      if (berlabel) {
        _teks(canvas, x.toStringAsFixed(0), Offset(px(x), atas + h + 9));
      }
    }

    // Garis horizontal
    for (var v = minY; v <= maxY + 1e-6; v += langkahY) {
      canvas.drawLine(Offset(kiri, py(v)), Offset(kiri + w, py(v)), tebal);
      final label = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
      _teks(canvas, label, Offset(kiri - 13, py(v)), fs: 8.5);
    }

    _teks(
      canvas,
      berbasisUmur ? 'Bulan' : 'cm',
      Offset(kiri + w - 10, atas + h + 18),
      fs: 8,
    );

    // Kurva standar WHO per potongan (PB/U dan TB/U terpisah di 24 bulan)
    for (var sd = -3; sd <= 3; sd++) {
      final col = _warnaSd[sd.abs()]!;
      final cat = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = sd == 0 ? 2.2 : 1.6;

      for (final (idx, a, b) in segmen) {
        final p = Path();
        var mulai = true;
        for (var i = 0; i <= _sampel; i++) {
          final x = a + (b - a) * i / _sampel;
          final v = _kurva(idx, x, sd);
          if (v == null) continue;
          final o = Offset(px(x), py(v));
          if (mulai) {
            p.moveTo(o.dx, o.dy);
            mulai = false;
          } else {
            p.lineTo(o.dx, o.dy);
          }
        }
        canvas.drawPath(p, cat);
      }

      final (idxAkhir, _, xAkhir) = segmen.last;
      final vAkhir = _kurva(idxAkhir, xAkhir, sd);
      if (vAkhir != null) {
        _teks(
          canvas,
          sd > 0 ? '+$sd' : '$sd',
          Offset(kiri + w + 3, py(vAkhir)),
          fs: 8.5,
          col: col,
          tengah: false,
        );
      }
    }

    if (titik.isEmpty) return;

    final garis = Paint()
      ..color = aksen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final indeks = List<int>.generate(titik.length, (i) => i)
      ..sort((p, q) => titik[p].dx.compareTo(titik[q].dx));
    final jalur = Path();
    for (var i = 0; i < indeks.length; i++) {
      final t = titik[indeks[i]];
      final o = Offset(px(t.dx), py(t.dy));
      i == 0 ? jalur.moveTo(o.dx, o.dy) : jalur.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(jalur, garis);

    for (final i in indeks) {
      final t = titik[i];
      final o = Offset(px(t.dx), py(t.dy));
      canvas.drawCircle(o, 7, Paint()..color = aksen.withOpacity(0.2));
      canvas.drawCircle(o, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(o, 4, Paint()..color = aksen);
      _teks(canvas, _fmt(t.dy), Offset(o.dx + 14, o.dy - 10), fs: 9, col: aksen);
      final s = i < label.length ? label[i] : '';
      if (s.isNotEmpty) {
        final warna = switch (s) {
          'N' => const Color(0xFF15803D),
          'T' => const Color(0xFFDC2626),
          _ => const Color(0xFF1D4ED8),
        };
        canvas.drawCircle(Offset(o.dx, o.dy + 15), 7, Paint()..color = warna);
        _teks(canvas, s, Offset(o.dx, o.dy + 15), fs: 8.5, col: Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KurvaPainter old) =>
      old.titik != titik ||
      old.label != label ||
      old.laki != laki ||
      old.xMin != xMin ||
      old.xMax != xMax ||
      old.berbasisUmur != berbasisUmur ||
      old.segmen != segmen;
}