import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../service/imunisasi_service.dart';

const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Kartu putih berbayangan: judul tebal kapital, keterangan kanan, garis aksen, lalu isi.
Widget _kartu({required String judul, String? kanan, required Widget child}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  judul.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: _teksGelap,
                  ),
                ),
              ),
              if (kanan != null) ...[
                const SizedBox(width: 10),
                Text(kanan,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
              ],
            ],
          ),
        ),
        Container(height: 3, color: _aksen),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ],
    ),
  );
}

/// Kotak kecil di dalam kartu: putih dengan garis tepi hitam lembut.
BoxDecoration _dekorDalam() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFB8BEC6), width: 1.2),
    );

/// Baris "Label : nilai" (satu warna hitam).
Widget _baris(String label, String nilai, {double lebar = 150}) {
  const gaya = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.35, color: _teksGelap);
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: lebar, child: Text(label, style: gaya)),
        const Text(': ', style: gaya),
        Expanded(child: Text(nilai, style: gaya)),
      ],
    ),
  );
}

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
class AdminImunisasiPage extends StatefulWidget {
  const AdminImunisasiPage({super.key});

  @override
  State<AdminImunisasiPage> createState() => _AdminImunisasiPageState();
}

class _AdminImunisasiPageState extends State<AdminImunisasiPage> {
  final _svc = ImunisasiService();
  StatistikImunisasi? _data;
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
        _data = hasil[0] as StatistikImunisasi;
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
  // HEADER (sama seperti halaman Imunisasi Anak: polos, judul di tengah)
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

  Widget _isi(StatistikImunisasi d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _kartu(
          judul: 'Cakupan Imunisasi',
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
                  _kotak('Anak\nDiimunisasi', '${d.totalAnakDiimunisasi}',
                      const Color(0xFFE3F2FD), const Color(0xFFBFDFF7), const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  _kotak('Balita\nAktif', '${d.jumlahBalita}',
                      const Color(0xFFF3F4F6), const Color(0xFFE5E7EB), const Color(0xFF374151)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _kotak('Saatnya Diimunisasi', '${d.anakJatuhTempo}',
                      const Color(0xFFFFF4DC), const Color(0xFFF9E0A8), const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  _kotak('Anak Terlambat', '${d.anakTerlambat}',
                      const Color(0xFFFDEAF1), const Color(0xFFF6C9D9), const Color(0xFFE11D48)),
                ],
              ),
            ],
          ),
        ),
        _kartu(
          judul: 'Jumlah Pemberian per Imunisasi',
          kanan: '${d.jenis.length} jenis',
          child: d.jenis.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('Belum ada data jenis imunisasi',
                        style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                  ),
                )
              : Column(children: [for (final e in d.jenis) _barisJenis(e, d.jumlahBalita)]),
        ),
        _kartu(
          judul: 'Jadwal Imunisasi Rutin',
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

  Widget _barisJenis(StatistikJenisImunisasi e, int jumlahBalita) {
    final belum = (jumlahBalita - e.jumlahAnak) < 0 ? 0 : jumlahBalita - e.jumlahAnak;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _dekorDalam(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.jenis.nama,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: _teksGelap)),
          if (e.jenis.penyakit.isNotEmpty)
            Text(e.jenis.penyakit,
                style: const TextStyle(fontSize: 15.5, color: AppColors.teksRedup)),
          const SizedBox(height: 8),
          Text(
            'Satu anak hanya bisa menerima ${e.dosisPerAnak} dosis'
            '${e.jenis.khususDaerah ? ' (khusus daerah endemis)' : ''}',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap),
          ),
          const SizedBox(height: 6),
          _baris('Anak yang sudah menerima', '${e.jumlahAnak} anak', lebar: 200),
          _baris('Anak yang belum', '$belum anak', lebar: 200),
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
            decoration: _dekorDalam(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _baris('Usia', g.key, lebar: 108),
                _baris('Jenis imunisasi', g.value.map((j) => j.namaDosis).join(', '), lebar: 108),
              ],
            ),
          ),
      ],
    );
  }
}