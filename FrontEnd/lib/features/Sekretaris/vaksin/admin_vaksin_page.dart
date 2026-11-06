import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../core/posyandu.dart';
import '../../../service/vaksin_service.dart';

const _hijauHeader = Color(0xFF065F46);

/// Judul header ekstra tebal (sama seperti halaman Akun).
/// Lapis bawah: garis tepi putih agar huruf lebih gemuk; lapis atas: isi putih.
Widget _judulTebal(String teks) {
  const ukuran = 20.0;
  const jarak = 1.2; // jarak antar huruf

  return Stack(
    children: [
      // Lapis bawah: garis tepi untuk menebalkan huruf
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        ),
      ),
      // Lapis atas: isi huruf
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Color(0x40000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Sekretaris: rekap imunisasi posyandu (cakupan, anak terlambat, jumlah dosis per jenis)
/// dan jadwal imunisasi rutin yang berlaku.
class AdminVaksinPage extends StatefulWidget {
  const AdminVaksinPage({super.key});

  @override
  State<AdminVaksinPage> createState() => _AdminVaksinPageState();
}

class _AdminVaksinPageState extends State<AdminVaksinPage> {
  final _svc = VaksinService();
  StatistikVaksin? _data;
  List<JadwalImunisasi> _jadwal = [];
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
      final hasil = await Future.wait([_svc.statistik(), _svc.jadwalMaster()]);
      if (!mounted) return;
      setState(() {
        _data = hasil[0] as StatistikVaksin;
        _jadwal = hasil[1] as List<JadwalImunisasi>;
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

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
  // Tombol kembali hanya muncul bila ada halaman sebelumnya.
  // -------------------------------------------------------------------------
  Widget _header() {
    final bisaKembali = Navigator.canPop(context);

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
              // Judul di tengah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal('Data Imunisasi'),
              ),
              // Tombol kembali di kiri
              if (bisaKembali)
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
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: _loading
                    ? ListView(children: const [
                        SizedBox(height: 200),
                        Center(child: CircularProgressIndicator()),
                      ])
                    : (_error != null && _data == null)
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              const SizedBox(height: 120),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 15.5)),
                              const SizedBox(height: 12),
                              Center(
                                  child: AppButton('Coba Lagi',
                                      icon: Icons.refresh, onPressed: _muat)),
                            ],
                          )
                        : _isi(_data!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _isi(StatistikVaksin d) {
    final maks = d.jenis.fold<int>(0, (m, e) => e.jumlahDosis > m ? e.jumlahDosis : m);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Cakupan Imunisasi',
          icon: Icons.verified_user_outlined,
          trailing: Pill(labelPosyandu(d.posyandu), bg: AppColors.hijauMuda, fg: AppColors.hijau),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${d.persenIdl}%',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.hijau)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Imunisasi Dasar Lengkap: ${d.anakDasarLengkap} dari ${d.anakUsia12Bulan} '
                      'anak usia 12 bulan ke atas',
                      style: const TextStyle(fontSize: 14, color: AppColors.teksRedup),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: d.anakUsia12Bulan == 0 ? 0 : d.anakDasarLengkap / d.anakUsia12Bulan,
                  minHeight: 9,
                  backgroundColor: AppColors.latar,
                  color: AppColors.hijau,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatBox(
                        nilai: '${d.totalDiberikan}',
                        label: 'Dosis\nDiberikan',
                        bg: AppColors.hijauMuda,
                        fg: AppColors.hijau),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatBox(
                        nilai: '${d.totalAnakDivaksin}',
                        label: 'Anak\nDivaksin',
                        bg: AppColors.biruMuda,
                        fg: AppColors.biru),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatBox(
                        nilai: '${d.jumlahBalita}',
                        label: 'Balita\nAktif',
                        bg: AppColors.isiField,
                        fg: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatBox(
                        nilai: '${d.anakJatuhTempo}',
                        label: 'Anak Saatnya\nDivaksin',
                        bg: AppColors.kuningMuda,
                        fg: AppColors.kuning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatBox(
                        nilai: '${d.anakTerlambat}',
                        label: 'Anak\nTerlambat',
                        bg: AppColors.merahMuda,
                        fg: AppColors.merah),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Jumlah Pemberian per Vaksin',
          icon: Icons.list_alt_outlined,
          trailing: Pill('${d.jenis.length} jenis', bg: AppColors.biruMuda, fg: AppColors.biru),
          child: d.jenis.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('Belum ada data jenis vaksin',
                        style: TextStyle(fontSize: 15, color: AppColors.teksRedup)),
                  ),
                )
              : Column(children: [for (final e in d.jenis) _barisJenis(e, maks)]),
        ),
        SectionCard(
          title: 'Jadwal Imunisasi Rutin',
          icon: Icons.event_note_outlined,
          trailing: const Pill('Kemenkes RI', bg: AppColors.hijauMuda, fg: AppColors.hijau),
          child: _jadwalMaster(),
        ),
      ],
    );
  }

  Widget _barisJenis(StatistikJenisVaksin e, int maks) {
    final nilai = maks == 0 ? 0.0 : e.jumlahDosis / maks;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.jenis.nama,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (e.jenis.penyakit.isNotEmpty)
                      Text(e.jenis.penyakit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill('${e.jumlahDosis} dosis', bg: AppColors.hijauMuda, fg: AppColors.hijau),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: nilai,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppColors.hijau,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${e.jumlahAnak} anak sudah menerima · ${e.dosisPerAnak} dosis per anak'
            '${e.jenis.khususDaerah ? ' · khusus daerah endemis' : ''}',
            style: const TextStyle(fontSize: 13.5, color: AppColors.teksRedup),
          ),
        ],
      ),
    );
  }

  Widget _jadwalMaster() {
    if (_jadwal.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('Jadwal imunisasi belum tersedia',
              style: TextStyle(fontSize: 15, color: AppColors.teksRedup)),
        ),
      );
    }
    final grup = <String, List<JadwalImunisasi>>{};
    for (final j in _jadwal) {
      grup.putIfAbsent(j.labelUsia, () => []).add(j);
    }
    return Column(
      children: [
        for (final g in grup.entries)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(g.key,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final j in g.value)
                        Pill(j.namaDosis,
                            bg: j.lanjutan ? AppColors.biruMuda : Colors.white,
                            fg: j.lanjutan ? AppColors.biru : Colors.black87),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}