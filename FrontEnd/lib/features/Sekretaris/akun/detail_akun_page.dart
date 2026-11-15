import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../service/admin_service.dart';
import 'edit_akun_page.dart';
import 'kelola_akun_page.dart';

const _teksGelap = Color(0xFF1F2937);

/// Detail satu akun petugas (kader / bidan).
/// Mengembalikan pesan (String) ke halaman Kelola Akun bila ada perubahan.
class DetailAkunPage extends StatefulWidget {
  final StaffAkun akun;
  final String desa;

  const DetailAkunPage({super.key, required this.akun, required this.desa});

  @override
  State<DetailAkunPage> createState() => _DetailAkunPageState();
}

class _DetailAkunPageState extends State<DetailAkunPage> {
  final _service = AdminService();
  late bool _aktif = widget.akun.aktif;
  bool _proses = false;
  String? _pesanKembali;

  StaffAkun get a => widget.akun;

  void _snack(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  String _bersih(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _ubah() async {
    final nama = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => EditAkunPage(akun: a, desa: widget.desa)),
    );
    if (nama == null || !mounted) return;
    Navigator.pop(context, 'Akun $nama diperbarui');
  }

  Future<void> _gantiStatus(bool nilai) async {
    setState(() => _proses = true);
    try {
      await _service.setAktif(a.id, nilai);
      if (!mounted) return;
      setState(() => _aktif = nilai);
      _pesanKembali = 'Akun ${a.nama} ${nilai ? 'diaktifkan' : 'dinonaktifkan'}';
      _snack(_pesanKembali!);
    } catch (e) {
      _snack(_bersih(e));
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _hapus() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus akun?'),
        content: Text(
            'Akun ${a.nama} (${a.labelPeran} ${widget.desa}) akan dihapus dan tidak dapat login lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.merah, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    setState(() => _proses = true);
    try {
      await _service.hapus(a.id);
      if (!mounted) return;
      Navigator.pop(context, 'Akun ${a.nama} dihapus');
    } catch (e) {
      _snack(_bersih(e));
      if (mounted) setState(() => _proses = false);
    }
  }

  // ------------------------------------------------------------------ tampilan

  Widget _baris(String label, String? nilai) {
    const gaya = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: _teksGelap);
    final kosong = nilai == null || nilai.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 118, child: Text(label, style: gaya)),
          const Text(': ', style: gaya),
          Expanded(
            child: Text(
              kosong ? 'Belum dilengkapi' : nilai!,
              style: kosong
                  ? const TextStyle(fontSize: 16, height: 1.3, color: AppColors.teksRedup)
                  : gaya,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartu({required String judul, Widget? kanan, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: bayanganKartuAkun,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kepalaKartuAkun(judul, kanan: kanan),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (sudah, _) {
        if (!sudah) Navigator.pop(context, _pesanKembali);
      },
      child: Scaffold(
        backgroundColor: AppColors.latar,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.merah,
                        side: const BorderSide(color: AppColors.merah, width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _proses ? null : _hapus,
                      child: const Text('Hapus',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hijauHeaderAkun,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _proses ? null : _ubah,
                      child: const Text('Edit',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: AnnotatedRegion(
          value: gayaStatusBarAkun,
          child: Column(
            children: [
              const HeaderAkun(judul: 'Detail Akun', kembali: true),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _kartu(
                      judul: 'Data Akun',
                      kanan: Text(a.labelPeran,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
                      child: Column(
                        children: [
                          _baris('Nama', a.nama),
                          _baris('Role', a.labelPeran),
                          _baris('No. HP', a.noHp),
                          _baris('Posyandu', widget.desa),
                        ],
                      ),
                    ),
                    _kartu(
                      judul: 'Data Diri',
                      child: Column(
                        children: [
                          // Diisi lewat fitur "lengkapi data diri" kader / bidan (menyusul).
                          _baris('NIK', null),
                          _baris('Tanggal Lahir', null),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: bayanganKartuAkun,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Status Akun',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600, color: _teksGelap)),
                          ),
                          Text(_aktif ? 'Aktif' : 'Nonaktif',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _aktif ? AppColors.hijau : AppColors.teksRedup)),
                          Switch(
                            value: _aktif,
                            activeColor: hijauHeaderAkun,
                            onChanged: _proses ? null : _gantiStatus,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}