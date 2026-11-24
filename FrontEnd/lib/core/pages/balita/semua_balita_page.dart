import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../../service/balita_service.dart';
import '../rekap/rekap_posyandu_page.dart';
import 'balita_detail_page.dart';

const _hijauTua = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi kartu, kolom cari & filter: hitam lembut (tidak mencolok).
const _garisKartu = Color(0xFFB8BEC6);
const _garisCari = _garisKartu;

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = [
  BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 3)),
];

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

BoxDecoration _dekorKartu() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Kepala kartu: judul tebal kapital di kiri, keterangan di kanan, garis aksen di bawah.
Widget _kepala(String judul, {String? kanan}) {
  return Column(
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
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(kanan,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Tautan kecil hijau lembut bergaris bawah.
Widget _tautan(String teks) => Text(
      teks,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: _aksen,
        decoration: TextDecoration.underline,
        decorationColor: _aksen,
      ),
    );

/// Teks status penimbangan (tanpa kode huruf).
String labelTimbang(String s) => const {
      'N': 'Naik',
      'T': 'Tidak naik',
      'O': 'Bulan lalu tidak ditimbang',
      'B': 'Baru',
    }[s] ??
    s;

class SemuaBalitaPage extends StatefulWidget {
  final String prefix;
  final bool bisaKelolaVaksin;

  const SemuaBalitaPage({super.key, required this.prefix, this.bisaKelolaVaksin = false});

  @override
  State<SemuaBalitaPage> createState() => _SemuaBalitaPageState();
}

class _SemuaBalitaPageState extends State<SemuaBalitaPage> {
  static const _filter = [
    'Semua',
    '0-11 bln',
    '12-23 bln',
    '24-59 bln',
    'Masalah gizi',
    '2T / BGM',
    'Vaksin terlambat',
    'Belum ditimbang',
    'Diarsipkan', // pindah, meninggal, lulus balita (riwayat tetap dapat dilihat)
  ];

  late final BalitaService _svc = BalitaService(widget.prefix);
  final _cari = TextEditingController();
  Timer? _tunda;

  DaftarBalita? _data;
  DaftarBalita? _arsip; // anak yang sudah diarsipkan
  bool _loading = true;
  String? _error;
  String _aktif = 'Semua';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _tunda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final cari = _cari.text.trim();
      final hasil = await Future.wait([
        _svc.daftar(cari: cari),
        _svc.daftarArsip(cari: cari),
      ]);
      if (!mounted) return;
      setState(() {
        _data = hasil[0];
        _arsip = hasil[1];
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

  void _ketik(String _) {
    _tunda?.cancel();
    _tunda = Timer(const Duration(milliseconds: 400), _muat);
  }

  List<BalitaItem> _saring(List<BalitaItem> list) {
    switch (_aktif) {
      case '0-11 bln':
        return list.where((b) => b.kelompokUsia == '0-11').toList();
      case '12-23 bln':
        return list.where((b) => b.kelompokUsia == '12-23').toList();
      case '24-59 bln':
        return list.where((b) => b.kelompokUsia == '24-59').toList();
      case 'Masalah gizi':
        return list.where((b) => b.masalahGizi).toList();
      case '2T / BGM':
        return list.where((b) => b.perluPerhatian).toList();
      case 'Vaksin terlambat':
        return list.where((b) => b.vaksin.terlambat > 0).toList();
      case 'Belum ditimbang':
        return list.where((b) => b.terakhir == null).toList();
    }
    return list;
  }

  Future<void> _buka(BalitaItem b) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BalitaDetailPage(
          prefix: widget.prefix,
          anakId: b.anakId,
          nama: b.nama,
          bisaKelolaVaksin: widget.bisaKelolaVaksin,
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
            headerRekap(context, 'Semua Balita'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _cari,
                onChanged: _ketik,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _muat(),
                decoration: InputDecoration(
                  hintText: 'Cari nama balita',
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  suffixIcon: _cari.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _cari.clear();
                            _muat();
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _garisCari, width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _garisCari, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.black54, width: 1.4),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            AppButton('Coba Lagi', onPressed: _muat),
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

  List<Widget> _isi(DaftarBalita d) {
    final r = d.ringkas;
    final lihatArsip = _aktif == 'Diarsipkan';
    final daftar = lihatArsip ? (_arsip?.balita ?? const <BalitaItem>[]) : _saring(d.balita);
    return [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: _dekorKartu(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kepala('Ringkasan Balita'),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Diurutkan dari yang paling perlu diperhatikan.
            _barisJumlah('2T / BGM', r.duaTBgm, AppColors.merah),
            _pemisah,
            _barisJumlah('Stunting', r.stunting, AppColors.merah),
            _pemisah,
            _barisJumlah('Vaksin terlambat', r.vaksinTerlambat, AppColors.kuning),
            _pemisah,
            _barisJumlah('Usia 0-11 bulan', r.usia0_11, _teksGelap),
            _pemisah,
            _barisJumlah('Usia 12-23 bulan', r.usia12_23, _teksGelap),
            _pemisah,
            _barisJumlah('Usia 24-59 bulan', r.usia24_59, _teksGelap),
            _pemisah,
            _barisJumlah('Laki-laki', r.lakiLaki, _teksGelap),
            _pemisah,
            _barisJumlah('Perempuan', r.perempuan, _teksGelap),
                ],
              ),
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
                  label: Text(f == 'Diarsipkan' && _arsip != null
                      ? 'Diarsipkan (${_arsip!.balita.length})'
                      : f),
                  selected: _aktif == f,
                  selectedColor: _hijauTua,
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  side: BorderSide(color: _aktif == f ? _hijauTua : _garisKartu, width: 1.2),
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
      const SizedBox(height: 10),
      if (daftar.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: _dekorKartu(),
          child: Text(
              lihatArsip ? 'Belum ada balita yang diarsipkan' : 'Tidak ada balita yang sesuai',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
        ),
      for (final b in daftar) _kartu(b),
    ];
  }

  static const _pemisah = Divider(height: 1, color: Color(0xFFE5E7EB));

  static String _tglTeks(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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

  Widget _kartu(BalitaItem b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: _dekorKartu(),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _buka(b),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kepala(b.nama, kanan: b.diarsipkan ? 'Tidak aktif' : null),
                if (b.diarsipkan)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Text(
                      [
                        if (b.alasanArsip.isNotEmpty) b.alasanArsip,
                        if (b.tanggalArsip != null) _tglTeks(b.tanggalArsip!),
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.teksRedup),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Usia : ',
                                style: TextStyle(fontWeight: FontWeight.w700, color: _teksGelap),
                              ),
                              TextSpan(
                                text: b.usiaTeks.isEmpty ? '-' : b.usiaTeks,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.35),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _tautan('Lihat detail'),
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
}