import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'balita_detail_page.dart';
import 'common_widgets.dart';
import '../features/Sekretaris/rekap/admin_rekap_page.dart';
import '../service/skdn_service.dart';

const _abu = Color(0xFF64748B);
const _abuMuda = Color(0xFFF1F5F9);

String _persen(double v) => '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}%';

/// Penjelasan singkat SKDN untuk sekretaris dan bidan.
void tampilkanPenjelasanSkdn(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: _abuMuda, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.hijau),
                SizedBox(width: 8),
                Text('Tentang Ringkasan Penimbangan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Halaman ini menunjukkan hasil penimbangan balita di posyandu selama satu bulan. '
              'Di laporan resmi ke puskesmas, ringkasan ini disebut SKDN.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 14),
            _barisInfo('S', 'Jumlah seluruh balita', 'Semua balita usia 0-59 bulan di posyandu.'),
            _barisInfo('K', 'Balita yang punya Buku KIA', 'Balita yang memiliki buku catatan tumbuh kembang.'),
            _barisInfo('D', 'Balita yang datang ditimbang', 'Balita yang ditimbang pada bulan ini.'),
            _barisInfo('N', 'Balita yang berat badannya naik', 'Kenaikan berat badan sesuai standar Kemenkes.'),
            const Divider(height: 24),
            const Text('Cara membaca', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
            const SizedBox(height: 8),
            const Text(
              '• Tingkat kehadiran menunjukkan berapa persen balita yang datang ditimbang. Targetnya minimal 85%.\n'
              '• Balita yang tumbuh baik menunjukkan berapa persen balita yang ditimbang dan berat badannya naik.\n'
              '• Balita yang tidak naik 2 bulan berturut-turut atau berat badannya sangat kurang perlu segera '
              'diperiksa bidan atau dirujuk ke puskesmas.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _barisInfo(String huruf, String judul, String isi) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hurufBulat(huruf),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(isi, style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
              ],
            ),
          ),
        ],
      ),
    );

Widget _hurufBulat(String huruf, {Color bg = AppColors.hijauMuda, Color fg = AppColors.hijau}) => Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(huruf, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: fg)),
    );

/// Ringkasan Penimbangan (SKDN) untuk sekretaris dan bidan.
/// [prefix] '/sekretaris' atau '/bidan'.
class SkdnPage extends StatefulWidget {
  final String prefix;

  const SkdnPage({super.key, required this.prefix});

  @override
  State<SkdnPage> createState() => _SkdnPageState();
}

