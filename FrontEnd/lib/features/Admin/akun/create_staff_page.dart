import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../auth/auth_service.dart';

const _hijauTua = Color(0xFF0B3D2E);
const _hijauGelap = Color(0xFF14634A);
const _hijauGaris = Color(0xFF1FA27F);
const _biruGaris = Color(0xFF2F6FD6);
const _oranyeGaris = Color(0xFFEA580C);

class CreateStaffPage extends StatefulWidget {
  const CreateStaffPage({super.key});

  @override
  State<CreateStaffPage> createState() => _CreateStaffPageState();
}

class _CreateStaffPageState extends State<CreateStaffPage> {
  final _key = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _username = TextEditingController();
  final _pw = TextEditingController();
  String _role = 'kader';
  bool _loading = false;
  bool _lihat = false;

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().createStaff(
        nama: _nama.text.trim(),
        username: _username.text.trim(),
        password: _pw.text,
        role: _role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akun $_role berhasil dibuat')));
      _nama.clear();
      _username.clear();
      _pw.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dekor(String hint, IconData ikon, Color garis, {Widget? suffix}) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
      prefixIcon: Icon(ikon, size: 19, color: garis),
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

  Widget _label(String teks, String badge, Color warnaBadge, Color bgBadge) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Buat Akun Kader / Bidan',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
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
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.person_add_alt_1, size: 19),
                  label: Text(_loading ? 'Menyimpan...' : 'Buat Akun',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Batal',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teksRedup)),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _key,
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
                        child: const Icon(Icons.badge_outlined, color: _hijauGelap, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data Akun Petugas',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800, color: _hijauTua)),
                            Text(
                              'Lengkapi informasi akun kader atau bidan untuk akses Posyandu Care',
                              style: TextStyle(
                                  fontSize: 10.5, height: 1.3, color: AppColors.teksRedup),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _label('ROLE PETUGAS', 'Wajib Pilih', _hijauGelap, AppColors.hijauMuda),
                  DropdownButtonFormField<String>(
                    value: _role,
                    icon: const Icon(Icons.keyboard_arrow_down, color: _hijauGelap),
                    decoration: _dekor('', Icons.manage_accounts_outlined, _hijauGaris),
                    items: const [
                      DropdownMenuItem(value: 'kader', child: Text('Kader Posyandu')),
                      DropdownMenuItem(value: 'bidan', child: Text('Bidan Desa')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? _role),
                  ),
                  _label('NAMA LENGKAP', 'Sesuai KTP / SK', _hijauGelap, AppColors.hijauMuda),
                  TextFormField(
                    controller: _nama,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dekor(
                        'Contoh: Siti Rahmawati, A.Md.Keb', Icons.person_outline, _hijauGaris),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                  ),
                  _label('USERNAME AKUN', 'Min. 4 karakter', _biruGaris,
                      const Color(0xFFE6F1FF)),
                  TextFormField(
                    controller: _username,
                    decoration: _dekor(
                        'Buat username tanpa spasi', Icons.alternate_email, _biruGaris),
                    validator: (v) =>
                        (v == null || v.trim().length < 4) ? 'Minimal 4 karakter' : null,
                  ),
                  _label('KATA SANDI AWAL', 'Min. 6 karakter', _oranyeGaris,
                      const Color(0xFFFFF1E6)),
                  TextFormField(
                    controller: _pw,
                    obscureText: !_lihat,
                    decoration: _dekor(
                      'Minimal 6 karakter',
                      Icons.lock_outline,
                      _oranyeGaris,
                      suffix: IconButton(
                        icon: Icon(
                            _lihat ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 19,
                            color: Colors.black45),
                        onPressed: () => setState(() => _lihat = !_lihat),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F6EC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: _hijauGelap,
                          child: Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                    text: 'Penyimpanan Terenkripsi Lokal: ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800, color: _hijauTua)),
                                TextSpan(
                                  text:
                                      'Akun baru dapat langsung digunakan untuk mencatat pertumbuhan & kegiatan posyandu walau tanpa jaringan internet.',
                                  style: TextStyle(color: AppColors.teksRedup),
                                ),
                              ],
                            ),
                            style: TextStyle(fontSize: 10.5, height: 1.4),
                          ),
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
    );
  }
}