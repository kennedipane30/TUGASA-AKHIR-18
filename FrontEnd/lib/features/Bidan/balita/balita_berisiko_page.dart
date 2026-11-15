import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/pages/balita/balita_detail_page.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../service/balita_service.dart';
import '../../../core/pages/rekap/rekap_posyandu_page.dart';

const _hijauTua = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

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
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 17),
                            ),
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
    final duaTBgm = d.anak.where((a) => a.balita.perluPerhatian).length;
    return [
      KartuRekap(
        title: 'Ringkasan Risiko',
        trailing: teksKananRekap('${r.total} anak'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diurutkan dari yang paling perlu ditangani.
            _barisJumlah('Risiko tinggi', r.tinggi, AppColors.merah),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _barisJumlah('Gizi buruk', r.giziBuruk, AppColors.merah),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _barisJumlah('2T / BGM', duaTBgm, AppColors.merah),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _barisJumlah('Stunting', r.stunting, AppColors.kuning),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _barisJumlah('Risiko sedang', r.sedang, AppColors.kuning),
            const SizedBox(height: 10),
            const Text(
              'Dinilai dari penimbangan terakhir setiap balita aktif, sesuai Permenkes No. 2 Tahun 2020 dan KBM Buku KIA.',
              style: TextStyle(fontSize: 16, color: AppColors.teksRedup),
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
                  selectedColor: _hijauTua,
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  side: BorderSide(color: _aktif == f ? _hijauTua : garisKartuRekap, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      const SizedBox(height: 12),
      if (daftar.isEmpty)
        KartuRekap(
          child: Text(
            d.anak.isEmpty ? 'Tidak ada anak berisiko di posyandu ini' : 'Tidak ada anak pada filter ini',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.teksRedup),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: dekorKartuRekap(),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _buka(a),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kepala kartu: nama di kiri, tingkat risiko di kanan, garis aksen di bawah.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          b.nama.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: _teksGelap,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(a.tinggi ? 'Risiko tinggi' : 'Risiko sedang',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: warna)),
                    ],
                  ),
                ),
                Container(height: 3, color: aksenKartuRekap),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _baris('Jenis Kelamin', b.jkTeks),
                      _baris('Umur', b.usiaTeks),
                      if (t != null) ...[
                        _baris('Ditimbang', t.tanggal == null ? '-' : formatTanggal(t.tanggal!)),
                        _baris('BB / TB', '${t.bbKg} kg / ${t.tbCm} cm'),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final x in a.alasan) Pill(x, bg: latar, fg: warna),
                        ],
                      ),
                      if (b.bulanTidakDatang >= 2) ...[
                        const SizedBox(height: 8),
                        Text('Tidak ditimbang ${b.bulanTidakDatang} bulan, perlu kunjungan rumah.',
                            style: const TextStyle(fontSize: 15.5, color: AppColors.merah)),
                      ],
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Lihat detail',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: aksenKartuRekap,
                            decoration: TextDecoration.underline,
                            decorationColor: aksenKartuRekap,
                          ),
                        ),
                      ),
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

  /// Baris ringkasan: keterangan di kiri, jumlah balita di kanan.
  Widget _barisJumlah(String label, int nilai, Color warna) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _teksGelap)),
          ),
          Text('$nilai balita',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: nilai == 0 ? AppColors.teksRedup : warna)),
        ],
      ),
    );
  }

  /// Baris "Label : nilai" (satu warna hitam).
  Widget _baris(String label, String nilai) {
    const gaya = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.35, color: _teksGelap);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 118, child: Text(label, style: gaya)),
          const Text(': ', style: gaya),
          Expanded(child: Text(nilai.isEmpty ? '-' : nilai, style: gaya)),
        ],
      ),
    );
  }
}