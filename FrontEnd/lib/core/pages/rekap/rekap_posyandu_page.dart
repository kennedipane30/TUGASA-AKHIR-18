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

  @override
  Widget build(BuildContext context) {
    const label = ['Penimbangan', 'Status Gizi', 'Vitamin A'];
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