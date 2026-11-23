import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pages/rekap/rekap_posyandu_page.dart';
import '../../../core/pages/rujukan/rujukan_detail_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../service/rujukan_service.dart';
import 'tambah_rujukan_page.dart';

// ============================================================================
// EDIT RUJUKAN - BIDAN
// Memperbaiki keluhan, diagnosis, tindakan, dan tujuan selama rujukan masih
// aktif. Anak, nomor, dan tanggal surat tetap. Hasil dikembalikan lewat
// Navigator.pop(context, RujukanDetail).
// ============================================================================

class EditRujukanPage extends StatefulWidget {
  final RujukanDetail rujukan;

  const EditRujukanPage({super.key, required this.rujukan});

  @override
  State<EditRujukanPage> createState() => _EditRujukanPageState();
}

class _EditRujukanPageState extends State<EditRujukanPage> {
  final _svc = const RujukanService();
  final _formKey = GlobalKey<FormState>();
  late final _keluhan = TextEditingController(text: widget.rujukan.keluhan);
  late final _diagnosis = TextEditingController(text: widget.rujukan.diagnosis);
  late final _tindakan = TextEditingController(text: widget.rujukan.tindakan);
  late final _tujuan = TextEditingController(text: widget.rujukan.tujuan);
  bool _menyimpan = false;

  @override
  void dispose() {
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

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _menyimpan = true);
    try {
      final r = await _svc.ubah(
        widget.rujukan.id,
        keluhan: _keluhan.text.trim(),
        diagnosis: _diagnosis.text.trim(),
        tindakan: _tindakan.text.trim(),
        tujuan: _tujuan.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, r);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rujukan;
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
            headerRekap(context, 'Edit Rujukan'),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    KartuRekap(
                      title: 'Surat Rujukan',
                      trailing: ChipStatusRujukan(r.status),
                      child: Column(
                        children: daftarBarisRujukan([
                          ('Nomor', r.nomor),
                          ('Tanggal', tglRujukan(r.tanggal)),
                          ('Anak', r.dataAnak.nama),
                        ]),
                      ),
                    ),
                    FormIsianRujukan(
                        keluhan: _keluhan, diagnosis: _diagnosis, tindakan: _tindakan, tujuan: _tujuan),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Setelah disimpan, orang tua mendapat pemberitahuan untuk mengunduh ulang surat rujukan.',
                        style: TextStyle(fontSize: 13.5, color: redupRujukan),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            footerSimpanRujukan(context: context, menyimpan: _menyimpan, onSimpan: _simpan),
          ],
        ),
      ),
    );
  }
}