import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../theme/app_colors.dart';
import 'common_widgets.dart';

// ---------------------------------------------------------------------------
// STATUS GIZI: gizi buruk, wasting, stunting (Permenkes 2/2020)
//   BB/PB atau BB/TB < -3 SD  -> Gizi buruk
//   BB/PB atau BB/TB < -2 SD  -> Wasting (gizi kurang)
//   PB/U  atau TB/U  < -3 SD  -> Stunting (sangat pendek)
//   PB/U  atau TB/U  < -2 SD  -> Stunting (pendek)
// ---------------------------------------------------------------------------

class MasalahGizi {
  final String kode; // gizi_buruk | wasting | stunting_berat | stunting
  final String label;
  final bool berat;
  final String penjelasan; // bahasa sederhana untuk orang tua
  final String saran;

  const MasalahGizi({
    required this.kode,
    required this.label,
    required this.berat,
    required this.penjelasan,
    required this.saran,
  });

  Color get warna => berat ? AppColors.merah : AppColors.kuning;
  Color get latar => berat ? AppColors.merahMuda : AppColors.kuningMuda;
}

Map<String, dynamic>? petaGizi(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

double? _z(dynamic v) => v == null ? null : double.tryParse(v.toString());

String _s(dynamic v) => v?.toString().trim().toLowerCase() ?? '';

/// Daftar masalah gizi dari objek `status_gizi` API. Kosong bila normal / belum ada.
List<MasalahGizi> masalahGizi(dynamic statusGizi) {
  final g = petaGizi(statusGizi);
  if (g == null) return const [];
  final out = <MasalahGizi>[];

  final zBbtb = _z(g['z_bbtb']);
  final zTbu = _z(g['z_tbu']);
  final katBbtb = _s(g['kategori_bbtb']);
  final katTbu = _s(g['kategori_tbu']);

  final giziBuruk =
      (zBbtb != null && zBbtb < -3) || katBbtb.contains('buruk');
  final wasting = !giziBuruk &&
      ((zBbtb != null && zBbtb < -2) ||
          katBbtb.contains('kurang') ||
          g['wasting'] == true);

  final stuntingBerat =
      (zTbu != null && zTbu < -3) || katTbu.contains('sangat pendek');
  final stunting = !stuntingBerat &&
      ((zTbu != null && zTbu < -2) ||
          katTbu == 'pendek' ||
          g['stunting'] == true);

  if (giziBuruk) {
    out.add(const MasalahGizi(
      kode: 'gizi_buruk',
      label: 'Gizi buruk',
      berat: true,
      penjelasan:
          'Berat badan anak sangat kurang dibandingkan panjang/tingginya.',
      saran: 'Segera konsultasikan ke bidan atau puskesmas.',
    ));
  } else if (wasting) {
    out.add(const MasalahGizi(
      kode: 'wasting',
      label: 'Wasting (gizi kurang)',
      berat: false,
      penjelasan:
          'Berat badan anak kurang dibandingkan panjang/tingginya (anak terlihat kurus).',
      saran:
          'Perbaiki makanan anak sesuai saran bidan dan timbang anak secara rutin.',
    ));
  }

  if (stuntingBerat) {
    out.add(const MasalahGizi(
      kode: 'stunting_berat',
      label: 'Stunting (sangat pendek)',
      berat: true,
      penjelasan:
          'Panjang/tinggi badan anak sangat kurang untuk usianya.',
      saran:
          'Konsultasikan ke bidan atau puskesmas dan datang ke posyandu setiap bulan.',
    ));
  } else if (stunting) {
    out.add(const MasalahGizi(
      kode: 'stunting',
      label: 'Stunting (pendek)',
      berat: false,
      penjelasan: 'Panjang/tinggi badan anak kurang untuk usianya.',
      saran:
          'Ikuti saran gizi dari bidan dan datang ke posyandu setiap bulan.',
    ));
  }
  return out;
}

bool adaMasalahGizi(dynamic statusGizi) => masalahGizi(statusGizi).isNotEmpty;

bool masalahGiziBerat(dynamic statusGizi) =>
    masalahGizi(statusGizi).any((m) => m.berat);

// ---------------------------------------------------------------------------
// PIL STATUS GIZI (untuk baris daftar)
// ---------------------------------------------------------------------------

/// Pil-pil masalah gizi. Bila normal: tidak tampil apa-apa, kecuali [tampilNormal].
List<Widget> pilGizi(dynamic statusGizi, {bool tampilNormal = false}) {
  final list = masalahGizi(statusGizi);
  if (list.isEmpty) {
    if (tampilNormal && petaGizi(statusGizi) != null) {
      return const [Pill('Gizi baik', icon: Icons.check)];
    }
    return const [];
  }
  return [
    for (final m in list)
      Pill(
        m.label,
        bg: m.latar,
        fg: m.warna,
        icon: Icons.warning_amber_rounded,
      ),
  ];
}

class BarisPilGizi extends StatelessWidget {
  final dynamic statusGizi;
  final bool tampilNormal;

  const BarisPilGizi(this.statusGizi, {super.key, this.tampilNormal = false});

  @override
  Widget build(BuildContext context) {
    final pil = pilGizi(statusGizi, tampilNormal: tampilNormal);
    if (pil.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: pil),
    );
  }
}

