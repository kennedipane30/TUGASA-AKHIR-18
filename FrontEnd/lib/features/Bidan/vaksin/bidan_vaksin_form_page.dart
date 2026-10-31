import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../service/vaksin_service.dart';
import 'vaksin_model.dart';

const _hijauHeader = Color(0xFF065F46);

/// Judul header ekstra tebal (sama seperti halaman Akun).
/// Lapis bawah: garis tepi putih agar huruf lebih gemuk; lapis atas: isi putih.
Widget _judulTebal(String teks) {
  const ukuran = 20.0;
  const jarak = 1.2; // jarak antar huruf

  return Stack(
    children: [
      // Lapis bawah: garis tepi untuk menebalkan huruf
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        ),
      ),
      // Lapis atas: isi huruf
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Color(0x40000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Form jadwalkan vaksin baru (rencana == null) atau ubah jadwal (rencana != null).
class BidanVaksinFormPage extends StatefulWidget {
  final String anakId;
  final String namaAnak;
  final VaksinRencana? rencana;

  const BidanVaksinFormPage({
    super.key,
    required this.anakId,
    required this.namaAnak,
    this.rencana,
  });

  @override
  State<BidanVaksinFormPage> createState() => _BidanVaksinFormPageState();
}

class _BidanVaksinFormPageState extends State<BidanVaksinFormPage> {
  final _svc = VaksinService();
  final _alasan = TextEditingController();

  List<VaksinMaster> _master = [];
  VaksinMaster? _dipilih;
  DateTime _tanggal = DateTime.now();
  bool _loading = true;
  bool _menyimpan = false;
  String? _error;

  bool get _edit => widget.rencana != null;

  @override
  void initState() {
    super.initState();

    if (_edit) {
      final r = widget.rencana!;
      _tanggal = DateTime.tryParse(r.perkiraanTanggal) ?? DateTime.now();

      if (_tanggal.isBefore(_hariIni())) {
        _tanggal = _hariIni();
      }

      _alasan.text = r.alasan;
      _loading = false;
    } else {
      _muatMaster();
    }
  }

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  DateTime _hariIni() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _muatMaster() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _svc.listMaster();
      if (!mounted) return;

      setState(() {
        _master = data;
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

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal.isBefore(_hariIni()) ? _hariIni() : _tanggal,
      firstDate: _hariIni(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (hasil != null) {
      setState(() => _tanggal = hasil);
    }
  }

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _simpan() async {
    if (!_edit && _dipilih == null) {
      _pesan('Pilih jenis vaksin terlebih dahulu');
      return;
    }

    final alasan = _alasan.text.trim();
    if (alasan.isEmpty) {
      _pesan('Dasar hasil pemeriksaan wajib diisi');
      return;
    }

    setState(() => _menyimpan = true);

    try {
      if (_edit) {
        await _svc.ubahRencana(
          id: widget.rencana!.id,
          tanggal: _tanggal,
          alasan: alasan,
        );
      } else {
        await _svc.buatRencana(
          anakId: widget.anakId,
          jadwalImunisasiId: _dipilih!.id,
          tanggal: _tanggal,
          alasan: alasan,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _menyimpan = false);
      _pesan(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  InputDecoration _dekor(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.isiField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
  // -------------------------------------------------------------------------
  Widget _header(String judul) {
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
                child: _judulTebal(judul),
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
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
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
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            _header(_edit ? 'Ubah Jadwal Vaksin' : 'Jadwalkan Vaksin'),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                AppButton(
                                  'Coba Lagi',
                                  icon: Icons.refresh,
                                  onPressed: _muatMaster,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            SectionCard(
                              title: widget.namaAnak,
                              icon: Icons.child_care,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Jenis Vaksin',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (_edit)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.isiField,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${widget.rencana!.vaksin.nama} · Dosis ${widget.rencana!.dosisKe}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  else
                                    DropdownButtonFormField<VaksinMaster>(
                                      value: _dipilih,
                                      isExpanded: true,
                                      decoration: _dekor('Pilih vaksin dan dosis'),
                                      items: [
                                        for (final m in _master)
                                          DropdownMenuItem(
                                            value: m,
                                            child: Text(
                                              m.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        setState(() => _dipilih = v);
                                      },
                                    ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Tanggal Vaksin',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: _pilihTanggal,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.isiField,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.event,
                                            size: 20,
                                            color: AppColors.hijau,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            formatTanggalTampil(
                                              formatTanggalApi(_tanggal),
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Dasar Hasil Pemeriksaan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _alasan,
                                    maxLines: 4,
                                    decoration: _dekor(
                                      'Contoh: kondisi anak sehat, BB naik, tidak demam sehingga layak divaksin',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                _menyimpan
                                    ? 'Menyimpan...'
                                    : (_edit
                                        ? 'Simpan Perubahan'
                                        : 'Simpan Jadwal'),
                                icon: Icons.save_outlined,
                                onPressed: _menyimpan ? () {} : _simpan,
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