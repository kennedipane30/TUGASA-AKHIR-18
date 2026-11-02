import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// Satu baris tabel standar WHO (metode LMS).
class BarisWho {
  final double acuan;
  final double l;
  final double m;
  final double s;

  const BarisWho(this.acuan, this.l, this.m, this.s);

  /// Ukuran pada z tertentu.
  double nilaiPadaZ(double z) => l == 0
      ? m * math.exp(s * z)
      : m * math.pow(1 + l * s * z, 1 / l).toDouble();

  /// Z = ((X/M)^L - 1) / (L*S). [sesuaikan] untuk indeks berbasis berat
  /// (penyesuaian WHO di luar ±3 SD), sama seperti perhitungan di server.
  double zScore(double x, {bool sesuaikan = false}) {
    var z = l == 0
        ? math.log(x / m) / s
        : (math.pow(x / m, l).toDouble() - 1) / (l * s);
    if (!sesuaikan) return z;
    if (z > 3) {
      final sd3 = nilaiPadaZ(3);
      z = 3 + (x - sd3) / (sd3 - nilaiPadaZ(2));
    } else if (z < -3) {
      final sd3 = nilaiPadaZ(-3);
      z = -3 + (x - sd3) / (nilaiPadaZ(-2) - sd3);
    }
    return z;
  }
}

/// Tabel standar antropometri WHO (assets/standar_antropometri.csv),
/// file yang sama dengan BackEnd/data/standar_antropometri.csv.
/// Dibaca dari aset aplikasi sehingga grafik tetap tampil saat offline.
class StandarWho {
  StandarWho._();
  static final StandarWho instance = StandarWho._();
  static const aset = 'assets/standar_antropometri.csv';

  final Map<String, List<BarisWho>> _seri = {};
  Future<void>? _proses;

  bool get siap => _seri.isNotEmpty;

  Future<void> muat() {
    return _proses ??= _baca().catchError((Object e) {
      _proses = null;
      throw e;
    });
  }

  Future<void> _baca() async {
    final teks = await rootBundle.loadString(aset);
    final baris = teks.split(RegExp(r'\r?\n'));
    final kepala = baris.first.replaceAll('\uFEFF', '').split(',');
    final iI = kepala.indexOf('indeks');
    final iJ = kepala.indexOf('jenis_kelamin');
    final iA = kepala.indexOf('acuan');
    final iL = kepala.indexOf('l');
    final iM = kepala.indexOf('m');
    final iS = kepala.indexOf('s');

    final hasil = <String, List<BarisWho>>{};
    for (final b in baris.skip(1)) {
      if (b.trim().isEmpty) continue;
      final c = b.split(',');
      hasil.putIfAbsent('${c[iI]}|${c[iJ]}', () => []).add(BarisWho(
            double.parse(c[iA]),
            double.parse(c[iL]),
            double.parse(c[iM]),
            double.parse(c[iS]),
          ));
    }
    for (final l in hasil.values) {
      l.sort((a, b) => a.acuan.compareTo(b.acuan));
    }
    _seri
      ..clear()
      ..addAll(hasil);
  }

  List<BarisWho> seri(String indeks, bool laki) =>
      _seri['$indeks|${laki ? 'L' : 'P'}'] ?? const [];

  /// Baris dengan acuan tepat (umur bulan penuh atau tinggi kelipatan 0,5 cm).
  BarisWho? cari(String indeks, bool laki, double acuan) {
    for (final r in seri(indeks, laki)) {
      if ((r.acuan - acuan).abs() < 0.01) return r;
    }
    return null;
  }

  /// Nilai kurva z pada posisi x (interpolasi linear antar baris), untuk menggambar grafik.
  double? nilaiPada(String indeks, bool laki, double x, double z) {
    final s = seri(indeks, laki);
    if (s.isEmpty || x < s.first.acuan - 1e-9 || x > s.last.acuan + 1e-9) {
      return null;
    }
    for (var i = 0; i < s.length - 1; i++) {
      final a = s[i], b = s[i + 1];
      if (x <= b.acuan) {
        final t = (x - a.acuan) / (b.acuan - a.acuan);
        final va = a.nilaiPadaZ(z), vb = b.nilaiPadaZ(z);
        return va + (vb - va) * t;
      }
    }
    return s.last.nilaiPadaZ(z);
  }
}

// ---------------------------------------------------------------------------
// Kategori status gizi (Permenkes 2/2020), sama dengan perhitungan server.
// Tingkat: 'baik' | 'waspada' | 'risiko'.
// ---------------------------------------------------------------------------
enum IndeksGizi { bbu, tbu, bbtb, imtu, lku, lila }

(String, String) kategoriGizi(IndeksGizi i, double z) {
  switch (i) {
    case IndeksGizi.bbu:
      if (z < -3) return ('Berat badan sangat kurang', 'risiko');
      if (z < -2) return ('Berat badan kurang', 'waspada');
      if (z <= 1) return ('Berat badan normal', 'baik');
      return ('Risiko berat badan lebih', 'waspada');
    case IndeksGizi.tbu:
      if (z < -3) return ('Sangat pendek', 'risiko');
      if (z < -2) return ('Pendek', 'risiko');
      if (z <= 3) return ('Normal', 'baik');
      return ('Tinggi', 'waspada');
    case IndeksGizi.bbtb:
    case IndeksGizi.imtu:
      if (z < -3) return ('Gizi buruk', 'risiko');
      if (z < -2) return ('Gizi kurang', 'waspada');
      if (z <= 1) return ('Gizi baik', 'baik');
      if (z <= 2) return ('Berisiko gizi lebih', 'waspada');
      if (z <= 3) return ('Gizi lebih', 'waspada');
      return ('Obesitas', 'risiko');
    case IndeksGizi.lku:
      if (z < -2) return ('Mikrosefali', 'risiko');
      if (z > 2) return ('Makrosefali', 'risiko');
      return ('Normal', 'baik');
    case IndeksGizi.lila:
      if (z < -3) return ('Sangat kurang', 'risiko');
      if (z < -2) return ('Kurang', 'waspada');
      return ('Normal', 'baik');
  }
}

/// Koreksi 0,7 cm: < 24 bulan seharusnya diukur berbaring, >= 24 bulan berdiri.
double koreksiPanjang(double tb, int usiaBulan, String caraUkur) {
  var v = tb;
  if (usiaBulan < 24 && caraUkur == 'berdiri') v += 0.7;
  if (usiaBulan >= 24 && caraUkur == 'berbaring') v -= 0.7;
  return (v * 10).roundToDouble() / 10;
}