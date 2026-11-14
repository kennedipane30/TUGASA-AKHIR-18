import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../../service/rekap_service.dart';
import 'skdn_page.dart';

// Halaman Rekap Posyandu dipecah menjadi 3 file (satu library):
//   rekap_posyandu_page.dart : komponen bersama, halaman utama, balita tidak hadir
//   rekap_gizi.dart          : tab Status Gizi
//   rekap_suplemen.dart      : tab Vitamin A & Obat Cacing
part 'rekap_gizi.dart';
part 'rekap_suplemen.dart';

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

// ----------------------------------------------------------------------------
// Bantuan membaca rekap (bahasa sehari-hari untuk sekretaris & bidan)
// ----------------------------------------------------------------------------

enum StatusKesimpulan { baik, perhatian, kosong }

/// Kartu "Kesimpulan" berisi kalimat sederhana di bagian paling atas rekap.
class KartuKesimpulan extends StatelessWidget {
  final StatusKesimpulan status;
  final String judul;
  final List<String> poin;

  const KartuKesimpulan({super.key, required this.status, required this.judul, required this.poin});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      StatusKesimpulan.baik => (AppColors.hijauMuda, AppColors.hijau, 'Baik'),
      StatusKesimpulan.perhatian => (AppColors.kuningMuda, AppColors.kuning, 'Perlu perhatian'),
      StatusKesimpulan.kosong => (_abuMuda, _abu, 'Belum ada data'),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withAlpha(90), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Kesimpulan', style: TextStyle(fontSize: 15, color: AppColors.teksRedup)),
              ),
              Pill(label, bg: bg, fg: fg),
            ],
          ),
          const SizedBox(height: 4),
          Text(judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final p in poin)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 16, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Kartu biru kecil "Ketuk untuk penjelasan".
class KartuBantuan extends StatelessWidget {
  final String teks;
  final VoidCallback onTap;

