part of 'rekap_posyandu_page.dart';

// ============================================================================
// TAB 2: VITAMIN A & OBAT CACING
// ============================================================================

class _TabSuplemen extends StatefulWidget {
  final String prefix;

  const _TabSuplemen({required this.prefix});

  @override
  State<_TabSuplemen> createState() => _TabSuplemenState();
}

class _TabSuplemenState extends State<_TabSuplemen> {
  final _svc = RekapService();
  int _tahun = DateTime.now().year;
  int _periode = DateTime.now().month >= 7 ? 2 : 1;
  RekapSuplemen? _data;
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
      final d = await _svc.suplemen(_tahun, _periode, prefix: widget.prefix);
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

  void _ubah({int? tahun, int? periode}) {
    setState(() {
      _tahun = tahun ?? _tahun;
      _periode = periode ?? _periode;
    });
    _muat();
  }

  Widget _pemilih() {
    final n = DateTime.now();
    Widget chip(int p, String l) {
      final aktif = _periode == p;
      final masaDepan = _tahun == n.year && p == 2 && n.month < 7;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: masaDepan ? null : () => _ubah(periode: p),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: aktif ? AppColors.hijau : AppColors.latar,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(l,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: aktif ? Colors.white : (masaDepan ? _abu : Colors.black87),
                )),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Tahun sebelumnya',
                onPressed: () => _ubah(tahun: _tahun - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text('Tahun $_tahun',
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              ),
              IconButton(
                tooltip: 'Tahun berikutnya',
                onPressed: _tahun < n.year ? () => _ubah(tahun: _tahun + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              chip(1, 'Februari'),
              const SizedBox(width: 8),
              chip(2, 'Agustus'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _pemilih(),
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

  Widget _kelompok(KelompokSuplemen k, Color warna, Color latar, IconData ikon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: latar, shape: BoxShape.circle),
                child: Icon(ikon, size: 18, color: warna),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                    Text(k.keterangan, style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              Text('${_angka(k.persen)}%',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: warna)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: k.sasaran == 0 ? 0 : (k.sudah / k.sasaran).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white,
              color: warna,
            ),
          ),
          const SizedBox(height: 6),
          Text('${k.sudah} dari ${k.sasaran} sasaran sudah menerima · ${k.belum} belum',
              style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  List<Widget> _isi(RekapSuplemen d) {
    KelompokSuplemen? cari(String kode) {
      for (final e in d.vitaminA) {
        if (e.kode == kode) return e;
      }
      return null;
    }

    final biru = cari('biru');
    final merah = cari('merah');
    final total = cari('total');
    final rentang = (d.rentangDari == null || d.rentangSampai == null)
        ? ''
        : 'Dihitung dari pemberian ${formatTanggal(d.rentangDari!)} s.d. ${formatTanggal(d.rentangSampai!)}';
    return [
      SectionCard(
        title: 'Vitamin A · ${d.label}',
        icon: Icons.medication_outlined,
        trailing: total == null
            ? null
            : Pill('${_angka(total.persen)}% cakupan', bg: AppColors.hijauMuda, fg: AppColors.hijau),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (biru != null) _kelompok(biru, AppColors.biru, AppColors.biruMuda, Icons.circle),
            if (merah != null) _kelompok(merah, AppColors.merah, AppColors.merahMuda, Icons.circle),
            if (total != null) _kelompok(total, AppColors.hijau, AppColors.hijauMuda, Icons.summarize_outlined),
            if (rentang.isNotEmpty)
              Text(rentang, style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
          ],
        ),
      ),
      SectionCard(
        title: 'Obat Cacing · Semester ${d.periode}',
        icon: Icons.healing_outlined,
        child: _kelompok(d.obatCacing, AppColors.kuning, AppColors.kuningMuda, Icons.medication),
      ),
      SectionCard(
        title: 'Belum Menerima',
        icon: Icons.person_search_outlined,
        trailing: Pill('${d.belumMenerima.length} anak', bg: AppColors.kuningMuda, fg: AppColors.kuning),
        child: d.belumMenerima.isEmpty
            ? _kosong(Icons.verified_outlined, 'Semua sasaran sudah menerima')
            : Column(
                children: [
                  for (final a in d.belumMenerima)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(a.anak.nama,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                              ),
                              Pill(a.kelompok, bg: Colors.white, fg: Colors.black87),
                            ],
                          ),
                          Text('${a.anak.jkTeks} · ${a.anak.usiaTeks}',
                              style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final b in a.belum)
                                Pill(
                                  b,
                                  bg: b.startsWith('Obat') ? AppColors.kuningMuda : AppColors.merahMuda,
                                  fg: b.startsWith('Obat') ? AppColors.kuning : AppColors.merah,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    ];
  }
}