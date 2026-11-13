import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../../service/balita_service.dart';
import '../rekap/rekap_posyandu_page.dart';
import 'balita_detail_page.dart';

const _abuMuda = Color(0xFFF1F5F9);

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
                    borderSide: BorderSide.none,
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
      SectionCard(
        title: 'Ringkasan Balita',
        trailing: Pill('${r.total} balita', bg: AppColors.hijauMuda, fg: AppColors.hijau),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 10),
            Text(
              'Laki-laki ${r.lakiLaki} · Perempuan ${r.perempuan} · Belum pernah ditimbang ${r.belumPernah}',
              style: const TextStyle(fontSize: 15.5, color: AppColors.teksRedup),
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
        const SectionCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Tidak ada balita yang sesuai', style: TextStyle(color: AppColors.teksRedup)),
            ),
          ),
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

  /// Label status dengan ukuran dan jarak yang seragam.
  Widget _label(String teks, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(teks,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: fg)),
      );

  Widget _kartu(BalitaItem b) {
    final t = b.terakhir;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _buka(b),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        t == null
                            ? 'Belum pernah ditimbang'
                            : 'Terakhir ${t.tanggal == null ? '-' : formatTanggal(t.tanggal!)}',
                        style: const TextStyle(fontSize: 15.5),
                      ),
                      if (t != null)
                        Text('BB ${t.bbKg} kg · TB ${t.tbCm} cm',
                            style: const TextStyle(fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Text('${b.jkTeks} · ${b.usiaTeks}',
                          style: const TextStyle(fontSize: 15.5, color: AppColors.teksRedup)),
                      const SizedBox(height: 8),
                      // Label dibagi rata selebar kartu: pertama menempel kiri,
                      // terakhir menempel kanan, di antaranya di tengah.
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (t != null && t.statusTimbang.isNotEmpty)
                            _label(
                              labelTimbang(t.statusTimbang),
                              t.statusTimbang == 'N'
                                  ? AppColors.hijauMuda
                                  : (t.statusTimbang == 'T' ? AppColors.merahMuda : AppColors.biruMuda),
                              t.statusTimbang == 'N'
                                  ? AppColors.hijau
                                  : (t.statusTimbang == 'T' ? AppColors.merah : AppColors.biru),
                            ),
                          if (t?.duaT == true) _label('2T', AppColors.merahMuda, AppColors.merah),
                          if (t?.bgm == true) _label('BGM', AppColors.merahMuda, AppColors.merah),
                          if (t != null && t.masalah.isEmpty && t.tingkat.isNotEmpty)
                            _label('Gizi normal', AppColors.hijauMuda, AppColors.hijau),
                          for (final m in t?.masalah ?? const <String>[])
                            _label(m, AppColors.kuningMuda, AppColors.kuning),
                          _label(
                            'Vaksin ${b.vaksin.persen}%',
                            b.vaksin.terlambat > 0 ? AppColors.kuningMuda : _abuMuda,
                            b.vaksin.terlambat > 0 ? AppColors.kuning : Colors.black87,
                          ),
                          if (b.bulanTidakDatang >= 2)
                            _label('${b.bulanTidakDatang} bln tidak datang', AppColors.merahMuda, AppColors.merah),
                        ],
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}