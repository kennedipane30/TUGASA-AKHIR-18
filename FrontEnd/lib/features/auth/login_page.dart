import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'register_page.dart';

const _hijau = Color(0xFF0B6B4D);
const _hijauGelap = Color(0xFF062B20);
const _hijauTerang = Color(0xFF7FE3C0);
const _teal = Color(0xFF2BB59A);
const _oranye = Color(0xFFFF7A1A);
const _oranyeGelap = Color(0xFFE8590C);
const _oranyeTerang = Color(0xFFFFA31A);
const _latar = Color(0xFF0B6B4D);
const _isiField = Color(0xFFF3FBF8);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idf = TextEditingController();
  final _pin = TextEditingController();

  bool _hide = true;
  bool _ingat = true;

  @override
  void dispose() {
    _idf.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _submit() async {
    if (_idf.text.trim().isEmpty) {
      _snack('No. HP atau username wajib diisi');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_pin.text)) {
      _snack('PIN harus 6 digit angka');
      return;
    }

    try {
      await context
          .read<AuthProvider>()
          .login(_idf.text.trim(), _pin.text);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  InputDecoration _dekor(String hint, {required IconData ikon, Widget? suffix}) {
    OutlineInputBorder garis(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      isDense: true,
      counterText: '',
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black38,
        fontSize: 16.5,
      ),
      prefixIcon: Icon(ikon, color: Colors.black45, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      filled: true,
      fillColor: _isiField,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      border: garis(_teal.withOpacity(0.55), 1.4),
      enabledBorder: garis(_teal.withOpacity(0.55), 1.4),
      focusedBorder: garis(_teal, 1.8),
    );
  }

  Widget _label(String teks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          teks,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16.5,
          ),
        ),
      ),
    );
  }

  Widget _kepala() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          Image.asset(
            'logo.png',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 150,
              height: 150,
              child: Icon(
                Icons.monitor_heart_outlined,
                color: Colors.white,
                size: 100,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -14),
            child: const Text(
              'Posyandu Care',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: const Text(
              'Pantau kesehatan anak dan gizi buah hati secara berkala tanpa batas koneksi',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _hijauTerang,
                fontSize: 16.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _kartu(bool loading) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Masuk ke Akun Anda',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_teal, _oranye]),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _label('No. HP atau Username'),
          TextField(
            controller: _idf,
            style: const TextStyle(fontSize: 16),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: _dekor(
              'Contoh: 081234567890 atau kennedi',
              ikon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 14),
          _label('PIN (6 Digit Angka)'),
          TextField(
            controller: _pin,
            style: const TextStyle(fontSize: 16, letterSpacing: 4),
            obscureText: _hide,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => loading ? null : _submit(),
            decoration: _dekor(
              '••••••',
              ikon: Icons.pin_outlined,
              suffix: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _hide
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black45,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _hide = !_hide);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Checkbox(
                  value: _ingat,
                  activeColor: _hijau,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) {
                    setState(() => _ingat = v ?? false);
                  },
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ingat akun',
                style: TextStyle(fontSize: 16),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _snack(
                  'Hubungi sekretaris posyandu desa Anda untuk reset PIN',
                ),
                child: const Text(
                  'Lupa PIN?',
                  style: TextStyle(
                    color: _oranye,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: loading ? 0.7 : 1,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_oranyeGelap, _oranye, _oranyeTerang],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _oranye.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Masuk Sekarang',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Belum memiliki akun Posyandu?',
              style: TextStyle(
                fontSize: 16.5,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisterPage(),
                ),
              ),
              child: const Text(
                'Daftar Akun Baru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: _teal),
                SizedBox(width: 6),
                Text(
                  'Mendukung pencatatan luring & sinkronisasi otomatis',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;

    return Scaffold(
      backgroundColor: _latar,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_hijauGelap, _hijau],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    _kepala(),
                    Expanded(child: _kartu(loading)),
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