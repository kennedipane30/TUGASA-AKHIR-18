import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/balita_detail_page.dart';
import '../../../core/common_widgets.dart';
import '../../../service/balita_service.dart';
import '../../Sekretaris/rekap/admin_rekap_page.dart';

/// Bidan: daftar anak berisiko (deteksi dini) berdasarkan penimbangan terakhir.
/// Risiko tinggi: gizi buruk, BGM, 2T, sangat pendek.
/// Risiko sedang: gizi kurang, pendek, BB kurang, tidak naik (T), gizi lebih.
class BalitaBerisikoPage extends StatefulWidget {
  const BalitaBerisikoPage({super.key});

  @override
  State<BalitaBerisikoPage> createState() => _BalitaBerisikoPageState();
}

class _BalitaBerisikoPageState extends State<BalitaBerisikoPage> {
  static const _filter = ['Semua', 'Risiko tinggi', '2T / BGM', 'Stunting', 'Wasting'];

  final _svc = const BalitaService('/bidan');
  DaftarBerisiko? _data;
  bool _loading = true;
  String? _error;
  String _aktif = 'Semua';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final d = await _svc.berisiko();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<AnakBerisiko> _saring(List<AnakBerisiko> list) {
    bool ada(AnakBerisiko a, List<String> kata) =>
        a.balita.terakhir?.masalah.any(kata.contains) ?? false;
    switch (_aktif) {
      case 'Risiko tinggi':
        return list.where((a) => a.tinggi).toList();
      case '2T / BGM':
        return list.where((a) => a.balita.perluPerhatian).toList();
      case 'Stunting':
        return list.where((a) => ada(a, const ['Pendek', 'Sangat pendek'])).toList();
      case 'Wasting':
        return list.where((a) => ada(a, const ['Gizi kurang', 'Gizi buruk'])).toList();
    }
    return list;
  }

  Future<void> _buka(AnakBerisiko a) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BalitaDetailPage(
          prefix: '/bidan',
          anakId: a.balita.anakId,
          nama: a.balita.nama,
          bisaKelolaVaksin: true,
        ),
      ),
    );
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            headerRekap(context, 'Deteksi Dini'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off, size: 40, color: AppColors.teksRedup),
                            const SizedBox(height: 10),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            AppButton('Coba Lagi', icon: Icons.refresh, onPressed: _muat),
                          ],
                        ),
                      )
                    else
                      ..._isi(_data!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _isi(DaftarBerisiko d) {
    final r = d.ringkas;
    final daftar = _saring(d.anak);
    return [
      SectionCard(
        title: 'Ringkasan Risiko',
        icon: Icons.warning_amber_rounded,
        trailing: Pill('${r.total} anak', bg: AppColors.merahMuda, fg: AppColors.merah),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: StatBox(
                      nilai: '${r.tinggi}', label: 'Risiko\ntinggi', bg: AppColors.merahMuda, fg: AppColors.merah),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${r.sedang}', label: 'Risiko\nsedang', bg: AppColors.kuningMuda, fg: AppColors.kuning),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatBox(nilai: '${r.duaT}', label: '2T')),
                const SizedBox(width: 6),
                Expanded(child: StatBox(nilai: '${r.bgm}', label: 'BGM')),
                const SizedBox(width: 6),
                Expanded(child: StatBox(nilai: '${r.giziBuruk}', label: 'Gizi\nburuk')),
                const SizedBox(width: 6),
                Expanded(child: StatBox(nilai: '${r.stunting}', label: 'Stunting')),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Dinilai dari penimbangan terakhir setiap balita aktif, sesuai Permenkes No. 2 Tahun 2020 dan KBM Buku KIA.',
              style: TextStyle(fontSize: 11, color: AppColors.teksRedup),
            ),
          ],
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _filter)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _aktif == f,
                  selectedColor: AppColors.hijau,
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _aktif == f ? Colors.white : Colors.black87,
                  ),
                  onSelected: (_) => setState(() => _aktif = f),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (daftar.isEmpty)
        SectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(Icons.verified_outlined, size: 38, color: AppColors.hijau),
                const SizedBox(height: 8),
                Text(
                  d.anak.isEmpty ? 'Tidak ada anak berisiko di posyandu ini' : 'Tidak ada anak pada filter ini',
                  style: const TextStyle(color: AppColors.teksRedup),
                ),
              ],
            ),
          ),
        ),
      for (final a in daftar) _kartu(a),
    ];
  }

  Widget _kartu(AnakBerisiko a) {
    final b = a.balita;
    final t = b.terakhir;
    final warna = a.tinggi ? AppColors.merah : AppColors.kuning;
    final latar = a.tinggi ? AppColors.merahMuda : AppColors.kuningMuda;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _buka(a),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: latar, shape: BoxShape.circle),
                  child: Icon(a.tinggi ? Icons.priority_high : Icons.error_outline, color: warna),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(b.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                          Pill(a.tinggi ? 'Risiko tinggi' : 'Risiko sedang', bg: latar, fg: warna),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${b.jkTeks} · ${b.usiaTeks}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
                      if (t != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Ditimbang ${t.tanggal == null ? '-' : formatTanggal(t.tanggal!)} · '
                          'BB ${t.bbKg} kg · TB ${t.tbCm} cm',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final x in a.alasan) Pill(x, bg: latar, fg: warna),
                        ],
                      ),
                      if (b.bulanTidakDatang >= 2) ...[
                        const SizedBox(height: 6),
                        Text('Tidak ditimbang ${b.bulanTidakDatang} bulan, perlu kunjungan rumah.',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.merah)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.teksRedup),
              ],
            ),
          ),
        ),
      ),
    );
  }
}