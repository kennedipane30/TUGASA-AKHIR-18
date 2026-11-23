import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/pages/rekap/rekap_posyandu_page.dart';
import '../../../core/pages/rujukan/rujukan_detail_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../service/rujukan_service.dart';
import 'edit_rujukan_page.dart';

// ============================================================================
// DETAIL RUJUKAN - BIDAN
// Lihat surat, unduh/bagikan PDF, edit rujukan (selama aktif), catat atau
// ubah hasil rujukan (rujukan balik), batalkan, atau hapus rujukan.
// ============================================================================

class DetailRujukanBidanPage extends StatefulWidget {
  final String id;
  const DetailRujukanBidanPage({super.key, required this.id});

  @override
  State<DetailRujukanBidanPage> createState() => _DetailRujukanBidanPageState();
}

class _DetailRujukanBidanPageState extends State<DetailRujukanBidanPage> {
  final _svc = const RujukanService();
  RujukanDetail? _data;
  bool _loading = true;
  String? _error;
  bool _berubah = false;
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
      final d = await _svc.detailBidan(widget.id);
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

  Future<void> _ubahRujukan() async {
    final d = _data;
    if (d == null) return;
    final r = await Navigator.push<RujukanDetail>(
      context,
      MaterialPageRoute(builder: (_) => EditRujukanPage(rujukan: d)),
    );
    if (r == null || !mounted) return;
    setState(() {
      _data = r;
      _berubah = true;
    });
    _snack('Rujukan diperbarui. Orang tua mendapat pemberitahuan.');
  }

  Future<void> _hapus() async {
    final d = _data;
    if (d == null) return;
    final terhapus = await hapusRujukan(context, d);
    if (terhapus && mounted) Navigator.pop(context, true);
  }

