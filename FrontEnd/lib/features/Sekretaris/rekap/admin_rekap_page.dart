import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../service/rekap_service.dart';

const _hijauHeader = Color(0xFF065F46);
const _abu = Color(0xFF64748B);
const _abuMuda = Color(0xFFF1F5F9);

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

/// Header hijau polos dengan judul di tengah (dipakai sekretaris dan kader).
Widget headerRekap(BuildContext context, String judul) {
  return Container(
    width: double.infinity,
    color: _hijauHeader,
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: _judulTebal(judul),
            ),
            if (Navigator.canPop(context))
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String _angka(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

Color _warnaTingkat(String t) {
  switch (t) {
    case 'risiko':
      return AppColors.merah;
    case 'waspada':
      return AppColors.kuning;
    default:
      return AppColors.hijau;
  }
}

Color _latarTingkat(String t) {
  switch (t) {
    case 'risiko':
      return AppColors.merahMuda;
    case 'waspada':
      return AppColors.kuningMuda;
    default:
      return AppColors.hijauMuda;
  }
}

// ============================================================================
// KOMPONEN BERSAMA
// ============================================================================

/// Pemilih bulan: ‹ November 2026 ›. Bulan setelah bulan berjalan tidak dapat dipilih.
class PemilihBulan extends StatelessWidget {
  final DateTime bulan;
  final ValueChanged<DateTime> onUbah;

  const PemilihBulan({super.key, required this.bulan, required this.onUbah});

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final bisaMaju = bulan.year < n.year || (bulan.year == n.year && bulan.month < n.month);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: () => onUbah(DateTime(bulan.year, bulan.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month, size: 18, color: AppColors.hijau),
                const SizedBox(width: 8),
                Text('${namaBulanRekap[bulan.month]} ${bulan.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: bisaMaju ? () => onUbah(DateTime(bulan.year, bulan.month + 1)) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

Widget _kosong(IconData ikon, String teks) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(ikon, size: 38, color: AppColors.teksRedup),
          const SizedBox(height: 8),
          Text(teks,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
        ],
      ),
    );

Widget _gagal(String pesan, VoidCallback ulang) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 40, color: AppColors.teksRedup),
          const SizedBox(height: 10),
          Text(pesan, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16.5)),
          const SizedBox(height: 12),
          AppButton('Coba Lagi', icon: Icons.refresh, onPressed: ulang),
        ],
      ),
    );

const _memuat = Padding(
  padding: EdgeInsets.symmetric(vertical: 60),
  child: Center(child: CircularProgressIndicator()),
);

Widget _batang(String label, int nilai, int dasar, Color warna, Color latar, {String? sub}) {
  final p = dasar == 0 ? 0.0 : nilai / dasar;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  if (sub != null && sub.isNotEmpty)
                    Text(sub, style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                ],
              ),
            ),
            Text('$nilai (${_angka(p * 100)}%)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: warna)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: p.clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: latar, color: warna),
        ),
      ],
    ),
  );
}

// ============================================================================
// HALAMAN REKAP SEKRETARIS
// ============================================================================

/// Sekretaris: rekap status gizi, Vitamin A & obat cacing, dan balita tidak hadir.
class AdminRekapPage extends StatefulWidget {
  final int tabAwal;

  const AdminRekapPage({super.key, this.tabAwal = 0});

  @override
  State<AdminRekapPage> createState() => _AdminRekapPageState();
}

class _AdminRekapPageState extends State<AdminRekapPage> {
  late int _tab = widget.tabAwal;

