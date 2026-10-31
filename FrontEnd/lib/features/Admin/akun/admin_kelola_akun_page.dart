import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../auth/auth_provider.dart';
import '../admin_service.dart';

const _hijauTua = Color(0xFF0B3D2E);
const _hijauGelap = Color(0xFF14634A);
const _hijauGaris = Color(0xFF1FA27F);
const _biruGaris = Color(0xFF2F6FD6);
const _oranyeGaris = Color(0xFFEA580C);
const _abuGaris = Color(0xFFD5DBD8);
const _hijauHeader = Color(0xFF065F46);

// ---------------------------------------------------------------------------
// HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
// [kembali] menampilkan tombol panah di kiri, [actions] tombol di kanan.
// ---------------------------------------------------------------------------
class _HeaderHijau extends StatelessWidget {
  final String judul;
  final bool kembali;
  final List<Widget>? actions;

  const _HeaderHijau({
    required this.judul,
    this.kembali = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final adaAksi = actions != null && actions!.isNotEmpty;

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
              // Judul di tengah (jarak kiri-kanan dibuat sama agar tetap di tengah)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: adaAksi ? 104 : 56),
                child: _judulTebal(judul),
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
// JUDUL HEADER EKSTRA TEBAL (sama seperti halaman Akun)
// Teks ditumpuk dua lapis: lapis bawah berupa garis tepi (stroke) putih
// sehingga huruf terlihat lebih gemuk, lapis atas berupa isi putih biasa.
// ---------------------------------------------------------------------------
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

/// Status bar transparan dengan ikon putih (header hijau di bawahnya).
const _gayaStatusBar = SystemUiOverlayStyle(
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
    final hasil = await Navigator.push<_HasilForm>(
      context,
      MaterialPageRoute(
        builder: (_) => _AkunFormPage(
          peranAwal: _aktif == 'Bidan' ? 'bidan' : 'kader',
          desa: _desa,
        ),
      ),
    );
    if (hasil == null) return;
    try {
      await _service.tambah(
        nama: hasil.nama,
        username: hasil.username,
        password: hasil.sandi ?? '',
        role: hasil.role,
      );
      _pesan('Akun ${hasil.nama} berhasil dibuat di $_desa');
      await _muat(tampilLoading: false);
    } catch (e) {
      _pesan(_bersih(e));
    }
  }

  Future<void> _ubah(StaffAkun a) async {
    final hasil = await Navigator.push<_HasilForm>(
      context,
      MaterialPageRoute(builder: (_) => _AkunFormPage(akun: a, desa: _desa)),
    );
    if (hasil == null) return;
    try {
      await _service.ubah(
        a.id,
        nama: hasil.nama,
        username: hasil.username,
        role: hasil.role,
        password: hasil.sandi,
      );
      _pesan('Akun ${hasil.nama} diperbarui');
      await _muat(tampilLoading: false);
    } catch (e) {
      _pesan(_bersih(e));
    }
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
    final jumlahAktif = daftar.where((a) => a.aktif).length;
    final hitung = {'Kader': jmlKader, 'Bidan': jmlBidan, 'Semua': _data.length};

    return Scaffold(
      backgroundColor: AppColors.latar,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _gayaStatusBar,
        child: Column(
          children: [
            _HeaderHijau(
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F6EC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFE5D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.groups_outlined,
                                color: _hijauGelap, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _aktif == 'Semua'
                                      ? 'Seluruh Akun Staf'
                                      : 'Akun $_aktif Bertugas',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: _hijauTua),
                                ),
                                Text(
                                    '${daftar.length} akun • $jumlahAktif aktif • Posyandu $_desa',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.teksRedup)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
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
                                  TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
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
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.merah)),
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
            child: Text('Belum ada akun', style: TextStyle(color: AppColors.teksRedup)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(a.nama.isNotEmpty ? a.nama[0].toUpperCase() : '?',
                    style: const TextStyle(color: _hijauGelap, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: bidan ? const Color(0xFFFFE8CC) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: bidan ? const Color(0xFFF5C27A) : garis),
                          ),
                          child: Text(a.labelPeran,
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: bidan ? _oranyeGaris : _hijauGelap)),
                        ),
                      ],
                    ),
                    Text('@${a.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                    const SizedBox(height: 4),
                    Pill('Posyandu $_desa',
                        bg: Colors.white, fg: _biruGaris, icon: Icons.place_outlined),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: garis),
                ),
                child: Text(a.aktif ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: a.aktif ? AppColors.hijau : AppColors.teksRedup)),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: a.aktif,
                  activeColor: AppColors.hijau,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => _gantiStatus(a, v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _tombolKecil(Icons.edit_outlined, 'Edit', Colors.black87, const Color(0xFFD5DBD8),
                  () => _ubah(a)),
              const SizedBox(width: 8),
              _tombolKecil(Icons.delete_outline, 'Hapus', AppColors.merah,
                  AppColors.merah.withOpacity(0.5), () => _hapus(a)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tombolKecil(IconData ikon, String teks, Color warna, Color garis, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 74,
        height: 30,
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
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: warna)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form tambah / edit akun
// ---------------------------------------------------------------------------
class _HasilForm {
  final String nama;
  final String username;
  final String role; // 'kader' atau 'bidan'
  final String? sandi;
  const _HasilForm(this.nama, this.username, this.role, this.sandi);
}

class _AkunFormPage extends StatefulWidget {
  final StaffAkun? akun;
  final String peranAwal;
  final String desa;
  const _AkunFormPage({this.akun, this.peranAwal = 'kader', required this.desa});

  @override
  State<_AkunFormPage> createState() => _AkunFormPageState();
}

class _AkunFormPageState extends State<_AkunFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _username;
  final _sandi = TextEditingController();
  late String _peran;
  bool _lihat = false;

  bool get _edit => widget.akun != null;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: widget.akun?.nama ?? '');
    _username = TextEditingController(text: widget.akun?.username ?? '');
    _peran = widget.akun?.role ?? widget.peranAwal;
  }

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _sandi.dispose();
    super.dispose();
  }

  InputDecoration _dekor(String hint, IconData ikon, Color garis, {Widget? suffix}) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
      prefixIcon: Icon(ikon, size: 19, color: garis == _abuGaris ? Colors.black38 : garis),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: b(garis, 1.4),
      enabledBorder: b(garis, 1.4),
      focusedBorder: b(garis, 1.8),
      errorBorder: b(AppColors.merah, 1.4),
      focusedErrorBorder: b(AppColors.merah, 1.8),
    );
  }

  Widget _label(String teks, String badge, Color warnaBadge, Color bgBadge,
      {bool wajib = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 14),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: teks,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  if (wajib)
                    const TextSpan(
                        text: ' *',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.merah)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bgBadge, borderRadius: BorderRadius.circular(8)),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w800, color: warnaBadge)),
          ),
        ],
      ),
    );
  }

  void _simpan() {
    if (!_form.currentState!.validate()) return;
    final sandi = _sandi.text.trim();
    Navigator.pop(
      context,
      _HasilForm(_nama.text.trim(), _username.text.trim(), _peran,
          sandi.isEmpty ? null : sandi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nilaiPeran = _peran == 'bidan' ? 'bidan' : 'kader';

    return Scaffold(
      backgroundColor: AppColors.latar,
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hijauTua,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _simpan,
                  icon: Icon(_edit ? Icons.save_outlined : Icons.person_add_alt_1, size: 19),
                  label: Text(_edit ? 'Simpan Perubahan' : 'Buat Akun',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_edit ? 'Batal & Kembali' : 'Batal',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teksRedup)),
              ),
            ],
          ),
        ),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _gayaStatusBar,
        child: Column(
          children: [
            _HeaderHijau(
              judul: _edit ? 'Edit Akun' : 'Buat Akun Kader / Bidan',
              kembali: true,
            ),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
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
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.hijauMuda,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.badge_outlined,
                                    color: _hijauGelap, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Data Akun Petugas',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: _hijauTua)),
                                    Text(
                                      _edit
                                          ? 'Perbarui informasi akun petugas Posyandu ${widget.desa}'
                                          : 'Akun otomatis bertugas di Posyandu ${widget.desa}',
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          height: 1.3,
                                          color: AppColors.teksRedup),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _label('ROLE PETUGAS', 'Wajib Pilih', _hijauGelap,
                              AppColors.hijauMuda,
                              wajib: true),
                          DropdownButtonFormField<String>(
                            value: nilaiPeran,
                            icon: const Icon(Icons.keyboard_arrow_down, color: _hijauGelap),
                            decoration:
                                _dekor('', Icons.manage_accounts_outlined, _hijauGaris),
                            items: const [
                              DropdownMenuItem(value: 'kader', child: Text('Kader Posyandu')),
                              DropdownMenuItem(value: 'bidan', child: Text('Bidan Desa')),
                            ],
                            onChanged: (v) => setState(() => _peran = v ?? _peran),
                          ),
                          _label('NAMA LENGKAP', 'Sesuai KTP / SK', _hijauGelap,
                              AppColors.hijauMuda,
                              wajib: true),
                          TextFormField(
                            controller: _nama,
                            textCapitalization: TextCapitalization.words,
                            decoration: _dekor('Contoh: Siti Rahmawati, A.Md.Keb',
                                Icons.person_outline, _hijauGaris),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                          ),
                          _label('USERNAME AKUN', 'Min. 4 karakter', _biruGaris,
                              const Color(0xFFE6F1FF),
                              wajib: true),
                          TextFormField(
                            controller: _username,
                            decoration: _dekor('Buat username tanpa spasi',
                                Icons.alternate_email, _biruGaris),
                            validator: (v) => (v == null || v.trim().length < 4)
                                ? 'Minimal 4 karakter'
                                : null,
                          ),
                          _label(
                              _edit ? 'KATA SANDI BARU' : 'KATA SANDI AWAL',
                              _edit ? 'Opsional' : 'Min. 6 karakter',
                              _edit ? AppColors.teksRedup : _oranyeGaris,
                              _edit ? Colors.transparent : const Color(0xFFFFF1E6),
                              wajib: !_edit),
                          TextFormField(
                            controller: _sandi,
                            obscureText: !_lihat,
                            decoration: _dekor(
                              _edit ? 'Kosongkan jika tidak diubah' : 'Minimal 6 karakter',
                              Icons.lock_outline,
                              _edit ? _abuGaris : _oranyeGaris,
                              suffix: IconButton(
                                icon: Icon(
                                    _lihat
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 19,
                                    color: Colors.black45),
                                onPressed: () => setState(() => _lihat = !_lihat),
                              ),
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (_edit && t.isEmpty) return null;
                              return t.length < 6 ? 'Minimal 6 karakter' : null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}