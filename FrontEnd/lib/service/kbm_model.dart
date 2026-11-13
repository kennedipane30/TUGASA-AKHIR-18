import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/common_widgets.dart';

// ============================================================================
// PENILAIAN PENIMBANGAN (KBM): N / T / O / B, 2T, BGM
// ============================================================================

String _s(dynamic v) => v == null ? '' : v.toString();
int? _iN(dynamic v) => v == null ? null : int.tryParse(_s(v));
double? _dN(dynamic v) => v == null ? null : double.tryParse(_s(v));

DateTime? _tgl(dynamic v) {
  final t = _s(v);
  if (t.length < 10) return null;
  return DateTime.tryParse(t.substring(0, 10));
}

class PenilaianTimbang {
  final String status; // N | T | O | B
  final double bbKg;
  final double? bbSebelumnya;
  final DateTime? tanggalSebelumnya;
  final int? selisihBulan;
  final int? kenaikanGram;
  final int? kbmGram;
  final bool duaT;
  final bool bgm;
  final double? zBbu;
  final bool perluRujuk;
  final String keterangan;

  const PenilaianTimbang({
    required this.status,
    required this.bbKg,
    required this.bbSebelumnya,
    required this.tanggalSebelumnya,
    required this.selisihBulan,
    required this.kenaikanGram,
    required this.kbmGram,
    required this.duaT,
    required this.bgm,
    required this.zBbu,
    required this.perluRujuk,
    required this.keterangan,
  });

  static PenilaianTimbang? dari(dynamic v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return PenilaianTimbang(
      status: _s(j['status']),
      bbKg: _dN(j['bb_kg']) ?? 0,
      bbSebelumnya: _dN(j['bb_sebelumnya']),
      tanggalSebelumnya: _tgl(j['tanggal_sebelumnya']),
      selisihBulan: _iN(j['selisih_bulan']),
      kenaikanGram: _iN(j['kenaikan_gram']),
      kbmGram: _iN(j['kbm_gram']),
      duaT: j['dua_t'] == true,
      bgm: j['bgm'] == true,
      zBbu: _dN(j['z_bbu']),
      perluRujuk: j['perlu_rujuk'] == true,
      keterangan: _s(j['keterangan']),
    );
  }

  bool get naik => status == 'N';
  bool get tidakNaik => status == 'T';

  String get labelStatus {
    switch (status) {
      case 'N':
        return 'N · Naik';
      case 'T':
        return 'T · Tidak naik';
      case 'O':
        return 'O · Bulan lalu tidak ditimbang';
      case 'B':
        return 'B · Baru ditimbang';
    }
    return '-';
  }

  Color get warna {
    switch (status) {
      case 'N':
        return AppColors.hijau;
      case 'T':
        return AppColors.merah;
      default:
        return AppColors.biru;
    }
  }

  Color get latar {
    switch (status) {
      case 'N':
        return AppColors.hijauMuda;
      case 'T':
        return AppColors.merahMuda;
      default:
        return AppColors.biruMuda;
    }
  }

  String get teksKenaikan {
    final k = kenaikanGram;
    if (k == null) return '-';
    if (k > 0) return '+$k g';
    if (k < 0) return '$k g';
    return '0 g';
  }
}

/// Pill ringkas status penimbangan: N/T/O/B, 2T, BGM.
List<Widget> pillPenilaian(PenilaianTimbang? p, {bool ringkas = false}) {
  if (p == null) return const [];
  return [
    Pill(ringkas ? p.status : p.labelStatus, bg: p.latar, fg: p.warna),
    if (p.duaT) const Pill('2T', bg: AppColors.merahMuda, fg: AppColors.merah, icon: Icons.warning_amber_rounded),
    if (p.bgm) const Pill('BGM', bg: AppColors.merahMuda, fg: AppColors.merah, icon: Icons.warning_amber_rounded),
  ];
}

/// Kotak rincian penilaian: status, kenaikan BB vs KBM, peringatan 2T/BGM.
class KotakPenilaian extends StatelessWidget {
  final PenilaianTimbang p;

  const KotakPenilaian({super.key, required this.p});

  Widget _kolom(String nilai, String label) => Expanded(
        child: Column(
          children: [
            Text(nilai, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.perluRujuk)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.merahMuda, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.merah, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      if (p.duaT) 'Tidak naik 2 bulan berturut-turut (2T)',
                      if (p.bgm) 'Berat badan di bawah garis merah (BGM)',
                    ].join(' dan ') +
                        '. Segera periksa oleh bidan dan pertimbangkan rujukan ke puskesmas.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.merah),
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.latar, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(p.naik ? Icons.trending_up : (p.tidakNaik ? Icons.trending_down : Icons.info_outline),
                      color: p.warna, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.labelStatus,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: p.warna)),
                  ),
                ],
              ),
              if (p.kenaikanGram != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _kolom(p.bbSebelumnya == null ? '-' : '${p.bbSebelumnya} kg', 'BB sebelumnya'),
                    _kolom('${p.bbKg} kg', 'BB sekarang'),
                    _kolom(p.teksKenaikan, 'Kenaikan'),
                    _kolom(p.kbmGram == null ? '-' : '${p.kbmGram} g', 'KBM'),
                  ],
                ),
              ],
              if (p.keterangan.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.keterangan, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}