  const KartuBantuan({super.key, required this.teks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.biruMuda,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.help_outline, color: AppColors.biru, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(teks,
                    style: const TextStyle(fontSize: 15.5, color: AppColors.biru, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.biru),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lembar penjelasan istilah (bottom sheet).
void tampilkanPenjelasan(
  BuildContext context, {
  required String judul,
  String? pembuka,
  required List<(String, String)> poin,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
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
              Text(judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (pembuka != null) ...[
                const SizedBox(height: 10),
                Text(pembuka, style: const TextStyle(fontSize: 16, height: 1.45)),
              ],
              const SizedBox(height: 14),
              for (final (istilah, arti) in poin)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(istilah, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(arti, style: const TextStyle(fontSize: 15.5, color: AppColors.teksRedup, height: 1.4)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
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
// HALAMAN REKAP POSYANDU (SEKRETARIS & BIDAN)
// ============================================================================

/// Rekap posyandu untuk sekretaris dan bidan, 3 tab:
/// 1. Penimbangan (SKDN) + daftar balita tidak hadir
/// 2. Status Gizi
/// 3. Vitamin A & Obat Cacing
/// [prefix] '/sekretaris' atau '/bidan'.
class RekapPosyanduPage extends StatefulWidget {
  final String prefix;
  final int tabAwal;

  const RekapPosyanduPage({super.key, required this.prefix, this.tabAwal = 0});

  @override
  State<RekapPosyanduPage> createState() => _RekapPosyanduPageState();
}

class _RekapPosyanduPageState extends State<RekapPosyanduPage> {
  late int _tab = widget.tabAwal;

  /// Satu tombol tab berbentuk kartu sendiri.
  Widget _kartuTab(int i, String label) {
    final aktif = _tab == i;
    return Expanded(
      child: Material(
        color: aktif ? AppColors.hijau : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _tab = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: aktif ? Colors.white : Colors.black87,
              ),
            ),
          ),
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
            headerRekap(context, 'Rekap Posyandu'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  _kartuTab(0, 'Penimbangan'),
                  const SizedBox(width: 8),
                  _kartuTab(1, 'Status Gizi'),
                  const SizedBox(width: 8),
                  _kartuTab(2, 'Vitamin A'),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  SkdnView(prefix: widget.prefix, tampilTidakHadir: true),
                  _TabGizi(prefix: widget.prefix),
                  _TabSuplemen(prefix: widget.prefix),
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
// BALITA TIDAK HADIR (halaman kader; sekretaris melihatnya di tab Penimbangan)
// ============================================================================

/// Daftar balita sasaran yang tidak ditimbang pada bulan terpilih (S − D).
/// [prefix] '/sekretaris', '/bidan', atau '/kader'.
class TidakHadirView extends StatefulWidget {
  final String prefix;

  const TidakHadirView({super.key, required this.prefix});

  @override
  State<TidakHadirView> createState() => _TidakHadirViewState();
}

class _TidakHadirViewState extends State<TidakHadirView> {

  final _svc = RekapService();
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);
  RekapTidakHadir? _data;
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
    return [
      SectionCard(
        title: 'Kehadiran ${d.label}',
        trailing: Pill('${d.jumlahJadwal} jadwal', bg: AppColors.biruMuda, fg: AppColors.biru),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: StatBox(nilai: '${d.sasaran}', label: 'Semua\nbalita')),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${d.ditimbang}', label: 'Datang\nditimbang', bg: AppColors.hijauMuda, fg: AppColors.hijau),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${d.tidakHadir}',
                      label: 'Tidak\ndatang',
                      bg: AppColors.merahMuda,
                      fg: AppColors.merah),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _batang('Kehadiran balita', d.ditimbang, d.sasaran, AppColors.hijau, AppColors.hijauMuda,
                sub: 'Target posyandu minimal 85%'),
            if (d.jumlahJadwal == 0)
              const Text('Belum ada jadwal posyandu pada bulan ini.',
                  style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
          ],
        ),
      ),
      DaftarTidakHadir(data: d),
    ];
  }
}

// ============================================================================
// DAFTAR BALITA TIDAK HADIR (filter + kartu)
// Dipakai tab Penimbangan sekretaris dan halaman Tidak Hadir kader.
// ============================================================================
class DaftarTidakHadir extends StatefulWidget {
  final RekapTidakHadir data;

  const DaftarTidakHadir({super.key, required this.data});

  @override
  State<DaftarTidakHadir> createState() => _DaftarTidakHadirState();
}

class _DaftarTidakHadirState extends State<DaftarTidakHadir> {
  static const _filter = ['Semua', '≥ 2 bulan', 'Belum pernah', 'Sudah mendaftar'];
  static const _ketFilter = {
    'Semua': 'Semua balita yang tidak datang bulan ini.',
    '≥ 2 bulan': 'Tidak datang 2 bulan atau lebih. Sebaiknya dikunjungi ke rumah.',
    'Belum pernah': 'Terdaftar tetapi belum pernah ditimbang sama sekali.',
    'Sudah mendaftar': 'Sudah mendaftar, tetapi tidak datang/check-in.',
  };
  String _aktif = 'Semua';

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final daftar = switch (_aktif) {
      '≥ 2 bulan' => d.anak.where((a) => a.bulanTidakDatang >= 2).toList(),
      'Belum pernah' => d.anak.where((a) => a.belumPernah).toList(),
      'Sudah mendaftar' => d.anak.where((a) => a.sudahMendaftar).toList(),
      _ => d.anak,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 6),
        Text(_ketFilter[_aktif] ?? '', style: const TextStyle(fontSize: 15, color: AppColors.teksRedup)),
        const SizedBox(height: 10),
        if (daftar.isEmpty)
          SectionCard(
            child: _kosong(
              Icons.verified_outlined,
              d.anak.isEmpty ? 'Semua balita sasaran sudah ditimbang bulan ini' : 'Tidak ada balita pada filter ini',
            ),
          ),
        for (final a in daftar) _kartu(a),
      ],
    );
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