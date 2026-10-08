import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'register_page.dart';

const _hijau = Color(0xFF0B6B4D);
const _hijauGelap = Color(0xFF062B20);
const _hijauTerang = Color(0xFF7FE3C0);
const _teal = Color(0xFF2BB59A);
const _judul = Color(0xFF0F6F82);
const _oranye = Color(0xFFFF7A1A);
const _oranyeGelap = Color(0xFFE8590C);
const _latar = Color(0xFFF3F2FB);
const _isiField = Color(0xFFF3FBF8);
const _biruMuda = Color(0xFFE6F1FF);
const _biru = Color(0xFF2F6FD6);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idf = TextEditingController();
  final _pw = TextEditingController();
  bool _hide = true;
  bool _ingat = true;

  @override
  void dispose() {
    _idf.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_idf.text.trim().isEmpty || _pw.text.isEmpty) {
      _snack('Nomor WhatsApp/NIK dan kata sandi wajib diisi');
      return;
    }
    try {
      await context.read<AuthProvider>().login(_idf.text.trim(), _pw.text);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  InputDecoration _dekor(String hint, {Widget? suffix}) {
    OutlineInputBorder garis(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
      suffixIcon: suffix,
      filled: true,
      fillColor: _isiField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: garis(_teal.withOpacity(0.55), 1.4),
      enabledBorder: garis(_teal.withOpacity(0.55), 1.4),
      focusedBorder: garis(_teal, 1.8),
    );
  }

  Widget _label(String kiri, String kanan, Color warnaKanan) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(kiri,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
            Text(kanan,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 11.5, color: warnaKanan)),
          ],
        ),
      );

  Widget _kepala() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_outlined, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('Mode Offline Siap Digunakan',
                    style: TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1FA27F), _hijau],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
              ],
            ),
            child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 14),
          const Text('Posyandu Care',
              style: TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Aplikasi Pemantauan Tumbuh Kembang Anak & KIA Digital',
            textAlign: TextAlign.center,
            style: TextStyle(color: _hijauTerang, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;

    return Scaffold(
      backgroundColor: _latar,
      body: Stack(
        children: [
          // Latar gradien hijau di bagian atas
          Container(
            height: 330,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_hijauGelap, _hijau],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  _kepala(),
                  const SizedBox(height: 22),

                  // Kartu form login
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26, blurRadius: 24, offset: Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              const Text('Masuk ke Akun Anda',
                                  style: TextStyle(
                                      color: _judul,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Container(
                                width: 44,
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [_teal, _oranye]),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Pantau kesehatan dan gizi buah hati secara berkala tanpa batas koneksi',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _label('No. HP atau NIK', 'Wajib', _oranye),
                        TextField(
                          controller: _idf,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          decoration:
                              _dekor('Contoh: 0812-3456-7890 atau 16 Digit'),
                        ),
                        const SizedBox(height: 14),
                        _label('Kata Sandi / PIN 6 Digit', 'Enkripsi Lokal',
                            Colors.black45),
                        TextField(
                          controller: _pw,
                          obscureText: _hide,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => loading ? null : _submit(),
                          decoration: _dekor(
                            '••••••••',
                            suffix: IconButton(
                              icon: Icon(
                                  _hide
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: _teal),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Checkbox(
                                value: _ingat,
                                activeColor: _hijau,
                                visualDensity: VisualDensity.compact,
                                onChanged: (v) => setState(() => _ingat = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Ingat akun', style: TextStyle(fontSize: 12.5)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: _hijau, shape: BoxShape.circle),
                              child: const Icon(Icons.shield_outlined,
                                  color: Colors.white, size: 11),
                            ),
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _snack(
                                  'Hubungi kader atau admin posyandu untuk reset kata sandi'),
                              child: const Text('Lupa Sandi?',
                                  style: TextStyle(
                                      color: _oranye,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Tombol masuk (oranye)
                        Opacity(
                          opacity: loading ? 0.7 : 1,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_oranye, _oranyeGelap]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: _oranye.withOpacity(0.4),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: loading ? null : _submit,
                                child: Center(
                                  child: loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Masuk Sekarang',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15)),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward,
                                                color: Colors.white, size: 18),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pembatas
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.black12)),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _biruMuda,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('ATAU MASUK LEBIH CEPAT',
                                  style: TextStyle(
                                      color: _biru,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const Expanded(child: Divider(color: Colors.black12)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Biometrik
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _biruMuda,
                              foregroundColor: _biru,
                              side: const BorderSide(color: Color(0xFFCFE1FA)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _snack(
                                'Masuk dengan biometrik akan tersedia pada tahap berikutnya'),
                            icon: const Icon(Icons.fingerprint, size: 22),
                            label: const Text('Masuk dengan Sidik Jari / Biometrik',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.black12, height: 1),
                        const SizedBox(height: 10),

                        // Daftar akun baru
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.center,
                            children: [
                              const Text('Belum memiliki akun Posyandu? ',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RegisterPage()),
                                ),
                                child: const Text('Daftar Akun Baru',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87)),
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
        ],
      ),
    );
  }
}