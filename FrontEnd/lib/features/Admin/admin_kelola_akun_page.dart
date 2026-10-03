import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';

class _Akun {
  final int id;
  final String nama;
  final String username;
  final String peran;
  final bool aktif;
  const _Akun({
    required this.id,
    required this.nama,
    required this.username,
    required this.peran,
    this.aktif = true,
  });

  _Akun salin({String? nama, String? username, String? peran, bool? aktif}) => _Akun(
        id: id,
        nama: nama ?? this.nama,
        username: username ?? this.username,
        peran: peran ?? this.peran,
        aktif: aktif ?? this.aktif,
      );
}

class AdminKelolaAkunPage extends StatefulWidget {
  /// true jika halaman dibuka lewat Navigator.push (menu Aksi Cepat).
  final bool denganTombolKembali;
  const AdminKelolaAkunPage({super.key, this.denganTombolKembali = false});

  @override
  State<AdminKelolaAkunPage> createState() => _AdminKelolaAkunPageState();
}

class _AdminKelolaAkunPageState extends State<AdminKelolaAkunPage> {
  static const _filter = ['Kader', 'Bidan', 'Semua'];
  String _aktif = 'Kader';
  int _idBerikut = 6;

  // DATA CONTOH. Ganti dengan data dari API (GET/POST/PUT/DELETE akun staf).
  final List<_Akun> _data = [
    const _Akun(id: 1, nama: 'Siti Aminah', username: 'siti.aminah', peran: 'Kader'),
    const _Akun(id: 2, nama: 'Dewi Lestari', username: 'dewi.lestari', peran: 'Kader'),
    const _Akun(id: 3, nama: 'Rina Marlina', username: 'rina.marlina', peran: 'Kader'),
    const _Akun(
        id: 4, nama: 'Yuni Astuti', username: 'yuni.astuti', peran: 'Kader', aktif: false),
    const _Akun(id: 5, nama: 'Bidan Ratna', username: 'bidan.ratna', peran: 'Bidan'),
  ];

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _tambah() async {
    final hasil = await Navigator.push<_HasilForm>(
      context,
      MaterialPageRoute(builder: (_) => _AkunFormPage(peranAwal: _aktif == 'Bidan' ? 'Bidan' : 'Kader')),
    );
    if (hasil == null) return;
    setState(() {
      _data.add(_Akun(
        id: _idBerikut++,
        nama: hasil.nama,
        username: hasil.username,
        peran: hasil.peran,
      ));
    });
    _pesan('Akun ${hasil.nama} berhasil dibuat');
  }

  Future<void> _ubah(_Akun a) async {
    final hasil = await Navigator.push<_HasilForm>(
      context,
      MaterialPageRoute(builder: (_) => _AkunFormPage(akun: a)),
    );
    if (hasil == null) return;
    setState(() {
      final i = _data.indexWhere((e) => e.id == a.id);
      if (i != -1) {
        _data[i] = a.salin(
          nama: hasil.nama,
          username: hasil.username,
          peran: hasil.peran,
        );
      }
    });
    _pesan('Akun ${hasil.nama} diperbarui');
  }

  Future<void> _hapus(_Akun a) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus akun?'),
        content: Text('Akun ${a.nama} (${a.peran}) akan dihapus dan tidak dapat login lagi.'),
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
    setState(() => _data.removeWhere((e) => e.id == a.id));
    _pesan('Akun ${a.nama} dihapus');
  }

  void _gantiStatus(_Akun a, bool nilai) {
    setState(() {
      final i = _data.indexWhere((e) => e.id == a.id);
      if (i != -1) _data[i] = a.salin(aktif: nilai);
    });
    _pesan('Akun ${a.nama} ${nilai ? 'diaktifkan' : 'dinonaktifkan'}');
  }

  @override
  Widget build(BuildContext context) {
    final daftar =
        _aktif == 'Semua' ? _data : _data.where((a) => a.peran == _aktif).toList();
    final jumlahAktif = daftar.where((a) => a.aktif).length;

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Kelola Akun', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: widget.denganTombolKembali,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
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
            child: daftar.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('Belum ada akun',
                          style: TextStyle(color: AppColors.teksRedup)),
                    ),
                  )
                : Column(children: [for (final a in daftar) _kartuAkun(a)]),
          ),
        ],
      ),
    );
  }

  Widget _kartuAkun(_Akun a) {
    final warnaPeran = a.peran == 'Bidan' ? AppColors.biru : AppColors.hijau;
    final bgPeran = a.peran == 'Bidan' ? AppColors.biruMuda : AppColors.hijauMuda;

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
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text('@${a.username}',
                        style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              Pill(a.peran, bg: bgPeran, fg: warnaPeran),
            ],
          ),
          const SizedBox(height: 8),
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
              const Spacer(),
              SizedBox(
                width: 96,
                child: AppButton('Edit',
                    icon: Icons.edit_outlined, filled: false, onPressed: () => _ubah(a)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 104,
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
  final String peran;
  final String? sandi;
  const _HasilForm(this.nama, this.username, this.peran, this.sandi);
}

class _AkunFormPage extends StatefulWidget {
  final _Akun? akun;
  final String peranAwal;
  const _AkunFormPage({this.akun, this.peranAwal = 'Kader'});

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
    _peran = widget.akun?.peran ?? widget.peranAwal;
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
                      DropdownMenuItem(value: 'Kader', child: Text('Kader')),
                      DropdownMenuItem(value: 'Bidan', child: Text('Bidan')),
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
                      _edit ? 'Kata sandi baru (kosongkan jika tidak diubah)' : 'Kata sandi awal (min. 6)',
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