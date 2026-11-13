import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/posyandu.dart';
import '../../../service/vaksin_service.dart';

const _hijauHeader = Color(0xFF065F46);

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
                                  style: const TextStyle(fontSize: 16.5)),
                              const SizedBox(height: 12),
                              Center(
                                  child: AppButton('Coba Lagi', onPressed: _muat)),
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
          trailing: Pill(labelPosyandu(d.posyandu), bg: AppColors.hijauMuda, fg: AppColors.hijau),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${d.persenIdl}%',
                      style: const TextStyle(
                          fontSize: 29, fontWeight: FontWeight.w600, color: AppColors.hijau)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Imunisasi Dasar Lengkap: ${d.anakDasarLengkap} dari ${d.anakUsia12Bulan} '
                      'anak usia 12 bulan ke atas',
                      style: const TextStyle(fontSize: 16, color: AppColors.teksRedup),
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
                  _kotak('Dosis\nDiberikan', '${d.totalDiberikan}',
                      const Color(0xFFE6F8EF), const Color(0xFFBDEBD3), const Color(0xFF059669)),
                  const SizedBox(width: 8),
                  _kotak('Anak\nDivaksin', '${d.totalAnakDivaksin}',
                      const Color(0xFFE3F2FD), const Color(0xFFBFDFF7), const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  _kotak('Balita\nAktif', '${d.jumlahBalita}',
                      const Color(0xFFF3F4F6), const Color(0xFFE5E7EB), const Color(0xFF374151)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _kotak('Saatnya Divaksin', '${d.anakJatuhTempo}',
                      const Color(0xFFFFF4DC), const Color(0xFFF9E0A8), const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  _kotak('Anak Terlambat', '${d.anakTerlambat}',
                      const Color(0xFFFDEAF1), const Color(0xFFF6C9D9), const Color(0xFFE11D48)),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Jumlah Pemberian per Vaksin',
          trailing: Pill('${d.jenis.length} jenis', bg: AppColors.biruMuda, fg: AppColors.biru),
          child: d.jenis.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('Belum ada data jenis vaksin',
                        style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                  ),
                )
              : Column(children: [for (final e in d.jenis) _barisJenis(e, maks)]),
        ),
        SectionCard(
          title: 'Jadwal Imunisasi Rutin',
          child: _jadwalMaster(),
        ),
      ],
    );
  }

  /// Kotak angka kecil: angka di atas, keterangan di bawah, rata tengah.
  Widget _kotak(String label, String nilai, Color bg, Color garis, Color fg) {
    return Expanded(
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: garis),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(nilai,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: fg, height: 1.1)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: fg, height: 1.2)),
          ],
        ),
      ),
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
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                    if (e.jenis.penyakit.isNotEmpty)
                      Text(e.jenis.penyakit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
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
            style: const TextStyle(fontSize: 16, color: AppColors.teksRedup),
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
              style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.key,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final j in g.value)
                      Pill(j.namaDosis,
                          bg: j.lanjutan ? AppColors.biruMuda : Colors.white,
                          fg: j.lanjutan ? AppColors.biru : Colors.black87),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}