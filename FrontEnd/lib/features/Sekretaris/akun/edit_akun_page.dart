import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/pin_util.dart';
import '../admin_service.dart';
import 'kelola_akun_page.dart' show HeaderAkun, gayaStatusBarAkun;

const _hijauTua = Color(0xFF065F46); // sama dengan warna header
const _hijauGelap = Color(0xFF14634A);
const _hijauGaris = Color(0xFF1FA27F);
const _biruGaris = Color(0xFF2F6FD6);
const _abuGaris = Color(0xFFD5DBD8);

// ---------------------------------------------------------------------------
// HALAMAN EDIT AKUN (kader / bidan)
// Mengirim data ke server lalu kembali ke Kelola Akun dengan nama akun.
// ---------------------------------------------------------------------------
class EditAkunPage extends StatefulWidget {
  final StaffAkun akun;
  final String desa;
  const EditAkunPage({super.key, required this.akun, required this.desa});

  @override
  State<EditAkunPage> createState() => _EditAkunPageState();
}

class _EditAkunPageState extends State<EditAkunPage> {
  final _form = GlobalKey<FormState>();
  final _service = AdminService();
  late final TextEditingController _nama;
  late final TextEditingController _username;
  late final TextEditingController _noHp;
  final _pin = TextEditingController();
  late String _peran;
  bool _lihat = false;
  bool _menyimpan = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: widget.akun.nama);
    _username = TextEditingController(text: widget.akun.username);
    _noHp = TextEditingController(text: widget.akun.noHp);
    _peran = widget.akun.role == 'bidan' ? 'bidan' : 'kader';
  }

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _noHp.dispose();
    _pin.dispose();
    super.dispose();
  }

  InputDecoration _dekor(String hint, IconData ikon, Color garis, {Widget? suffix}) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 16, color: Colors.black38),
      counterText: '',
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
                          fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  if (wajib)
                    const TextSpan(
                        text: ' *',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                    fontSize: 14.5, fontWeight: FontWeight.w600, color: warnaBadge)),
          ),
        ],
      ),
    );
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (!_form.currentState!.validate()) return;
    final pin = _pin.text.trim();
    setState(() {
      _menyimpan = true;
      _galat = null;
    });
    try {
      await _service.ubah(
        widget.akun.id,
        nama: _nama.text.trim(),
        username: _username.text.trim(),
        noHp: _noHp.text.trim(),
        role: _peran,
        pin: pin.isEmpty ? null : pin,
      );
      if (!mounted) return;
      Navigator.pop(context, _nama.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _galat = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: _menyimpan ? null : _simpan,
                  icon: _menyimpan
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 19),
                  label: Text(_menyimpan ? 'Menyimpan...' : 'Simpan Perubahan',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
                ),
              ),
              TextButton(
                onPressed: _menyimpan ? null : () => Navigator.pop(context),
                child: const Text('Batal',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.teksRedup)),
              ),
            ],
          ),
        ),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: gayaStatusBarAkun,
        child: Column(
          children: [
            const HeaderAkun(judul: 'Edit Akun', kembali: true),
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
                          const Text('Data Akun Petugas',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600, color: _hijauTua)),
                          Text(
                            'Perbarui informasi akun petugas Posyandu ${widget.desa}',
                            style: const TextStyle(
                                fontSize: 16, height: 1.3, color: AppColors.teksRedup),
                          ),
                          _label('ROLE PETUGAS', 'Wajib Pilih', _hijauGelap,
                              AppColors.hijauMuda,
                              wajib: true),
                          DropdownButtonFormField<String>(
                            value: _peran,
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
                          _label('NO. HP / WHATSAPP', '10-15 digit', _hijauGelap,
                              AppColors.hijauMuda,
                              wajib: true),
                          TextFormField(
                            controller: _noHp,
                            keyboardType: TextInputType.phone,
                            maxLength: 15,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _dekor('Contoh: 081234567890',
                                Icons.phone_outlined, _hijauGaris),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.length < 10 || t.length > 15) {
                                return 'No. HP 10-15 digit angka';
                              }
                              return null;
                            },
                          ),
                          _label(
                              'PIN BARU',
                              'Opsional',
                              AppColors.teksRedup,
                              Colors.transparent,
                              wajib: false),
                          TextFormField(
                            controller: _pin,
                            obscureText: !_lihat,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _dekor(
                              'Kosongkan jika tidak diubah',
                              Icons.pin_outlined,
                              _abuGaris,
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
                              if (t.isEmpty) return null;
                              return validasiPin(t);
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_galat != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_galat!,
                            style: const TextStyle(fontSize: 16, color: AppColors.merah)),
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