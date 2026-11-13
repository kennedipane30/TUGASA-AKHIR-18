part of 'rekap_posyandu_page.dart';

// ============================================================================
// TAB 1: STATUS GIZI
// ============================================================================

class _TabGizi extends StatefulWidget {
  final String prefix;

  const _TabGizi({required this.prefix});

  @override
  State<_TabGizi> createState() => _TabGiziState();
}

class _TabGiziState extends State<_TabGizi> {
  final _svc = RekapService();
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);
  RekapGizi? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _svc.gizi(_bulan, prefix: widget.prefix);
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          PemilihBulan(
            bulan: _bulan,
            onUbah: (b) {
              setState(() => _bulan = b);
              _muat();
            },
          ),
          const SizedBox(height: 12),
          if (_loading)
            _memuat
          else if (_error != null)
            _gagal(_error!, _muat)
          else
            ..._isi(_data!),
        ],
      ),
    );
  }

  List<Widget> _isi(RekapGizi d) {
    return [
      SectionCard(
        title: 'Ringkasan ${d.label}',
        icon: Icons.monitor_weight_outlined,
        trailing: Pill('${_angka(d.partisipasi)}% diukur', bg: AppColors.biruMuda, fg: AppColors.biru),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: StatBox(nilai: '${d.sasaran}', label: 'Balita\nsasaran')),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${d.diukur}', label: 'Sudah\ndiukur', bg: AppColors.hijauMuda, fg: AppColors.hijau),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${d.normal}', label: 'Gizi\nnormal', bg: AppColors.hijauMuda, fg: AppColors.hijau),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatBox(
                      nilai: '${d.stunting}',
                      label: 'Stunting\n${_angka(d.persen(d.stunting))}%',
                      bg: AppColors.merahMuda,
                      fg: AppColors.merah),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${d.wasting}',
                      label: 'Wasting\n${_angka(d.persen(d.wasting))}%',
                      bg: AppColors.kuningMuda,
                      fg: AppColors.kuning),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${d.underweight}',
                      label: 'BB kurang\n${_angka(d.persen(d.underweight))}%',
                      bg: AppColors.biruMuda,
                      fg: AppColors.biru),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Persentase dihitung dari balita yang diukur bulan ini. Satu anak bisa termasuk lebih dari satu kategori.',
              style: TextStyle(fontSize: 16, color: AppColors.teksRedup),
            ),
          ],
        ),
      ),
      SectionCard(
        title: 'Kategori Status Gizi',
        icon: Icons.pie_chart_outline,
        trailing: const Pill('Permenkes 2/2020', bg: AppColors.hijauMuda, fg: AppColors.hijau),
        child: d.diukur == 0
            ? _kosong(Icons.scale_outlined, 'Belum ada balita yang diukur pada bulan ini')
            : Column(
                children: [
                  for (final k in d.kategori)
                    _batang(k.label, k.jumlah, d.diukur, _warnaTingkat(k.tingkat), _latarTingkat(k.tingkat),
                        sub: k.indeks),
                ],
              ),
      ),
      SectionCard(
        title: 'Tren 6 Bulan',
        icon: Icons.show_chart,
        child: _TrenGizi(tren: d.tren),
      ),
      SectionCard(
        title: 'Balita Prioritas',
        icon: Icons.priority_high,
        trailing: Pill('${d.prioritas.length} anak', bg: AppColors.merahMuda, fg: AppColors.merah),
        child: d.prioritas.isEmpty
            ? _kosong(Icons.verified_outlined, 'Tidak ada balita dengan masalah gizi pada bulan ini')
            : Column(children: [for (final a in d.prioritas) _kartuPrioritas(a)]),
      ),
    ];
  }

  Widget _kartuPrioritas(AnakGizi a) {
    String z(String l, double? v) => v == null ? '' : '$l ${v.toStringAsFixed(2)}';
    final nilai = [z('BB/U', a.zBbu), z('TB/U', a.zTbu), z('BB/TB', a.zBbtb)].where((e) => e.isNotEmpty).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.anak.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              ),
              if (a.tanggalUkur != null)
                Text(formatTanggal(a.tanggalUkur!), style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
            ],
          ),
          const SizedBox(height: 2),
          Text('${a.anak.jkTeks} · ${a.anak.usiaTeks}', style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in a.masalah)
                Pill(
                  m,
                  bg: m.startsWith('Gizi buruk') || m.startsWith('Sangat') || m.contains('sangat') || m == 'Obesitas'
                      ? AppColors.merahMuda
                      : AppColors.kuningMuda,
                  fg: m.startsWith('Gizi buruk') || m.startsWith('Sangat') || m.contains('sangat') || m == 'Obesitas'
                      ? AppColors.merah
                      : AppColors.kuning,
                ),
            ],
          ),
          if (nilai.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Z-score: $nilai', style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
          ],
        ],
      ),
    );
  }
}

/// Grafik batang sederhana: jumlah stunting, wasting, BB kurang per bulan.
class _TrenGizi extends StatelessWidget {
  final List<TrenGizi> tren;

  const _TrenGizi({required this.tren});

  @override
  Widget build(BuildContext context) {
    if (tren.isEmpty) return _kosong(Icons.show_chart, 'Belum ada data');
    var maks = 1;
    for (final t in tren) {
      for (final v in [t.stunting, t.wasting, t.underweight]) {
        if (v > maks) maks = v;
      }
    }
    const tinggi = 110.0;
    Widget bar(int v, Color c) => Container(
          width: 9,
          height: v == 0 ? 2 : tinggi * v / maks,
          decoration: BoxDecoration(color: v == 0 ? _abuMuda : c, borderRadius: BorderRadius.circular(3)),
        );
    Widget legenda(Color c, String l) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(l, style: const TextStyle(fontSize: 16)),
          ],
        );
    return Column(
      children: [
        SizedBox(
          height: tinggi + 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final t in tren)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${t.stunting}/${t.wasting}/${t.underweight}',
                          style: const TextStyle(fontSize: 14.5, color: AppColors.teksRedup)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          bar(t.stunting, AppColors.merah),
                          const SizedBox(width: 2),
                          bar(t.wasting, AppColors.kuning),
                          const SizedBox(width: 2),
                          bar(t.underweight, AppColors.biru),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(t.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      Text('${t.diukur} anak', style: const TextStyle(fontSize: 14.5, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            legenda(AppColors.merah, 'Stunting'),
            legenda(AppColors.kuning, 'Wasting'),
            legenda(AppColors.biru, 'BB kurang'),
          ],
        ),
      ],
    );
  }
}