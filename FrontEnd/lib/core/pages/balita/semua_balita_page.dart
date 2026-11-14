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
  ];

  late final BalitaService _svc = BalitaService(widget.prefix);
  final _cari = TextEditingController();
  Timer? _tunda;

  DaftarBalita? _data;
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
      final d = await _svc.daftar(cari: _cari.text.trim());
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
    final daftar = _saring(d.balita);
    return [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _garisKartu, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan Balita',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _teksGelap)),
            const SizedBox(height: 12),
            Row(
              children: [
                _kotak('0-11 bln', '${r.usia0_11}',
                    const Color(0xFFE3F2FD), const Color(0xFFBFDFF7), const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                _kotak('12-23 bln', '${r.usia12_23}',
                    const Color(0xFFE6F8EF), const Color(0xFFBDEBD3), const Color(0xFF059669)),
                const SizedBox(width: 8),
                _kotak('24-59 bln', '${r.usia24_59}',
                    const Color(0xFFF3F4F6), const Color(0xFFE5E7EB), const Color(0xFF374151)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _kotak('Stunting', '${r.stunting}',
                    const Color(0xFFFDEAF1), const Color(0xFFF6C9D9), const Color(0xFFE11D48)),
                const SizedBox(width: 8),
                _kotak('2T / BGM', '${r.duaTBgm}',
                    const Color(0xFFFDEAF1), const Color(0xFFF6C9D9), const Color(0xFFE11D48)),
                const SizedBox(width: 8),
                _kotak('Vaksin\nterlambat', '${r.vaksinTerlambat}',
                    const Color(0xFFFFF4DC), const Color(0xFFF9E0A8), const Color(0xFFD97706)),
              ],
            ),
            const SizedBox(height: 12),
            _baris('Laki-laki', '${r.lakiLaki}'),
            const SizedBox(height: 6),
            _baris('Perempuan', '${r.perempuan}'),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _garisKartu, width: 1.2),
          ),
          child: const Text('Tidak ada balita yang sesuai',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
        ),
      for (final b in daftar) _kartu(b),
    ];
  }

  /// Kotak angka kecil: angka di atas, keterangan di bawah, rata tengah.
  Widget _kotak(String label, String nilai, Color bg, Color garis, Color fg) {
    return Expanded(
      child: Container(
        height: 80,
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg, height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _kartu(BalitaItem b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _buka(b),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _garisKartu, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _baris('Nama', b.nama),
                const SizedBox(height: 6),
                _baris('Usia', b.usiaTeks),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lihat detail',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: _hijauTua)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16, color: _hijauTua),
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

  /// Baris "Label : nilai" (satu warna hitam).
  Widget _baris(String label, String nilai) {
    const gaya = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: _teksGelap);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, child: Text(label, style: gaya)),
        const Text(': ', style: gaya),
        Expanded(child: Text(nilai.isEmpty ? '-' : nilai, style: gaya)),
      ],
    );
  }
}