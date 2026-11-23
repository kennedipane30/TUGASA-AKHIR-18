import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pages/rekap/rekap_posyandu_page.dart';
import '../../../core/pages/rujukan/rujukan_detail_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../service/rujukan_service.dart';

// ============================================================================
// RUJUKAN ANAK - ORANG TUA
// Daftar surat rujukan anak; detail, unduh, dan bagikan surat (hanya melihat).
// ============================================================================

class OrangTuaRujukanPage extends StatefulWidget {
  const OrangTuaRujukanPage({super.key});

  @override
  State<OrangTuaRujukanPage> createState() => _OrangTuaRujukanPageState();
}

class _OrangTuaRujukanPageState extends State<OrangTuaRujukanPage> {
  final _svc = const RujukanService();
  List<RujukanRingkas>? _data;
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
      final d = await _svc.daftarOrangTua();
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
    if (d.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 46, color: redupRujukan),
            SizedBox(height: 10),
            Text('Belum ada surat rujukan untuk anak Anda.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: redupRujukan)),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final r in d)
          KartuRingkasRujukan(
            r,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetailRujukanAnakPage(id: r.id)),
            ),
          ),
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
            headerRekap(context, 'Rujukan Anak'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [_isi()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Detail rujukan (orang tua)
// ----------------------------------------------------------------------------

class DetailRujukanAnakPage extends StatefulWidget {
  final String id;
  const DetailRujukanAnakPage({super.key, required this.id});

  @override
  State<DetailRujukanAnakPage> createState() => _DetailRujukanAnakPageState();
}

class _DetailRujukanAnakPageState extends State<DetailRujukanAnakPage> {
  final _svc = const RujukanService();
  RujukanDetail? _data;
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
      final d = await _svc.detailOrangTua(widget.id);
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

  void _snack(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _unduh() async {
    final d = _data;
    if (d == null) return;
    setState(() => _mengunduh = true);
    try {
      await unduhSuratRujukan(d);
    } catch (e) {
      _snack('PDF gagal dibuat: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _mengunduh = false);
    }
  }

  Future<void> _bagikan() async {
    final d = _data;
    if (d == null) return;
    setState(() => _membagikan = true);
    try {
      await bagikanSuratRujukan(context, d);
    } catch (e) {
      _snack('PDF gagal dibagikan: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _membagikan = false);
    }
  }

  Widget _petunjuk(RujukanDetail d) {
    if (!d.aktif) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.kuningMuda,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.kuning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bawa anak beserta surat rujukan ini ke ${d.tujuan}. '
              'Tunjukkan surat (dicetak atau dari HP) kepada petugas kesehatan.',
              style: const TextStyle(fontSize: 14.5, height: 1.4, color: teksRujukan),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                            const SizedBox(height: 14),
                            SizedBox(
                              width: 170,
                              child: TombolRujukan(label: 'Coba Lagi', ikon: Icons.refresh, onTap: _muat),
                            ),
                          ],
                        ),
                      )
                    else if (d != null) ...[
                      _petunjuk(d),
                      RujukanDetailView(d),
                    ],
                  ],
                ),
              ),
            ),
            if (d != null && !_loading)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TombolRujukan(
                          label: 'Bagikan',
                          ikon: Icons.share_outlined,
                          isi: false,
                          proses: _membagikan,
                          onTap: _bagikan,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TombolRujukan(
                          label: 'Unduh PDF',
                          ikon: Icons.download_rounded,
                          proses: _mengunduh,
                          onTap: _unduh,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}