  @override
  Widget build(BuildContext context) {
    const label = ['Status Gizi', 'Vitamin A', 'Tidak Hadir'];
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
            headerRekap(context, 'Rekap Posyandu'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    for (var i = 0; i < label.length; i++)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: _tab == i ? AppColors.hijau : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              label[i],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _tab == i ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _TabGizi(),
                  _TabSuplemen(),
                  TidakHadirView(prefix: '/sekretaris'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 1: STATUS GIZI
// ============================================================================

class _TabGizi extends StatefulWidget {
  const _TabGizi();

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
      final d = await _svc.gizi(_bulan);
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

// ============================================================================
// TAB 2: VITAMIN A & OBAT CACING
// ============================================================================

class _TabSuplemen extends StatefulWidget {
  const _TabSuplemen();

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
      final d = await _svc.suplemen(_tahun, _periode);
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

// ============================================================================
// TAB 3: BALITA TIDAK HADIR (dipakai juga oleh kader)
// ============================================================================

/// Daftar balita sasaran yang tidak ditimbang pada bulan terpilih (S − D).
/// [prefix] '/sekretaris' atau '/kader'.
class TidakHadirView extends StatefulWidget {
  final String prefix;

  const TidakHadirView({super.key, required this.prefix});

  @override
  State<TidakHadirView> createState() => _TidakHadirViewState();
}

class _TidakHadirViewState extends State<TidakHadirView> {
  static const _filter = ['Semua', '≥ 2 bulan', 'Belum pernah', 'Sudah mendaftar'];

  final _svc = RekapService();
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);
  RekapTidakHadir? _data;
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
      _loading = true;
      _error = null;
    });
    try {
      final d = await _svc.tidakHadir(widget.prefix, _bulan);
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

  List<Widget> _isi(RekapTidakHadir d) {
    final daftar = switch (_aktif) {
      '≥ 2 bulan' => d.anak.where((a) => a.bulanTidakDatang >= 2).toList(),
      'Belum pernah' => d.anak.where((a) => a.belumPernah).toList(),
      'Sudah mendaftar' => d.anak.where((a) => a.sudahMendaftar).toList(),
      _ => d.anak,
    };
    return [
      SectionCard(
        title: 'Kehadiran ${d.label}',
        icon: Icons.groups_outlined,
        trailing: Pill('${d.jumlahJadwal} jadwal', bg: AppColors.biruMuda, fg: AppColors.biru),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: StatBox(nilai: '${d.sasaran}', label: 'S\nSasaran')),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${d.ditimbang}', label: 'D\nDitimbang', bg: AppColors.hijauMuda, fg: AppColors.hijau),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${d.tidakHadir}',
                      label: 'S − D\nTidak hadir',
                      bg: AppColors.merahMuda,
                      fg: AppColors.merah),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _batang('Partisipasi (D/S)', d.ditimbang, d.sasaran, AppColors.hijau, AppColors.hijauMuda,
                sub: 'Target posyandu ≥ 85%'),
            if (d.jumlahJadwal == 0)
              const Text('Belum ada jadwal posyandu pada bulan ini.',
                  style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
          child: _kosong(
            Icons.verified_outlined,
            d.anak.isEmpty ? 'Semua balita sasaran sudah ditimbang bulan ini' : 'Tidak ada balita pada filter ini',
          ),
        ),
      for (final a in daftar) _kartu(a),
    ];
  }

  Widget _kartu(AnakTidakHadir a) {
    final parah = a.belumPernah || a.bulanTidakDatang >= 2;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: parah ? AppColors.merahMuda : AppColors.kuningMuda,
              shape: BoxShape.circle,
            ),
            child: Icon(
              a.belumPernah ? Icons.person_off_outlined : Icons.event_busy,
              size: 20,
              color: parah ? AppColors.merah : AppColors.kuning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.anak.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                Text('${a.anak.jkTeks} · ${a.anak.usiaTeks}',
                    style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                const SizedBox(height: 6),
                Text(a.keterangan, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(
                      a.terakhirDitimbang == null
                          ? 'Belum pernah ditimbang'
                          : 'Terakhir ${formatTanggal(a.terakhirDitimbang!)}',
                      bg: _abuMuda,
                      fg: Colors.black87,
                    ),
                    if (a.bulanTidakDatang >= 2)
                      Pill('${a.bulanTidakDatang} bulan', bg: AppColors.merahMuda, fg: AppColors.merah),
                    if (a.sudahMendaftar)
                      const Pill('Mendaftar, tidak check-in', bg: AppColors.biruMuda, fg: AppColors.biru),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}