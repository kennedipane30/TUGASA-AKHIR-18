import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pages/rekap/rekap_posyandu_page.dart';
import '../../../core/pages/rujukan/rujukan_detail_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../service/rujukan_service.dart';
import 'detail_rujukan_page.dart';

// ============================================================================
// TAMBAH RUJUKAN - BIDAN
// Cari & pilih anak -> data anak otomatis -> isi keluhan, diagnosis,
// tindakan, tujuan -> simpan (surat bernomor + notifikasi ke orang tua).
// ============================================================================

class TambahRujukanPage extends StatefulWidget {
  /// Anak yang langsung dipilih (dari daftar "Perlu Dirujuk"); null = cari dulu.
  final String? anakIdAwal;

  const TambahRujukanPage({super.key, this.anakIdAwal});

  @override
  State<TambahRujukanPage> createState() => _TambahRujukanPageState();
}

class _TambahRujukanPageState extends State<TambahRujukanPage> {
  final _svc = const RujukanService();

  // pencarian
  final _cari = TextEditingController();
  Timer? _tunda;
  List<AnakCariRujukan> _hasilCari = [];
  bool _mencari = false;
  String? _gagalCari;

  // anak terpilih
  DataAnakRujukan? _anak;
  bool _memuatAnak = false;
  String? _gagalAnak;

  // form
  final _formKey = GlobalKey<FormState>();
  final _keluhan = TextEditingController();
  final _diagnosis = TextEditingController();
  final _tindakan = TextEditingController();
  final _tujuan = TextEditingController();
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    final id = widget.anakIdAwal;
    if (id != null && id.isNotEmpty) {
      _pilih(id);
    } else {
      _jalankanCari('');
    }
  }

  @override
  void dispose() {
    _tunda?.cancel();
    _cari.dispose();
    _keluhan.dispose();
    _diagnosis.dispose();
    _tindakan.dispose();
    _tujuan.dispose();
    super.dispose();
  }

  void _snack(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  void _ketikCari(String v) {
    _tunda?.cancel();
    _tunda = Timer(const Duration(milliseconds: 400), () => _jalankanCari(v));
  }

  Future<void> _jalankanCari(String kata) async {
    setState(() {
      _mencari = true;
      _gagalCari = null;
    });
    try {
      final h = await _svc.cariAnak(kata.trim());
      if (!mounted) return;
      setState(() {
        _hasilCari = h;
        _mencari = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagalCari = e.toString().replaceFirst('Exception: ', '');
        _mencari = false;
      });
    }
  }

  Future<void> _pilih(String anakId) async {
    setState(() {
      _memuatAnak = true;
      _gagalAnak = null;
    });
    try {
      final d = await _svc.dataAnak(anakId);
      if (!mounted) return;
      setState(() {
        _anak = d;
        _memuatAnak = false;
        if (_keluhan.text.trim().isEmpty && d.keluhanTerakhir.isNotEmpty) {
          _keluhan.text = d.keluhanTerakhir;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagalAnak = e.toString().replaceFirst('Exception: ', '');
        _memuatAnak = false;
      });
    }
  }

  void _gantiAnak() {
    setState(() {
      _anak = null;
      _keluhan.clear();
    });
    if (_hasilCari.isEmpty) _jalankanCari(_cari.text);
  }

  Future<void> _simpan() async {
    final a = _anak;
    if (a == null || _menyimpan) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Surat Rujukan?'),
        content: Text('${a.nama} akan dirujuk ke ${_tujuan.text.trim()}. '
            'Orang tua akan menerima notifikasi dan dapat mengunduh surat rujukan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Periksa Lagi')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Buat', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _menyimpan = true);
    try {
      final r = await _svc.buat(
        anakId: a.anakId,
        keluhan: _keluhan.text.trim(),
        diagnosis: _diagnosis.text.trim(),
        tindakan: _tindakan.text.trim(),
        tujuan: _tujuan.text.trim(),
      );
      if (!mounted) return;
      _snack('Surat rujukan ${r.nomor} berhasil dibuat');
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DetailRujukanBidanPage(id: r.id)),
        result: true,
      );
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Widget _pencarian() {
    return KartuRekap(
      title: 'Pilih Anak',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _cari,
            onChanged: _ketikCari,
            textInputAction: TextInputAction.search,
            onSubmitted: _jalankanCari,
            style: const TextStyle(fontSize: 15),
            decoration: dekorRujukan('Ketik nama anak atau NIK').copyWith(prefixIcon: const Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          if (_mencari || _memuatAnak)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_gagalCari != null || _gagalAnak != null)
            Text(_gagalCari ?? _gagalAnak!, style: const TextStyle(color: AppColors.merah))
          else if (_hasilCari.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Anak tidak ditemukan.', style: TextStyle(color: redupRujukan, fontSize: 14.5)),
            )
          else
            for (var i = 0; i < _hasilCari.length; i++)
              InkWell(
                onTap: () => _pilih(_hasilCari[i].anakId),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: i == _hasilCari.length - 1
                        ? null
                        : const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.hijauMuda,
                        child: Icon(
                            _hasilCari[i].jenisKelamin.toUpperCase().startsWith('P') ? Icons.girl : Icons.boy,
                            color: AppColors.hijau),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_hasilCari[i].nama,
                                style: const TextStyle(
                                    fontSize: 15.5, fontWeight: FontWeight.w700, color: teksRujukan)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                _hasilCari[i].usiaTeks,
                                if (_hasilCari[i].namaOrangTua.isNotEmpty) 'Ortu: ${_hasilCari[i].namaOrangTua}',
                              ].join('  |  '),
                              style: const TextStyle(fontSize: 13.5, color: redupRujukan),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: redupRujukan),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _form(DataAnakRujukan a) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (widget.anakIdAwal == null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _gantiAnak,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Ganti anak'),
                style: TextButton.styleFrom(foregroundColor: AppColors.hijau),
              ),
            ),
          ...kartuDataAnakRujukan(a),
          FormIsianRujukan(keluhan: _keluhan, diagnosis: _diagnosis, tindakan: _tindakan, tujuan: _tujuan),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _anak;
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
            headerRekap(context, 'Tambah Rujukan'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [if (a == null) _pencarian() else _form(a)],
              ),
            ),
            if (a != null) footerSimpanRujukan(context: context, menyimpan: _menyimpan, onSimpan: _simpan),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FORM ISIAN RUJUKAN (dipakai halaman Tambah & Edit rujukan)
// Keluhan, Diagnosis, Tindakan yang sudah dilakukan, Tujuan.
// ============================================================================

InputDecoration dekorRujukan(String hint) => InputDecoration(
      hintText: hint,
      counterText: '',
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.5),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: garisRujukan, width: 1.2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: garisRujukan, width: 1.2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.hijau, width: 1.6)),
    );

