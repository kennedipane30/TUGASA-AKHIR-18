import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../service/vaksin_service.dart';
import '../../Bidan/vaksin/vaksin_lihat_body.dart';

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

/// Orang tua: lihat jadwal imunisasi, riwayat vaksin, dan suplemen anak sendiri,
/// serta melaporkan reaksi setelah imunisasi (diteruskan ke bidan).
class OrangTuaVaksinPage extends StatefulWidget {
  const OrangTuaVaksinPage({super.key});

  @override
  State<OrangTuaVaksinPage> createState() => _OrangTuaVaksinPageState();
}

class _OrangTuaVaksinPageState extends State<OrangTuaVaksinPage> {
  final _svc = VaksinService();

  List<AnakRingkas> _anak = [];
  AnakRingkas? _dipilih;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.anakSaya();
      if (!mounted) return;
      setState(() {
        _anak = data;
        _dipilih = data.isNotEmpty ? data.first : null;
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

  // Header bagian atas: judul di tengah
  Widget _header() {
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
                child: _judulTebal('Vaksin Anak'),
              ),
              // Tombol kembali di kiri
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back,
                          color: Colors.white, size: 22),
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

  Widget _isi() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              AppButton('Coba Lagi', icon: Icons.refresh, onPressed: _muat),
            ],
          ),
        ),
      );
    }
    if (_anak.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada data anak. Tambahkan data anak terlebih dahulu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.teksRedup)),
        ),
      );
    }
    return Column(
      children: [
        if (_anak.length > 1)
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final a in _anak)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(a.nama),
                        selected: _dipilih?.id == a.id,
                        selectedColor: AppColors.hijau,
                        backgroundColor: AppColors.latar,
                        labelStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _dipilih?.id == a.id
                                ? Colors.white
                                : Colors.black87),
                        onSelected: (_) => setState(() => _dipilih = a),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SectionCard(
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.hijauMuda,
                  child: Icon(Icons.child_care, color: AppColors.hijau),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_dipilih!.nama,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      Text('Usia ${_dipilih!.usia}',
                          style: const TextStyle(
                              fontSize: 15.5, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: VaksinLihatBody(
            key: ValueKey(_dipilih!.id),
            anakId: _dipilih!.id,
            bisaLaporKipi: true,
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
            _header(),
            Expanded(child: _isi()),
          ],
        ),
      ),
    );
  }
}