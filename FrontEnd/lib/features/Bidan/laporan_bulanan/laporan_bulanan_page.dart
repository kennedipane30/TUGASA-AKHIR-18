import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/auth_provider.dart';
import '../../../service/laporan_bulanan_service.dart';
import '../../../service/rekap_service.dart' show namaBulanRekap;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/posyandu.dart';
import '../../../core/pages/rekap/rekap_posyandu_page.dart';
import 'laporan_bulanan_pdf.dart';

// ============================================================================
// LAPORAN BULANAN POSYANDU - BIDAN
// Pilih bulan -> laporan tampil -> unduh / bagikan PDF.
// ============================================================================

const _garis = Color(0xFFB8BEC6);
const _teks = Color(0xFF1F2937);
const _redup = Color(0xFF64748B);

class BidanLaporanBulananPage extends StatefulWidget {
  const BidanLaporanBulananPage({super.key});

  @override
  State<BidanLaporanBulananPage> createState() => _BidanLaporanBulananPageState();
}

class _BidanLaporanBulananPageState extends State<BidanLaporanBulananPage> {
  final _svc = const LaporanBulananService('/bidan');
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);
  LaporanBulanan? _data;
  bool _loading = true;
  String? _error;
  bool _mengunduh = false;
  bool _membagikan = false;

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
      final d = await _svc.ambil(_bulan);
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

  void _snack(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  String get _namaPencetak {
    final u = context.read<AuthProvider>().user;
    return (u?['nama'] ?? '').toString().trim();
  }

  String _namaFile(LaporanBulanan d) {
    final pos = labelPosyandu(d.posyandu).replaceAll(' ', '_');
    return 'Laporan_Bulanan_${pos}_${namaBulanRekap[_bulan.month]}_${_bulan.year}.pdf';
  }

  Future<Uint8List> _pdf(LaporanBulanan d) =>
      buatPdfLaporanBulananBidan(data: d, namaPencetak: _namaPencetak);

  /// Unduh: membuka layar cetak HP, lalu pilih "Simpan sebagai PDF".
  Future<void> _unduh() async {
    final d = _data;
    if (d == null || _mengunduh) return;
    setState(() => _mengunduh = true);
    try {
      final bytes = await _pdf(d);
      await Printing.layoutPdf(name: _namaFile(d), onLayout: (_) async => bytes);
    } catch (e) {
      _snack('PDF gagal dibuat: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _mengunduh = false);
    }
  }

  /// Bagikan: file PDF dikirim lewat menu bagikan HP (WhatsApp, email, Drive, ...).
  Future<void> _bagikan() async {
    final d = _data;
    if (d == null || _membagikan) return;
    setState(() => _membagikan = true);
    try {
      final bytes = await _pdf(d);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_namaFile(d)}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final kotak = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: 'Laporan Bulanan Posyandu ${labelPosyandu(d.posyandu)} - ${d.label}',
          subject: 'Laporan Bulanan Posyandu ${labelPosyandu(d.posyandu)} - ${d.label}',
          sharePositionOrigin:
              kotak == null ? null : kotak.localToGlobal(Offset.zero) & kotak.size,
        ),
      );
    } catch (e) {
      _snack('PDF gagal dibagikan: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _membagikan = false);
    }
  }

  // -------------------------------------------------------------------------
  // KOMPONEN
  // -------------------------------------------------------------------------

  String _persen(double v) {
    final t = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '${t.replaceAll('.', ',')}%';
  }

  Widget _baris(String label, String nilai, {String? sub, bool tebal = false, bool akhir = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: akhir ? null : const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15, color: _teks, fontWeight: tebal ? FontWeight.w700 : FontWeight.w500)),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 13, color: _redup)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(nilai,
              style: TextStyle(
                  fontSize: 15.5, color: _teks, fontWeight: tebal ? FontWeight.w800 : FontWeight.w700)),
        ],
      ),
    );
  }

  List<Widget> _daftarBaris(List<(String, String, String?)> isi, {Set<int> tebal = const {}}) => [
        for (var i = 0; i < isi.length; i++)
          _baris(isi[i].$1, isi[i].$2, sub: isi[i].$3, tebal: tebal.contains(i), akhir: i == isi.length - 1),
      ];

  Widget _kosong(String teks) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(teks, style: const TextStyle(fontSize: 14.5, color: _redup)),
      );

  Widget _kartuKegiatan(LaporanBulanan d) {
    final k = d.kegiatan;
    final tgl = k.tanggalSesi.map((t) => '${t.day} ${namaBulanRekap[t.month]}').join(', ');
    return KartuRekap(
      title: 'I. Kegiatan & Kehadiran',
      trailing: teksKananRekap('${k.jumlahSesi} sesi'),
      child: Column(
        children: _daftarBaris([
          ('Jadwal posyandu', k.jumlahSesi == 0 ? 'Tidak ada' : '${k.jumlahSesi} sesi', tgl.isEmpty ? null : tgl),
          ('Balita sasaran (0-59 bulan)', '${k.sasaran}', null),
          ('Didaftarkan ke sesi', '${k.didaftarkan}', null),
          ('Hadir (check-in)', '${k.hadir}', null),
          ('Tidak hadir', '${k.tidakHadir}', null),
          ('Persentase kehadiran', _persen(k.persenHadir), null),
        ], tebal: {5}),
      ),
    );
  }

  Widget _kartuSkdn(LaporanBulanan d) {
    final s = d.skdn;
    return KartuRekap(
      title: 'II. Penimbangan (SKDN)',
      trailing: teksKananRekap('D/S ${_persen(s.persenDS)}'),
      child: Column(
        children: _daftarBaris([
          ('S - Seluruh balita', '${s.s}', null),
          ('K - Punya Buku KIA / terdaftar', '${s.k}', 'K/S = ${_persen(s.persenKS)}'),
          ('D - Ditimbang bulan ini', '${s.d}', 'D/S = ${_persen(s.persenDS)}'),
          ('N - Berat badan naik', '${s.n}', 'N/D = ${_persen(s.persenND)}'),
        ]),
      ),
    );
  }

  Widget _kartuGizi(LaporanBulanan d) {
    final g = d.gizi;
    return KartuRekap(
      title: 'III. Status Gizi',
      trailing: teksKananRekap('${g.diukur} diukur'),
      child: Column(
        children: _daftarBaris([
          for (final x in g.kategori) (x.label, '${x.jumlah}', x.indeks),
          ('2T (dua kali tidak naik)', '${d.skdn.duaT}', 'Penimbangan'),
          ('BGM (bawah garis merah)', '${d.skdn.bgm}', 'Penimbangan'),
        ]),
      ),
    );
  }

  Widget _kartuImunisasi(LaporanBulanan d) {
    return KartuRekap(
      title: 'IV. Imunisasi',
      trailing: teksKananRekap('${d.totalImunisasi} pemberian'),
      child: d.imunisasi.isEmpty
          ? _kosong('Tidak ada imunisasi di posyandu bulan ini.')
          : Column(
              children: _daftarBaris([
                for (final v in d.imunisasi) (v.nama, '${v.jumlah}', null),
                ('Total pemberian', '${d.totalImunisasi}', null),
              ], tebal: {d.imunisasi.length}),
            ),
    );
  }

  Widget _kartuSuplemen(LaporanBulanan d) {
    return KartuRekap(
      title: 'V. Suplemen',
      child: d.suplemen.isEmpty
          ? _kosong('Tidak ada pemberian suplemen bulan ini.')
          : Column(
              children: _daftarBaris([
                for (final s in d.suplemen) (s.nama, '${s.jumlah} balita', null),
              ]),
            ),
    );
  }

  Widget _kartuBerisiko(LaporanBulanan d) {
    final list = d.balitaBerisiko;
    return KartuRekap(
      title: 'VI. Balita Berisiko',
      trailing: teksKananRekap('${list.length} balita'),
      child: list.isEmpty
          ? _kosong('Tidak ada balita berisiko bulan ini.')
          : Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: i == list.length - 1 ? 0 : 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _garis, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ${list[i].nama}',
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _teks)),
                        const SizedBox(height: 3),
                        Text(
                          '${list[i].jk == 'L' ? 'Laki-laki' : list[i].jk == 'P' ? 'Perempuan' : '-'}'
                          '  |  ${list[i].usiaTeks}',
                          style: const TextStyle(fontSize: 13.5, color: _redup),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final m in list[i].masalah)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.merahMuda,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(m,
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.merah)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  /// VII. KPSP: khusus bidan, terisi setelah fitur KPSP tersedia.
  Widget _kartuKpsp() {
    return KartuRekap(
      title: 'VII. Hasil KPSP',
      trailing: teksKananRekap('Khusus bidan'),
      child: Column(
        children: [
          ..._daftarBaris([
            ('Sesuai (S)', '-', null),
            ('Meragukan (M)', '-', null),
            ('Kemungkinan ada penyimpangan (P)', '-', null),
          ]),
          const SizedBox(height: 6),
          _kosong('Akan terisi setelah fitur KPSP tersedia.'),
        ],
      ),
    );
  }

  Widget _tombol({
    required String label,
    required IconData ikon,
    required bool proses,
    required VoidCallback? onTap,
    bool isi = true,
  }) {
    final balita = proses
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: isi ? Colors.white : AppColors.hijau),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          );
    final bentuk = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return SizedBox(
      height: 50,
      child: isi
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hijau,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.hijau.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: bentuk,
              ),
              child: balita,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.hijau,
                side: const BorderSide(color: AppColors.hijau, width: 1.4),
                shape: bentuk,
              ),
              child: balita,
            ),
    );
  }

  Widget _footer() {
    final siap = _data != null && !_loading;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: _tombol(
                label: 'Bagikan',
                ikon: Icons.share_outlined,
                proses: _membagikan,
                isi: false,
                onTap: siap && !_membagikan ? _bagikan : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tombol(
                label: 'Unduh PDF',
                ikon: Icons.download_rounded,
                proses: _mengunduh,
                onTap: siap && !_mengunduh ? _unduh : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _isi() {
    final d = _data;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42, color: _redup),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: _teks)),
            const SizedBox(height: 14),
            SizedBox(
              width: 160,
              child: _tombol(label: 'Coba Lagi', ikon: Icons.refresh, proses: false, onTap: _muat),
            ),
          ],
        ),
      );
    }
    if (d == null) return const SizedBox.shrink();
    return Column(
      children: [
        _kartuKegiatan(d),
        _kartuSkdn(d),
        _kartuGizi(d),
        _kartuImunisasi(d),
        _kartuSuplemen(d),
        _kartuBerisiko(d),
        _kartuKpsp(),
      ],
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
            headerRekap(context, 'Laporan Bulanan'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  children: [
                    PemilihBulan(bulan: _bulan, onUbah: _ubahBulan),
                    const SizedBox(height: 14),
                    _isi(),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }
}