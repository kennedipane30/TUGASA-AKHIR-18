import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import 'pendataan_page.dart';

// ---------------------------------------------------------------------------
// HALAMAN CATAT PENGUKURAN (halaman penuh)
// Mencatat pengukuran pertama anak pada sesi posyandu ini.
// Kembali ke halaman Pendataan dengan teks peringatan validasi (boleh kosong).
// ---------------------------------------------------------------------------
class CatatPengukuranPage extends StatefulWidget {
  final AntreanKader anak;

  const CatatPengukuranPage({super.key, required this.anak});

  @override
  State<CatatPengukuranPage> createState() => _CatatPengukuranPageState();
}

class _CatatPengukuranPageState extends State<CatatPengukuranPage> {
  final _bb = TextEditingController();
  final _tb = TextEditingController();
  final _lk = TextEditingController();
  final _lila = TextEditingController();
  final _keluhan = TextEditingController();
  final _catatan = TextEditingController();

  bool _sakit = false;
  bool _asi = false;
  bool _kirim = false;
  final bool _memuat = false;
  String? _galat;

  @override
  void dispose() {
    for (final c in [_bb, _tb, _lk, _lila, _keluhan, _catatan]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _angka(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _simpan() async {
    final bb = _angka(_bb);
    final tb = _angka(_tb);

    if (bb == null || tb == null) {
      setState(
        () => _galat =
            'Berat badan dan tinggi/panjang badan wajib diisi dengan angka.',
      );
      return;
    }

    final lk = _angka(_lk);
    final lila = _angka(_lila);

    setState(() {
      _kirim = true;
      _galat = null;
    });

    try {
      final r = await ApiClient.dio.put(
        '/kader/pendaftaran/${widget.anak.pendaftaranId}/pengukuran',
        data: {
          'bb_kg': bb,
          'tb_cm': tb,
          if (lk != null) 'lingkar_kepala_cm': lk,
          if (lila != null) 'lila_cm': lila,
          'keluhan': _keluhan.text.trim(),
          'sedang_sakit': _sakit,
          'asi_eksklusif': _asi,
          'catatan': _catatan.text.trim(),
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];

      final peringatan = d is Map
          ? d['peringatan_validasi']?.toString() ?? ''
          : '';

      if (mounted) {
        Navigator.pop(context, peringatan);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _galat = pesanErrorPendataan(e);
          _kirim = false;
        });
      }
    }
  }

  Widget _kolom(
    TextEditingController c,
    String label, {
    bool angka = true,
    int baris = 1,
  }) {
    return TextField(
      controller: c,
      maxLines: baris,
      style: const TextStyle(fontSize: 17.5),
      keyboardType: angka
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16),
        filled: true,
        fillColor: AppColors.latar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      color: hijauHeaderPendataan,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: judulHeaderPendataan('Catat Pengukuran'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      bottomNavigationBar: _memuat
          ? null
          : SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE6ECE8))),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: hijauHeaderPendataan,
                            side: const BorderSide(color: hijauHeaderPendataan, width: 1.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _kirim ? null : () => Navigator.pop(context),
                          child: const Text('Batal',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hijauHeaderPendataan,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _kirim ? null : _simpan,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _kirim ? 'Menyimpan...' : 'Simpan & Teruskan ke Bidan',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _memuat
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE6ECE8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.anak.nama,
                                      style: const TextStyle(
                                          fontSize: 19, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Pill('Antrean ${widget.anak.kodeNomor}'),
                                ],
                              ),
                              Text(
                                '${widget.anak.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${widget.anak.usia}',
                                style: const TextStyle(
                                    fontSize: 16.5, color: AppColors.teksRedup),
                              ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _kolom(_bb, 'Berat badan (kg)'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _kolom(_tb, 'Tinggi/panjang (cm)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _kolom(_lk, 'Lingkar kepala (cm)'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _kolom(_lila, 'LiLA (cm)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _kolom(
                        _keluhan,
                        'Keluhan',
                        angka: false,
                      ),
                      const SizedBox(height: 10),
                      _kolom(
                        _catatan,
                        'Catatan',
                        angka: false,
                        baris: 2,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Sedang sakit',
                          style: TextStyle(fontSize: 16.5),
                        ),
                        value: _sakit,
                        onChanged: (v) {
                          setState(() => _sakit = v);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'ASI eksklusif',
                          style: TextStyle(fontSize: 16.5),
                        ),
                        value: _asi,
                        onChanged: (v) {
                          setState(() => _asi = v);
                        },
                      ),
                            ],
                          ),
                        ),
                        if (_galat != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _galat!,
                              style: const TextStyle(color: AppColors.merah, fontSize: 16),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}