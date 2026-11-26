import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pages/rekap/rekap_posyandu_page.dart';
import '../../../core/pages/rujukan/rujukan_detail_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../service/balita_service.dart';
import '../../../service/rujukan_service.dart';
import 'tambah_rujukan_page.dart';
import 'detail_rujukan_page.dart';

// ============================================================================
// SURAT RUJUKAN - BIDAN
// Tab Aktif (dirujuk) / Selesai (selesai & dibatalkan), saran "Perlu Dirujuk",
// dan tombol Buat Rujukan.
// ============================================================================

class BidanRujukanPage extends StatefulWidget {
  const BidanRujukanPage({super.key});

  @override
  State<BidanRujukanPage> createState() => _BidanRujukanPageState();
}

class _BidanRujukanPageState extends State<BidanRujukanPage> {
  final _svc = const RujukanService();
  int _tab = 0; // 0 aktif, 1 selesai
  List<RujukanRingkas>? _data;
  List<BalitaBerisiko> _perlu = [];
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
      final d = await _svc.daftarBidan(_tab == 0 ? 'aktif' : 'selesai');
      var perlu = <BalitaBerisiko>[];
      if (_tab == 0) {
        try {
          final b = await const BalitaService('/bidan').berisiko();
          // balita yang sudah punya rujukan aktif tidak disarankan lagi
          final sudah = d.map((e) => e.balitaId).toSet();
          perlu = b.balita.where((a) => a.tinggi && !sudah.contains(a.balita.balitaId)).toList();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _data = d;
        _perlu = perlu;
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

  void _gantiTab(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _data = null;
    });
    _muat();
  }

  Future<void> _buat([String? balitaId]) async {
    final hasil = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TambahRujukanPage(balitaIdAwal: balitaId)),
    );
    if (hasil == true) _muat();
  }

  Future<void> _buka(RujukanRingkas r) async {
    final ubah = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailRujukanBidanPage(id: r.id)),
    );
    if (ubah == true) _muat();
  }

  Widget _kartuTab(int i, String label) {
    final aktif = _tab == i;
    return Expanded(
      child: Material(
        color: aktif ? AppColors.hijau : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _gantiTab(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: aktif ? AppColors.hijau : garisKartuRekap, width: 1.2),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: aktif ? Colors.white : Colors.black87)),
          ),
        ),
      ),
    );
  }

  Widget _kartuPerlu() {
    if (_tab != 0 || _perlu.isEmpty) return const SizedBox.shrink();
    return KartuRekap(
      title: 'Perlu Dirujuk',
      trailing: teksKananRekap('${_perlu.length} balita'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Balita dengan risiko tinggi dari penimbangan terakhir.',
              style: TextStyle(fontSize: 13.5, color: redupRujukan)),
          const SizedBox(height: 8),
          for (var i = 0; i < _perlu.length; i++)
            Container(
              margin: EdgeInsets.only(bottom: i == _perlu.length - 1 ? 0 : 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: garisRujukan, width: 1.2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_perlu[i].balita.nama,
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w700, color: teksRujukan)),
                        const SizedBox(height: 2),
                        Text(_perlu[i].balita.usiaTeks,
                            style: const TextStyle(fontSize: 13.5, color: redupRujukan)),
                        const SizedBox(height: 4),
                        Text(_perlu[i].alasan.join(', '),
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.merah)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _buat(_perlu[i].balita.balitaId),
                    style: TextButton.styleFrom(foregroundColor: AppColors.hijau),
                    child: const Text('Rujuk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _isi() {
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
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 14),
            SizedBox(
              width: 170,
              child: TombolRujukan(label: 'Coba Lagi', ikon: Icons.refresh, onTap: _muat),
            ),
          ],
        ),
      );
    }
    final d = _data ?? [];
    return Column(
      children: [
        _kartuPerlu(),
        if (d.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                const Icon(Icons.description_outlined, size: 46, color: redupRujukan),
                const SizedBox(height: 10),
                Text(_tab == 0 ? 'Belum ada rujukan aktif.' : 'Belum ada rujukan selesai.',
                    style: const TextStyle(fontSize: 15, color: redupRujukan)),
              ],
            ),
          )
        else
          for (final r in d) KartuRingkasRujukan(r, onTap: () => _buka(r)),
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
            headerRekap(context, 'Surat Rujukan'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  _kartuTab(0, 'Aktif'),
                  const SizedBox(width: 10),
                  _kartuTab(1, 'Selesai'),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  children: [_isi()],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: TombolRujukan(label: 'Tambah Rujukan', ikon: Icons.add, onTap: () => _buat()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}