  Future<void> _catatHasil() async {
    final d = _data;
    if (d == null) return;
    final hasil = await showModalBottomSheet<RujukanDetail>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormHasilRujukan(rujukan: d),
    );
    if (hasil == null || !mounted) return;
    setState(() {
      _data = hasil;
      _berubah = true;
    });
    _snack(d.selesai ? 'Hasil rujukan diperbarui' : 'Hasil rujukan tersimpan. Status rujukan: Selesai');
  }

  Future<void> _batalkan() async {
    final d = _data;
    if (d == null) return;
    final alasan = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Rujukan?'),
        content: TextField(
          controller: alasan,
          maxLines: 3,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Alasan pembatalan',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Batalkan Rujukan',
                style: TextStyle(color: AppColors.merah, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    final teks = alasan.text.trim();
    alasan.dispose();
    if (ok != true) return;
    if (teks.isEmpty) {
      _snack('Alasan pembatalan wajib diisi');
      return;
    }
    try {
      final r = await _svc.batal(d.id, teks);
      if (!mounted) return;
      setState(() {
        _data = r;
        _berubah = true;
      });
      _snack('Rujukan dibatalkan');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _footer() {
    final d = _data;
    if (d == null || _loading) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (d.aktif) ...[
              Row(
                children: [
                  Expanded(
                    child: TombolRujukan(
                      label: 'Edit',
                      ikon: Icons.edit_outlined,
                      isi: false,
                      onTap: _ubahRujukan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TombolRujukan(
                      label: 'Catat Hasil',
                      ikon: Icons.assignment_turned_in_outlined,
                      onTap: _catatHasil,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (d.selesai) ...[
              SizedBox(
                width: double.infinity,
                child: TombolRujukan(
                  label: 'Ubah Hasil Rujukan',
                  ikon: Icons.edit_note,
                  isi: false,
                  onTap: _catatHasil,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
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
                    isi: !d.aktif,
                    proses: _mengunduh,
                    onTap: _unduh,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _berubah);
      },
      child: Scaffold(
        backgroundColor: AppColors.latar,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Column(
            children: [
              headerRekap(context, 'Detail Rujukan'),
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
                        RujukanDetailView(d),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            if (d.aktif)
                              TextButton.icon(
                                onPressed: _batalkan,
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Batalkan Rujukan',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                style: TextButton.styleFrom(foregroundColor: AppColors.merah),
                              ),
                            TextButton.icon(
                              onPressed: _hapus,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Hapus Rujukan',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              style: TextButton.styleFrom(foregroundColor: AppColors.merah),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Form hasil rujukan (rujukan balik)
// ----------------------------------------------------------------------------

class _FormHasilRujukan extends StatefulWidget {
  final RujukanDetail rujukan;
  const _FormHasilRujukan({required this.rujukan});

  @override
  State<_FormHasilRujukan> createState() => _FormHasilRujukanState();
}

class _FormHasilRujukanState extends State<_FormHasilRujukan> {
  final _formKey = GlobalKey<FormState>();
  final _hasil = TextEditingController();
  final _terapi = TextEditingController();
  final _lanjut = TextEditingController();
  late DateTime _tanggal = DateTime.now();
  bool _menyimpan = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.rujukan.balik;
    if (b != null) {
      _hasil.text = b.hasilDiagnosis;
      _terapi.text = b.terapiSaran;
      _lanjut.text = b.tindakLanjut;
      if (b.tanggalDiperiksa != null) _tanggal = b.tanggalDiperiksa!;
    }
  }

  @override
  void dispose() {
    _hasil.dispose();
    _terapi.dispose();
    _lanjut.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final awal = widget.rujukan.tanggal ?? DateTime.now().subtract(const Duration(days: 365));
    final t = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: awal,
      lastDate: DateTime.now(),
      helpText: 'Tanggal diperiksa di faskes',
    );
    if (t != null) setState(() => _tanggal = t);
  }

  Future<void> _simpan() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _menyimpan = true;
      _error = null;
    });
    try {
      final r = await const RujukanService().catatBalik(
        widget.rujukan.id,
        tanggalDiperiksa: _tanggal,
        hasilDiagnosis: _hasil.text.trim(),
        terapiSaran: _terapi.text.trim(),
        tindakLanjut: _lanjut.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, r);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _menyimpan = false;
      });
    }
  }

  InputDecoration _dekor(String hint) => InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.5),
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

  Widget _isian(TextEditingController c, String label, String hint, {bool wajib = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(wajib ? '$label *' : label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: teksRujukan)),
            const SizedBox(height: 6),
            TextFormField(
              controller: c,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dekor(hint),
              validator: (v) => wajib && (v ?? '').trim().isEmpty ? '$label wajib diisi' : null,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: garisRujukan, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(widget.rujukan.balik == null ? 'CATAT HASIL RUJUKAN' : 'UBAH HASIL RUJUKAN',
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: teksRujukan)),
                const SizedBox(height: 4),
                Text('Hasil pemeriksaan dari ${widget.rujukan.tujuan}',
                    style: const TextStyle(fontSize: 14, color: redupRujukan)),
                const SizedBox(height: 6),
                Container(height: 3, color: aksenKartuRekap),
                const SizedBox(height: 14),
                const Text('Tanggal diperiksa *',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: teksRujukan)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pilihTanggal,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: garisRujukan, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 20, color: AppColors.hijau),
                        const SizedBox(width: 10),
                        Text(tglRujukan(_tanggal), style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _isian(_hasil, 'Hasil / diagnosis dari faskes', 'Contoh: Gizi kurang, tanpa infeksi penyerta',
                    wajib: true),
                _isian(_terapi, 'Terapi / saran dari faskes', 'Contoh: PMT pemulihan 90 hari, vitamin'),
                _isian(_lanjut, 'Tindak lanjut di posyandu', 'Contoh: Timbang ulang tiap 2 minggu'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_error!, style: const TextStyle(color: AppColors.merah)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TombolRujukan(
                        label: 'Batal',
                        ikon: Icons.close,
                        isi: false,
                        warna: AppColors.merah,
                        onTap: _menyimpan ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TombolRujukan(
                        label: 'Simpan',
                        ikon: Icons.check,
                        proses: _menyimpan,
                        onTap: _simpan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HAPUS RUJUKAN - BIDAN
// Konfirmasi, lalu hapus. Mengembalikan true bila rujukan berhasil dihapus.
// ============================================================================

Future<bool> hapusRujukan(BuildContext context, RujukanDetail r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus Rujukan?'),
      content: Text(
        'Surat rujukan ${r.nomor} untuk ${r.dataAnak.nama} akan dihapus dan tidak dapat '
        'dikembalikan. Orang tua akan diberi tahu bahwa surat ini tidak berlaku lagi.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Hapus', style: TextStyle(color: AppColors.merah, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await const RujukanService().hapus(r.id);
    if (context.mounted) Navigator.pop(context); // tutup loading
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Rujukan dihapus')));
    }
    return true;
  } catch (e) {
    if (context.mounted) Navigator.pop(context); // tutup loading
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
    return false;
  }
}