// ---------------------------------------------------------------------------
// KOTAK STATUS GIZI (untuk halaman detail)
// ---------------------------------------------------------------------------

class KotakStatusGizi extends StatelessWidget {
  final dynamic statusGizi;

  /// true: bahasa sederhana untuk orang tua. false: tampilkan z-score untuk petugas.
  final bool untukOrangTua;

  const KotakStatusGizi(
    this.statusGizi, {
    super.key,
    this.untukOrangTua = false,
  });

  String _angka(dynamic v) {
    final z = _z(v);
    if (z == null) return '-';
    final t = z.toStringAsFixed(2).replaceAll('.', ',');
    return z > 0 ? '+$t' : t;
  }

  Widget _barisIndeks(String judul, dynamic z, dynamic kategori) {
    final kat = kategori?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              judul,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.teksRedup,
              ),
            ),
          ),
          Expanded(
            child: Text(
              kat.isEmpty ? '-' : '$kat  (z ${_angka(z)})',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotakMasalah(MasalahGizi m) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: m.latar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: m.warna.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: m.warna, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: m.warna,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.penjelasan,
                  style: const TextStyle(fontSize: 14.5, height: 1.35),
                ),
                if (untukOrangTua) ...[
                  const SizedBox(height: 4),
                  Text(
                    m.saran,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = petaGizi(statusGizi);
    if (g == null) {
      return const Text(
        'Status gizi belum tersedia.',
        style: TextStyle(fontSize: 15, color: AppColors.teksRedup),
      );
    }
    final masalah = masalahGizi(g);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (masalah.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.hijauMuda,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.hijau, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tidak ada tanda gizi buruk, wasting, atau stunting.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hijau,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final m in masalah) _kotakMasalah(m),
        if (!untukOrangTua) ...[
          const SizedBox(height: 4),
          _barisIndeks('BB/U', g['z_bbu'], g['kategori_bbu']),
          _barisIndeks(
            (g['indeks_tbu']?.toString().isNotEmpty ?? false)
                ? g['indeks_tbu'].toString()
                : 'PB/U · TB/U',
            g['z_tbu'],
            g['kategori_tbu'],
          ),
          _barisIndeks(
            (g['indeks_bbtb']?.toString().isNotEmpty ?? false)
                ? g['indeks_bbtb'].toString()
                : 'BB/PB · BB/TB',
            g['z_bbtb'],
            g['kategori_bbtb'],
          ),
          if (g['perlu_cek_ulang'] == true)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Hasil perlu dicek ulang (nilai di luar kewajaran).',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.merah,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// KARTU PERINGATAN GIZI DI BERANDA ORANG TUA
// Mengambil /riwayat, memakai pemeriksaan terakhir tiap anak.
// ---------------------------------------------------------------------------

class KartuPeringatanGizi extends StatefulWidget {
  final void Function(String anakId) onLihat;

  const KartuPeringatanGizi({super.key, required this.onLihat});

  @override
  State<KartuPeringatanGizi> createState() => KartuPeringatanGiziState();
}

class _AnakBermasalah {
  final String anakId;
  final String nama;
  final DateTime? tanggal;
  final List<MasalahGizi> masalah;

  _AnakBermasalah(this.anakId, this.nama, this.tanggal, this.masalah);
}

class KartuPeringatanGiziState extends State<KartuPeringatanGizi> {
  List<_AnakBermasalah> _data = [];

  @override
  void initState() {
    super.initState();
    muatUlang();
  }

  Future<void> muatUlang() async {
    try {
      final r = await ApiClient.dio.get(
        '/riwayat',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];

      // pemeriksaan terakhir (yang punya status gizi) per anak
      final terakhir = <String, Map<String, dynamic>>{};
      final tglTerakhir = <String, DateTime>{};
      if (d is List) {
        for (final e in d) {
          if (e is! Map || e['status_gizi'] is! Map) continue;
          final id = e['anak_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final t = DateTime.tryParse(e['tanggal']?.toString() ?? '') ??
              DateTime(1970);
          if (!tglTerakhir.containsKey(id) || t.isAfter(tglTerakhir[id]!)) {
            tglTerakhir[id] = t;
            terakhir[id] = Map<String, dynamic>.from(e);
          }
        }
      }

      final out = <_AnakBermasalah>[];
      terakhir.forEach((id, e) {
        final m = masalahGizi(e['status_gizi']);
        if (m.isEmpty) return;
        out.add(_AnakBermasalah(
          id,
          e['nama_anak']?.toString() ?? 'Anak',
          tglTerakhir[id],
          m,
        ));
      });
      out.sort((a, b) =>
          (b.masalah.any((x) => x.berat) ? 1 : 0) -
          (a.masalah.any((x) => x.berat) ? 1 : 0));

      if (!mounted) return;
      setState(() => _data = out);
    } catch (_) {
      // diam saja: kartu tidak ditampilkan bila gagal
    }
  }

  String _tgl(DateTime? t) {
    if (t == null || t.year < 2000) return '';
    const bln = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
      'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final l = t.toLocal();
    return '${l.day} ${bln[l.month - 1]} ${l.year}';
  }

  Widget _kartu(_AnakBermasalah a) {
    final berat = a.masalah.any((m) => m.berat);
    final warna = berat ? AppColors.merah : AppColors.kuning;
    final latar = berat ? AppColors.merahMuda : AppColors.kuningMuda;
    final tgl = _tgl(a.tanggal);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: warna.withOpacity(0.45), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: warna, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Perhatian untuk ${a.nama}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: warna,
                  ),
                ),
              ),
            ],
          ),
          if (tgl.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Hasil pemeriksaan $tgl',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.teksRedup,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final m in a.masalah)
                Pill(m.label, bg: Colors.white, fg: m.warna),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in a.masalah) ...[
            Text(
              m.penjelasan,
              style: const TextStyle(fontSize: 14.5, height: 1.35),
            ),
            const SizedBox(height: 2),
          ],
          const SizedBox(height: 4),
          Text(
            a.masalah.firstWhere((m) => m.berat, orElse: () => a.masalah.first).saran,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.onLihat(a.anakId),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Lihat hasil pemeriksaan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: warna,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_data.isEmpty) return const SizedBox.shrink();
    return Column(children: [for (final a in _data) _kartu(a)]);
  }
}