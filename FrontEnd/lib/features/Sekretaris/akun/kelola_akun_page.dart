import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/auth_provider.dart';
import '../admin_service.dart';
import 'edit_akun_page.dart';
import 'tambah_akun_page.dart';

const _hijauTua = Color(0xFF065F46); // sama dengan warna header
const _hijauGelap = Color(0xFF14634A);
const _oranyeGaris = Color(0xFFEA580C);
const hijauHeaderAkun = Color(0xFF065F46);
const _biru = Color(0xFF2563EB);
const _biruMuda = Color(0xFFE3F2FD);
const _biruGarisMuda = Color(0xFFBFDFF7);

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
  static const _filter = ['Kader', 'Bidan', 'Semua'];
  final _service = AdminService();

  String _aktif = 'Kader';
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

  Future<void> _ubah(StaffAkun a) async {
    final nama = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => EditAkunPage(akun: a, desa: _desa)),
    );
    if (nama == null) return;
    _pesan('Akun $nama diperbarui');
    await _muat(tampilLoading: false);
  }

  Future<void> _hapus(StaffAkun a) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus akun?'),
        content: Text(
            'Akun ${a.nama} (${a.labelPeran} $_desa) akan dihapus dan tidak dapat login lagi.'),
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
    try {
      await _service.hapus(a.id);
      _pesan('Akun ${a.nama} dihapus');
      await _muat(tampilLoading: false);
    } catch (e) {
      _pesan(_bersih(e));
    }
  }

  Future<void> _gantiStatus(StaffAkun a, bool nilai) async {
    try {
      await _service.setAktif(a.id, nilai);
      _pesan('Akun ${a.nama} ${nilai ? 'diaktifkan' : 'dinonaktifkan'}');
      await _muat(tampilLoading: false);
    } catch (e) {
      _pesan(_bersih(e));
    }
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
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: gayaStatusBarAkun,
        child: Column(
          children: [
            HeaderAkun(
              judul: 'Kelola Akun',
              kembali: widget.denganTombolKembali,
              actions: [
                IconButton(
                  tooltip: 'Muat ulang',
                  icon: const Icon(Icons.sync, color: Colors.white, size: 22),
                  onPressed: _memuat ? null : () => _muat(),
                ),
                IconButton(
                  tooltip: 'Tambah akun',
                  icon: const Icon(Icons.person_add_alt_1_outlined,
                      color: Colors.white, size: 22),
                  onPressed: _tambah,
                ),
                const SizedBox(width: 4),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _muat(tampilLoading: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hijauTua,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _tambah,
                        icon: const Icon(Icons.person_add_alt_1, size: 19),
                        label: const Text('Tambah Akun Petugas',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                                    color: _aktif == f
                                        ? _hijauTua
                                        : const Color(0xFFE3E8E5)),
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
                    Row(
                      children: [
                        const Icon(Icons.groups_outlined, size: 18, color: _hijauGelap),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Daftar Akun',
                              style:
                                  TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        ),
                        Pill('${daftar.length} akun terdaftar',
                            bg: AppColors.hijauMuda, fg: AppColors.hijau),
                      ],
                    ),
                    const SizedBox(height: 10),
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
      return const SectionCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Belum ada akun',
                style: TextStyle(fontSize: 16.5, color: AppColors.teksRedup)),
          ),
        ),
      );
    }
    return Column(
      children: [for (var i = 0; i < daftar.length; i++) _kartuAkun(daftar[i], i)],
    );
  }

  Widget _kartuAkun(StaffAkun a, int i) {
    const palet = [
      (Color(0xFFE8F7EF), Color(0xFFBFE5D0)),
      (Color(0xFFFFF6DD), Color(0xFFF5E1A4)),
      (Color(0xFFEAF2FD), Color(0xFFCFE1FA)),
    ];
    final (bg, garis) = palet[i % palet.length];
    final bidan = a.role == 'bidan';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role (di tengah)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: bidan ? const Color(0xFFFFE8CC) : _biruMuda,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: bidan ? const Color(0xFFF5C27A) : _biruGarisMuda),
              ),
              child: Text(a.labelPeran,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: bidan ? _oranyeGaris : _biru)),
            ),
          ),
          const SizedBox(height: 10),
          _barisInfo('Nama', a.nama),
          const SizedBox(height: 4),
          _barisInfo('No. HP', a.noHp.isEmpty ? '-' : a.noHp),
          const SizedBox(height: 10),
          // Aktif, Edit, Hapus dengan lebar dan jarak sama
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: garis),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.aktif ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: a.aktif ? AppColors.hijau : AppColors.teksRedup)),
                      Transform.scale(
                        scale: 0.65,
                        child: Switch(
                          value: a.aktif,
                          activeColor: hijauHeaderAkun,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => _gantiStatus(a, v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tombolKecil(Icons.edit_outlined, 'Edit', Colors.black87,
                    const Color(0xFFD5DBD8), () => _ubah(a)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tombolKecil(Icons.delete_outline, 'Hapus', AppColors.merah,
                    AppColors.merah.withOpacity(0.5), () => _hapus(a)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barisInfo(String label, String nilai) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
          ),
          const Text(': ', style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
          Expanded(
            child: Text(nilai,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
          ),
        ],
      );

  Widget _tombolKecil(IconData ikon, String teks, Color warna, Color garis, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: garis),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, size: 14, color: warna),
            const SizedBox(width: 4),
            Text(teks,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: warna)),
          ],
        ),
      ),
    );
  }
}