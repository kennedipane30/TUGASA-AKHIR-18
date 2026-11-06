import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'common_widgets.dart';
import '../service/balita_service.dart';
import '../features/Sekretaris/rekap/admin_rekap_page.dart';
import 'balita_detail_page.dart';

const _abuMuda = Color(0xFFF1F5F9);

/// Semua balita di posyandu petugas (sekretaris, kader, bidan).
/// [prefix] '/sekretaris', '/kader', atau '/bidan'.
/// [bisaKelolaVaksin] true untuk bidan (dapat mencatat vaksin dari luar posyandu).
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
                  prefixIcon: const Icon(Icons.search),
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
                            const Icon(Icons.cloud_off, size: 40, color: AppColors.teksRedup),
                            const SizedBox(height: 10),
                            Text(_error!, textAlign: TextAlign.center),
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

  List<Widget> _isi(DaftarBalita d) {
    final r = d.ringkas;
    final daftar = _saring(d.balita);
    return [
      SectionCard(
        title: 'Ringkasan Balita',
        icon: Icons.child_care,
        trailing: Pill('${r.total} balita', bg: AppColors.hijauMuda, fg: AppColors.hijau),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: StatBox(nilai: '${r.usia0_11}', label: '0-11 bln')),
                const SizedBox(width: 8),
                Expanded(child: StatBox(nilai: '${r.usia12_23}', label: '12-23 bln')),
                const SizedBox(width: 8),
                Expanded(child: StatBox(nilai: '${r.usia24_59}', label: '24-59 bln')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatBox(
                      nilai: '${r.stunting}', label: 'Stunting', bg: AppColors.merahMuda, fg: AppColors.merah),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${r.duaTBgm}', label: '2T / BGM', bg: AppColors.merahMuda, fg: AppColors.merah),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatBox(
                      nilai: '${r.vaksinTerlambat}',
                      label: 'Vaksin\nterlambat',
                      bg: AppColors.kuningMuda,
                      fg: AppColors.kuning),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Laki-laki ${r.lakiLaki} · Perempuan ${r.perempuan} · Belum pernah ditimbang ${r.belumPernah}',
              style: const TextStyle(fontSize: 13, color: AppColors.teksRedup),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

  Widget _kartu(BalitaItem b) {
    final t = b.terakhir;
    final perempuan = b.jenisKelamin == 'P';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _buka(b),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: perempuan ? const Color(0xFFFCE7F3) : AppColors.biruMuda,
                  child: Icon(Icons.child_care, color: perempuan ? const Color(0xFFBE185D) : AppColors.biru),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('${b.jkTeks} · ${b.usiaTeks}',
                          style: const TextStyle(fontSize: 13, color: AppColors.teksRedup)),
                      const SizedBox(height: 6),
                      Text(
                        t == null
                            ? 'Belum pernah ditimbang'
                            : 'Terakhir ${t.tanggal == null ? '-' : formatTanggal(t.tanggal!)} · '
                                'BB ${t.bbKg} kg · TB ${t.tbCm} cm',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (t != null && t.statusTimbang.isNotEmpty)
                            Pill(
                              t.statusTimbang,
                              bg: t.statusTimbang == 'N'
                                  ? AppColors.hijauMuda
                                  : (t.statusTimbang == 'T' ? AppColors.merahMuda : AppColors.biruMuda),
                              fg: t.statusTimbang == 'N'
                                  ? AppColors.hijau
                                  : (t.statusTimbang == 'T' ? AppColors.merah : AppColors.biru),
                            ),
                          if (t?.duaT == true) const Pill('2T', bg: AppColors.merahMuda, fg: AppColors.merah),
                          if (t?.bgm == true) const Pill('BGM', bg: AppColors.merahMuda, fg: AppColors.merah),
                          if (t != null && t.masalah.isEmpty && t.tingkat.isNotEmpty)
                            const Pill('Gizi normal', bg: AppColors.hijauMuda, fg: AppColors.hijau),
                          for (final m in t?.masalah ?? const <String>[])
                            Pill(m, bg: AppColors.kuningMuda, fg: AppColors.kuning),
                          Pill(
                            'Vaksin ${b.vaksin.persen}%',
                            bg: b.vaksin.terlambat > 0 ? AppColors.kuningMuda : _abuMuda,
                            fg: b.vaksin.terlambat > 0 ? AppColors.kuning : Colors.black87,
                          ),
                          if (b.bulanTidakDatang >= 2)
                            Pill('${b.bulanTidakDatang} bln tidak datang',
                                bg: AppColors.merahMuda, fg: AppColors.merah),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.teksRedup),
              ],
            ),
          ),
        ),
      ),
    );
  }
}