class FormIsianRujukan extends StatelessWidget {
  final TextEditingController keluhan;
  final TextEditingController diagnosis;
  final TextEditingController tindakan;
  final TextEditingController tujuan;

  const FormIsianRujukan({
    super.key,
    required this.keluhan,
    required this.diagnosis,
    required this.tindakan,
    required this.tujuan,
  });

  Widget _isian(TextEditingController c, String label, String hint,
      {bool wajib = false, int baris = 3, int maks = 1000}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: teksRujukan)),
              if (wajib) const TextSpan(text: ' *', style: TextStyle(color: AppColors.merah, fontSize: 15)),
            ])),
          ),
          TextFormField(
            controller: c,
            minLines: baris,
            maxLines: baris + 3,
            maxLength: maks,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15),
            decoration: dekorRujukan(hint),
            validator: (v) => wajib && (v ?? '').trim().isEmpty ? '$label wajib diisi' : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KartuRekap(
      title: 'Isian Rujukan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isian(keluhan, 'Keluhan', 'Contoh: BB tidak naik sejak 2 bulan terakhir, nafsu makan turun',
              wajib: true),
          _isian(diagnosis, 'Diagnosis', 'Contoh: Gizi kurang, 2T', wajib: true, baris: 2, maks: 500),
          _isian(tindakan, 'Tindakan yang sudah dilakukan', 'Contoh: Konseling gizi, pemberian PMT'),
          _isian(tujuan, 'Tujuan', 'Contoh: Puskesmas Laguboti - Poli Anak', wajib: true, baris: 1, maks: 200),
        ],
      ),
    );
  }
}

/// Footer Batal (merah) + Simpan (hijau).
Widget footerSimpanRujukan({
  required BuildContext context,
  required bool menyimpan,
  required VoidCallback onSimpan,
}) =>
    SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: TombolRujukan(
                label: 'Batal',
                ikon: Icons.close,
                isi: false,
                warna: AppColors.merah,
                onTap: menyimpan ? null : () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TombolRujukan(label: 'Simpan', ikon: Icons.check, proses: menyimpan, onTap: onSimpan),
            ),
          ],
        ),
      ),
    );