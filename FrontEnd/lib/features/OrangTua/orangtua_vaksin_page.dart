import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../service/vaksin_service.dart';
import '../Bidan/vaksin_lihat_body.dart';

/// Orang tua: lihat rencana dan riwayat vaksin anak sendiri.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Vaksin Anak', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                )
              : _anak.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Belum ada data anak. Tambahkan data anak terlebih dahulu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.teksRedup)),
                      ),
                    )
                  : Column(
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
                                            fontWeight: FontWeight.w700,
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
                                              fontWeight: FontWeight.w800, fontSize: 14)),
                                      Text('Usia ${_dipilih!.usia}',
                                          style: const TextStyle(
                                              fontSize: 11.5, color: AppColors.teksRedup)),
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
                          ),
                        ),
                      ],
                    ),
    );
  }
}