class _SkdnPageState extends State<SkdnPage> {
  late final SkdnService _svc = SkdnService(widget.prefix);
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);
  SkdnData? _data;
  bool _loading = true;
  String? _error;

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
      final d = await _svc.hitung(_bulan);
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

  void _ubahBulan(DateTime b) {
    setState(() {
      _bulan = DateTime(b.year, b.month);
      _data = null;
    });
    _muat();
  }

  void _bukaAnak(AnakSkdn a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BalitaDetailPage(
          prefix: widget.prefix,
          anakId: a.anakId,
          nama: a.nama,
          bisaKelolaVaksin: widget.prefix == '/bidan',
          tabAwal: 1,
        ),
      ),
    );
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
            headerRekap(context, 'Ringkasan Penimbangan'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    PemilihBulan(bulan: _bulan, onUbah: _ubahBulan),
                    const SizedBox(height: 10),
                    _kartuInfo(),
                    const SizedBox(height: 4),
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

  Widget _kartuInfo() {
    return Material(
      color: AppColors.biruMuda,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => tampilkanPenjelasanSkdn(context),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.biru, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hasil penimbangan balita bulan ini (SKDN). Ketuk untuk penjelasan.',
                  style: TextStyle(fontSize: 12, color: AppColors.biru, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.biru),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _isi(SkdnData d) {
    final b = d.bulan;
    return [
      const SizedBox(height: 8),
      _kartuRingkasan(b),
      _kartuPersentase(d),
      _kartuRincian(b),
      if (d.tren.length > 1) _kartuTren(d),
      _kartuAnak(
        'Perlu Diperiksa / Dirujuk',
        Icons.warning_amber_rounded,
        AppColors.merah,
        AppColors.merahMuda,
        d.perluRujuk,
        'Tidak ada balita yang perlu dirujuk bulan ini.',
      ),
      _kartuAnak(
        'Berat Badan Tidak Naik',
        Icons.trending_flat,
        AppColors.kuning,
        AppColors.kuningMuda,
        d.tidakNaik,
        'Tidak ada balita yang berat badannya tidak naik bulan ini.',
      ),
    ];
  }

  // ------------------------------------------------------------- ringkasan

  Widget _barisJumlah(String huruf, String label, int nilai, {Color bg = AppColors.hijauMuda, Color fg = AppColors.hijau}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _hurufBulat(huruf, bg: bg, fg: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Text('$nilai', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: fg)),
        ],
      ),
    );
  }

  Widget _kartuRingkasan(SkdnBulan b) {
    return SectionCard(
      title: 'Ringkasan ${b.label}',
      icon: Icons.analytics_outlined,
      child: Column(
        children: [
          _barisJumlah('S', 'Jumlah seluruh balita', b.s, bg: _abuMuda, fg: Colors.black87),
          _barisJumlah('K', 'Balita yang punya Buku KIA', b.k, bg: _abuMuda, fg: Colors.black87),
          _barisJumlah('D', 'Balita yang datang ditimbang', b.d),
          _barisJumlah('N', 'Balita yang berat badannya naik', b.n, bg: AppColors.biruMuda, fg: AppColors.biru),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ persentase

  Widget _barisPersen(String judul, String rumus, double nilai, Color warna, {double? target}) {
    final capai = target == null || nilai >= target;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(judul, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              Text(_persen(nilai), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: warna)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (nilai / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.latar,
              color: warna,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(rumus, style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
              const Spacer(),
              if (target != null)
                Text(
                  capai ? 'Target ${_persen(target)} tercapai' : 'Belum mencapai target ${_persen(target)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: capai ? AppColors.hijau : AppColors.merah,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kartuPersentase(SkdnData d) {
    final b = d.bulan;
    return SectionCard(
      title: 'Persentase',
      icon: Icons.percent,
      trailing: Pill(
        d.capaiTarget ? 'Kehadiran baik' : 'Kehadiran kurang',
        bg: d.capaiTarget ? AppColors.hijauMuda : AppColors.merahMuda,
        fg: d.capaiTarget ? AppColors.hijau : AppColors.merah,
      ),
      child: Column(
        children: [
          _barisPersen('Tingkat kehadiran balita', 'Datang ditimbang ÷ seluruh balita (D/S)', b.persenDS,
              d.capaiTarget ? AppColors.hijau : AppColors.merah,
              target: d.targetDS),
          _barisPersen('Balita yang tumbuh baik dari yang ditimbang', 'Berat badan naik ÷ datang ditimbang (N/D)',
              b.persenND, AppColors.biru),
          _barisPersen('Balita yang punya Buku KIA', 'Punya Buku KIA ÷ seluruh balita (K/S)', b.persenKS, _abu),
          _barisPersen('Kehadiran balita yang punya Buku KIA', 'Datang ditimbang ÷ punya Buku KIA (D/K)', b.persenDK,
              AppColors.hijau),
          _barisPersen('Balita yang tumbuh baik dari seluruh balita', 'Berat badan naik ÷ seluruh balita (N/S)',
              b.persenNS, AppColors.biru),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- rincian

  Widget _barisRincian(IconData ikon, String label, int nilai, Color fg, Color bg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(ikon, size: 16, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
          Text('$nilai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fg)),
        ],
      ),
    );
  }

  Widget _kartuRincian(SkdnBulan b) {
    return SectionCard(
      title: 'Rincian Balita yang Ditimbang',
      icon: Icons.monitor_weight_outlined,
      trailing: Pill('${b.d} balita', bg: AppColors.hijauMuda, fg: AppColors.hijau),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barisRincian(Icons.trending_up, 'Berat badan naik', b.n, AppColors.hijau, AppColors.hijauMuda),
          _barisRincian(Icons.trending_flat, 'Berat badan tidak naik', b.t, AppColors.kuning, AppColors.kuningMuda),
          _barisRincian(Icons.help_outline, 'Bulan lalu tidak ditimbang, belum bisa dinilai', b.o, _abu, _abuMuda),
          _barisRincian(Icons.fiber_new_outlined, 'Baru pertama kali ditimbang', b.b, AppColors.biru, AppColors.biruMuda),
          const Divider(height: 18),
          _barisRincian(Icons.warning_amber_rounded, 'Tidak naik 2 bulan berturut-turut (perlu dirujuk)', b.duaT,
              AppColors.merah, AppColors.merahMuda),
          _barisRincian(Icons.warning_amber_rounded, 'Berat badan sangat kurang / bawah garis merah (perlu dirujuk)',
              b.bgm, AppColors.merah, AppColors.merahMuda),
          _barisRincian(Icons.person_off_outlined, 'Balita yang tidak datang ditimbang', b.tidakDatang, _abu, _abuMuda),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ tren

  Widget _kartuTren(SkdnData d) {
    return SectionCard(
      title: 'Perkembangan 6 Bulan',
      icon: Icons.show_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final t in d.tren)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _batang(t.persenDS, AppColors.hijau),
                            const SizedBox(width: 3),
                            _batang(t.persenND, AppColors.biru),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.labelSingkat,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: t.bulan == d.bulan.bulan ? FontWeight.w900 : FontWeight.w500,
                            color: t.bulan == d.bulan.bulan ? Colors.black87 : AppColors.teksRedup,
                          ),
                        ),
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
              _legenda(AppColors.hijau, 'Tingkat kehadiran (D/S)'),
              _legenda(AppColors.biru, 'Tumbuh baik (N/D)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _batang(double persen, Color warna) {
    final double tinggi = 110 * (persen / 100).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(persen == 0 ? '' : persen.toStringAsFixed(0),
            style: const TextStyle(fontSize: 8.5, color: AppColors.teksRedup)),
        const SizedBox(height: 2),
        Container(
          width: 12,
          height: tinggi < 2 ? 2 : tinggi,
          decoration: BoxDecoration(
            color: persen == 0 ? _abuMuda : warna,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _legenda(Color warna, String teks) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(teks, style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
        ],
      );

  // ------------------------------------------------------------ daftar anak

  Widget _kartuAnak(String judul, IconData ikon, Color fg, Color bg, List<AnakSkdn> list, String kosong) {
    return SectionCard(
      title: judul,
      icon: ikon,
      trailing: Pill('${list.length} balita', bg: bg, fg: fg),
      child: list.isEmpty
          ? Text(kosong, style: const TextStyle(fontSize: 12.5, color: AppColors.teksRedup))
          : Column(children: [for (final a in list) _barisAnak(a, fg, bg)]),
    );
  }

  Widget _barisAnak(AnakSkdn a, Color fg, Color bg) {
    final naik = a.kenaikanGram;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _bukaAnak(a),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: bg,
                  child: Icon(Icons.child_care, size: 18, color: fg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text('${a.jkTeks} · ${a.usiaTeks}',
                          style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                      const SizedBox(height: 4),
                      Text(a.keterangan, style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'BB ${a.bbKg} kg'
                        '${naik == null ? '' : ' · ${naik > 0 ? '+' : ''}$naik g'}'
                        '${a.kbmGram == null ? '' : ' (minimal ${a.kbmGram} g)'}'
                        '${a.tanggalUkur == null ? '' : ' · ${formatTanggal(a.tanggalUkur!)}'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.teksRedup),
                      ),
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