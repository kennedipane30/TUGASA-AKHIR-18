import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/auth_provider.dart';
import '../admin_service.dart';
import 'detail_akun_page.dart';
import 'tambah_akun_page.dart';

const _hijauTua = Color(0xFF065F46); // sama dengan warna header
const _hitam = Color(0xFF1F2937);
const hijauHeaderAkun = Color(0xFF065F46);

/// Garis tepi kartu, filter & kolom isian: hitam lembut (tidak mencolok).
const garisKartuAkun = Color(0xFFB8BEC6);

// ---------------------------------------------------------------------------
// HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
// [kembali] menampilkan tombol panah di kiri, [actions] tombol di kanan.
// ---------------------------------------------------------------------------
class HeaderAkun extends StatelessWidget {
  final String judul;
  final bool kembali;
  final List<Widget>? actions;

  const HeaderAkun({
    super.key,
    required this.judul,
    this.kembali = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final adaAksi = actions != null && actions!.isNotEmpty;

    return Container(
      width: double.infinity,
      color: hijauHeaderAkun,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Judul di tengah (jarak kiri-kanan dibuat sama agar tetap di tengah)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: adaAksi ? 104 : 56),
                child: judulHeaderAkun(judul),
              ),
              // Tombol kembali di kiri
              if (kembali)
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
              // Tombol aksi di kanan
              if (adaAksi)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// JUDUL HEADER (gaya teks sama dengan halaman lain)
// ---------------------------------------------------------------------------
Widget judulHeaderAkun(String teks) {
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

/// Status bar transparan dengan ikon putih (header hijau di bawahnya).
const gayaStatusBarAkun = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

class AdminKelolaAkunPage extends StatefulWidget {
  /// true jika halaman dibuka lewat Navigator.push (menu Aksi Cepat).
  final bool denganTombolKembali;
  const AdminKelolaAkunPage({super.key, this.denganTombolKembali = false});

  @override
  State<AdminKelolaAkunPage> createState() => _AdminKelolaAkunPageState();
}

class _AdminKelolaAkunPageState extends State<AdminKelolaAkunPage> {
  static const _filter = ['Semua', 'Kader', 'Bidan'];
  final _service = AdminService();

  String _aktif = 'Semua';
  bool _memuat = true;
  String? _galat;
  List<StaffAkun> _data = [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  String get _desa {
    final u = context.read<AuthProvider>().user;
    final n = (u?['posyandu_nama'] ?? '').toString();
    return n.isEmpty ? 'desa Anda' : n;
  }

  String _bersih(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _muat({bool tampilLoading = true}) async {
    if (tampilLoading) setState(() => _memuat = true);
    try {
      final hasil = await _service.daftarStaff();
      if (!mounted) return;
      setState(() {
        _data = hasil;
        _galat = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = _bersih(e);
        _memuat = false;
      });
    }
  }

  Future<void> _tambah() async {
    final nama = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => TambahAkunPage(
          peranAwal: _aktif == 'Bidan' ? 'bidan' : 'kader',
          desa: _desa,
        ),
      ),
    );
    if (nama == null) return;
    _pesan('Akun $nama berhasil dibuat di $_desa');
    await _muat(tampilLoading: false);
  }

  Future<void> _bukaDetail(StaffAkun a) async {
    final pesan = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => DetailAkunPage(akun: a, desa: _desa)),
    );
    if (pesan != null) _pesan(pesan);
    await _muat(tampilLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final jmlKader = _data.where((a) => a.role == 'kader').length;
    final jmlBidan = _data.where((a) => a.role == 'bidan').length;
    final daftar = switch (_aktif) {
      'Kader' => _data.where((a) => a.role == 'kader').toList(),
      'Bidan' => _data.where((a) => a.role == 'bidan').toList(),
      _ => _data,
    };
    final hitung = {'Kader': jmlKader, 'Bidan': jmlBidan, 'Semua': _data.length};

    return Scaffold(
      backgroundColor: AppColors.latar,
      // Tombol tambah akun tetap di bawah (tidak ikut bergulir)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hijauTua,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _tambah,
              child: const Text('Tambah Akun Petugas',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
            ),
          ),
        ),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: gayaStatusBarAkun,
        child: Column(
          children: [
            HeaderAkun(
              judul: 'Kelola Akun',
              kembali: widget.denganTombolKembali,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _muat(tampilLoading: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in _filter)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('$f (${hitung[f]})'),
                                selected: _aktif == f,
                                selectedColor: _hijauTua,
                                backgroundColor: Colors.white,
                                showCheckmark: false,
                                side: BorderSide(
                                    color: _aktif == f ? _hijauTua : garisKartuAkun,
                                    width: 1.2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: _aktif == f ? Colors.white : Colors.black87,
                                ),
                                onSelected: (_) => setState(() => _aktif = f),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _isiDaftar(daftar),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _isiDaftar(List<StaffAkun> daftar) {
    if (_memuat) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_galat != null) {
      return SectionCard(
        color: AppColors.kuningMuda,
        child: Column(
          children: [
            Text(_galat!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16.5, color: AppColors.merah)),
            const SizedBox(height: 10),
            AppButton('Coba Lagi', icon: Icons.refresh, filled: false, onPressed: () => _muat()),
          ],
        ),
      );
    }
    if (daftar.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: garisKartuAkun, width: 1.2),
        ),
        child: const Text('Belum ada akun',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16.5, color: AppColors.teksRedup)),
      );
    }
    return Column(
      children: [for (var i = 0; i < daftar.length; i++) _kartuAkun(daftar[i], i)],
    );
  }

  Widget _kartuAkun(StaffAkun a, int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _bukaDetail(a),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: garisKartuAkun, width: 1.2),
            ),
            child: Column(
              children: [
                _baris('Role', a.aktif ? a.labelPeran : '${a.labelPeran} (Nonaktif)'),
                _baris('Nama', a.nama),
                _baris('No. HP', a.noHp.isEmpty ? '-' : a.noHp),
                const SizedBox(height: 2),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lihat detail',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: _hijauTua)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16, color: _hijauTua),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Baris "Label : nilai" (satu warna hitam).
  Widget _baris(String label, String nilai) {
    const gaya = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: _hitam);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: gaya)),
          const Text(': ', style: gaya),
          Expanded(
            child: Text(nilai, maxLines: 1, overflow: TextOverflow.ellipsis, style: gaya),
          ),
        ],
      ),
    );
  }
}