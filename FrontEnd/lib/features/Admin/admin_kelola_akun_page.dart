import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import 'admin_service.dart';

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
          builder: (_) => _AkunFormPage(peranAwal: _aktif == 'Bidan' ? 'bidan' : 'kader')),
    );
    if (hasil == null) return;
    try {
      await _service.tambah(
        nama: hasil.nama,
        username: hasil.username,
        password: hasil.sandi ?? '',
        role: hasil.role,
      );
      _pesan('Akun ${hasil.nama} berhasil dibuat');
      await _muat(tampilLoading: false);
    } catch (e) {
      _pesan(_bersih(e));
    }
  }

  Future<void> _ubah(StaffAkun a) async {
    final hasil = await Navigator.push<_HasilForm>(
      context,
      MaterialPageRoute(builder: (_) => _AkunFormPage(akun: a)),
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
        content: Text('Akun ${a.nama} (${a.labelPeran}) akan dihapus dan tidak dapat login lagi.'),
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
    final daftar = switch (_aktif) {
      'Kader' => _data.where((a) => a.role == 'kader').toList(),
      'Bidan' => _data.where((a) => a.role == 'bidan').toList(),
      _ => _data,
    };
    final jumlahAktif = daftar.where((a) => a.aktif).length;

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Kelola Akun', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: widget.denganTombolKembali,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _memuat ? null : () => _muat(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _muat(tampilLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SectionCard(
              color: AppColors.hijauMuda,
              child: Row(
                children: [
                  const Icon(Icons.manage_accounts, color: AppColors.hijau),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _aktif == 'Semua' ? 'Seluruh Akun Staf' : 'Akun $_aktif Bertugas',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text('${daftar.length} akun · $jumlahAktif aktif',
                            style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppButton('Tambah Akun', icon: Icons.person_add_alt_1, onPressed: _tambah),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in _filter)
                  ChoiceChip(
                    label: Text(f),
                    selected: _aktif == f,
                    selectedColor: AppColors.hijau,
                    backgroundColor: Colors.white,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _aktif == f ? Colors.white : Colors.black87,
                    ),
                    onSelected: (_) => setState(() => _aktif = f),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Daftar Akun',
              icon: Icons.groups_outlined,
              trailing: Pill('${daftar.length} akun', bg: AppColors.biruMuda, fg: AppColors.biru),
              child: _isiDaftar(daftar),
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(_galat!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.merah)),
            const SizedBox(height: 10),
            AppButton('Coba Lagi', icon: Icons.refresh, filled: false, onPressed: () => _muat()),
          ],
        ),
      );
    }
    if (daftar.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('Belum ada akun', style: TextStyle(color: AppColors.teksRedup)),
        ),
      );
    }
    return Column(children: [for (final a in daftar) _kartuAkun(a)]);
  }

  Widget _kartuAkun(StaffAkun a) {
    final warnaPeran = a.role == 'bidan' ? AppColors.biru : AppColors.hijau;
    final bgPeran = a.role == 'bidan' ? AppColors.biruMuda : AppColors.hijauMuda;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: bgPeran,
                child: Text(a.nama.isNotEmpty ? a.nama[0].toUpperCase() : '?',
                    style: TextStyle(color: warnaPeran, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text('@${a.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Pill(a.labelPeran, bg: bgPeran, fg: warnaPeran),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Pill(a.aktif ? 'Aktif' : 'Nonaktif',
                  bg: a.aktif ? AppColors.hijauMuda : AppColors.isiField,
                  fg: a.aktif ? AppColors.hijau : AppColors.teksRedup),
              const SizedBox(width: 4),
              Switch(
                value: a.aktif,
                activeColor: AppColors.hijau,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => _gantiStatus(a, v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AppButton('Edit',
                    icon: Icons.edit_outlined, filled: false, onPressed: () => _ubah(a)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton('Hapus',
                    icon: Icons.delete_outline,
                    filled: false,
                    color: AppColors.merah,
                    onPressed: () => _hapus(a)),
              ),
            ],
          ),
        ],
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
  const _AkunFormPage({this.akun, this.peranAwal = 'kader'});

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

  InputDecoration _dekor(String label, {Widget? suffix}) => InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.isiField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  void _simpan() {
    if (!_form.currentState!.validate()) return;
    final sandi = _sandi.text.trim();
    Navigator.pop(
      context,
      _HasilForm(_nama.text.trim(), _username.text.trim(), _peran, sandi.isEmpty ? null : sandi),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: Text(_edit ? 'Edit Akun' : 'Buat Akun Kader / Bidan',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Data Akun',
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _peran,
                    decoration: _dekor('Role'),
                    items: const [
                      DropdownMenuItem(value: 'kader', child: Text('Kader')),
                      DropdownMenuItem(value: 'bidan', child: Text('Bidan')),
                    ],
                    onChanged: (v) => setState(() => _peran = v ?? _peran),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nama,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dekor('Nama lengkap'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _username,
                    decoration: _dekor('Username (min. 4)'),
                    validator: (v) =>
                        (v == null || v.trim().length < 4) ? 'Minimal 4 karakter' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sandi,
                    obscureText: !_lihat,
                    decoration: _dekor(
                      _edit
                          ? 'Kata sandi baru (kosongkan jika tidak diubah)'
                          : 'Kata sandi awal (min. 6)',
                      suffix: IconButton(
                        icon: Icon(_lihat ? Icons.visibility_off : Icons.visibility),
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
            AppButton(_edit ? 'Simpan Perubahan' : 'Buat Akun',
                icon: _edit ? Icons.save_outlined : Icons.person_add_alt_1,
                onPressed: _simpan),
          ],
        ),
      ),
    );
  }
}