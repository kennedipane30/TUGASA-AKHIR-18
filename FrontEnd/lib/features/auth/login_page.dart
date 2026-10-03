import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'register_page.dart';

const _hijau = Color(0xFF0B6B4D);
const _latar = Color(0xFFF3F2FB);
const _isiField = Color(0xFFEDEBF7);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idf = TextEditingController();
  final _pw = TextEditingController();
  bool _hide = true;
  bool _ingat = false;

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

  InputDecoration _dekor(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
      suffixIcon: suffix,
      filled: true,
      fillColor: _isiField,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _label(String teks) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text.rich(
          TextSpan(
            text: teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            children: const [
              TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;

    return Scaffold(
      backgroundColor: _latar,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _hijau,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.child_care, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Posyandu Sehat',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('Sistem Informasi Posyandu Terintegrasi',
                              style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Judul
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: _hijau,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.child_friendly, color: Colors.white, size: 46),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Selamat Datang di Posyandu\nSehat Nusantara',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Layanan digital pemantauan tumbuh kembang anak & kesehatan balita terpadu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Form login
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F4EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Mandiri & KMS',
                          style: TextStyle(
                              color: _hijau, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 16),
                    _label('Nomor WhatsApp / NIK'),
                    TextField(
                      controller: _idf,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: _dekor('Contoh: 08123456789 atau 3273...', Icons.badge_outlined),
                    ),
                    const SizedBox(height: 16),
                    _label('Kata Sandi / PIN 6 Digit'),
                    TextField(
                      controller: _pw,
                      obscureText: _hide,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => loading ? null : _submit(),
                      decoration: _dekor(
                        'Masukkan kata sandi akun',
                        Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _ingat,
                          activeColor: _hijau,
                          onChanged: (v) => setState(() => _ingat = v ?? false),
                        ),
                        const Text('Ingat Saya', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _snack(
                              'Hubungi kader atau admin posyandu untuk reset kata sandi'),
                          child: const Text('Lupa Kata Sandi?',
                              style: TextStyle(
                                  color: _hijau, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hijau,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: loading ? null : _submit,
                        icon: loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.login),
                        label: Text(loading ? 'Memproses...' : 'Masuk Sekarang',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),

              // Belum punya akun
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sentiment_satisfied_alt, color: Color(0xFFE6A100)),
                        SizedBox(width: 8),
                        Text('Belum punya akun keluarga?',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Silakan daftar mandiri untuk memantau grafik KMS, jadwal imunisasi, dan asupan gizi si kecil secara real-time.',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE3E0F7),
                          foregroundColor: const Color(0xFF3B3485),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        ),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Daftar Akun Orang Tua Baru',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),

              // Jadwal terdekat
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F4EC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_available, color: _hijau),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JADWAL POSYANDU TERDEKAT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54)),
                          SizedBox(height: 4),
                          Text('Penimbangan Serentak: 15 Bulan Ini',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Bawa Buku KIA / KMS saat berkunjung',
                              style: TextStyle(fontSize: 11.5, color: _hijau)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      children: [
                        _linkFooter('Panduan\nPenggunaan'),
                        _linkFooter('Call Center\nPosyandu'),
                        _linkFooter('Kebijakan\nPrivasi'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Versi 2.4.0 (Siap Mode Luar Jaringan / Offline)',
                        style: TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkFooter(String teks) => Text(
        teks,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      );
}