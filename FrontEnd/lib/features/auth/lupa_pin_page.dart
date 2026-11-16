// lib/features/auth/lupa_pin_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/pin_util.dart';
import 'otp_page.dart';
import 'otp_service.dart';

const _hijau = Color(0xFF0B6B4D);
const _hijauGelap = Color(0xFF062B20);
const _hijauTerang = Color(0xFF7FE3C0);
const _teal = Color(0xFF2BB59A);
const _oranye = Color(0xFFFF7A1A);
const _oranyeGelap = Color(0xFFE8590C);
const _oranyeTerang = Color(0xFFFFA31A);
const _isiField = Color(0xFFF3FBF8);

/// Lupa PIN: pemilik akun mengatur PIN baru sendiri lewat kode OTP WhatsApp.
///
/// Alur: isi No. WhatsApp + PIN baru -> kode dikirim -> OtpPage -> PIN disimpan.
class LupaPinPage extends StatefulWidget {
  /// Opsional: No. HP yang sudah diketik di halaman login.
  final String? noHpAwal;

  const LupaPinPage({super.key, this.noHpAwal});

  @override
  State<LupaPinPage> createState() => _LupaPinPageState();
}

class _LupaPinPageState extends State<LupaPinPage> {
  final _key = GlobalKey<FormState>();
  final _svc = OtpService();
  late final TextEditingController _hp;
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();

  bool _hidePin = true;
  bool _hidePin2 = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final awal = widget.noHpAwal ?? '';
    // isi otomatis hanya bila yang diketik di login berupa No. HP (bukan username/NIK)
    _hp = TextEditingController(
      text: RegExp(r'^(08|62)\d{8,12}$').hasMatch(awal) ? awal : '',
    );
  }

  @override
  void dispose() {
    _hp.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final hp = _hp.text.trim();

    setState(() => _loading = true);
    try {
      // 1. kirim kode ke WhatsApp
      final info = await _svc.kirim(hp, TujuanOtp.resetPin);
      if (!mounted) return;

      // 2. pengguna memasukkan kode di halaman OTP
      final token = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpPage(noHp: hp, tujuan: TujuanOtp.resetPin, info: info),
        ),
      );
      if (token == null || !mounted) return; // kembali tanpa verifikasi

      // 3. simpan PIN baru
      await _svc.lupaPin(noHp: hp, pinBaru: _pin.text, tokenOtp: token);
      if (!mounted) return;
      _snack('PIN berhasil diatur ulang. Silakan masuk dengan PIN baru.');
      Navigator.pop(context);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  OutlineInputBorder _garis(Color warna, {double lebar = 1.4}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: warna, width: lebar),
      );

  InputDecoration _dekor(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 16.5),
      counterText: '',
      prefixIcon: Icon(icon, color: Colors.black45, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      filled: true,
      fillColor: _isiField,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: _garis(_teal.withValues(alpha: 0.55)),
      enabledBorder: _garis(_teal.withValues(alpha: 0.55)),
      focusedBorder: _garis(_teal, lebar: 1.8),
      errorBorder: _garis(Colors.red.shade300),
      focusedErrorBorder: _garis(Colors.red.shade400, lebar: 1.8),
    );
  }

  Widget _label(String teks) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: Text(
          teks,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16.5,
            color: Colors.black87,
          ),
        ),
      );

  Widget _matakan(bool tersembunyi, VoidCallback ubah) => IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          tersembunyi ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.black45,
          size: 20,
        ),
        onPressed: ubah,
      );

  Widget _kartu() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Atur Ulang PIN',
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
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Kami akan mengirim kode verifikasi ke nomor WhatsApp yang terdaftar di akun Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 16, height: 1.45),
            ),
          ),
          const SizedBox(height: 8),
          _label('Nomor WhatsApp Terdaftar'),
          TextFormField(
            controller: _hp,
            style: const TextStyle(fontSize: 16),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dekor('Contoh: 081234567890', Icons.phone_outlined),
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'No. WhatsApp tidak valid'
                : null,
          ),
          _label('PIN Baru (6 Digit Angka)'),
          TextFormField(
            controller: _pin,
            style: const TextStyle(fontSize: 16),
            obscureText: _hidePin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dekor(
              'Ketik 6 angka rahasia',
              Icons.lock_outline,
              suffix: _matakan(_hidePin, () => setState(() => _hidePin = !_hidePin)),
            ),
            validator: (v) => validasiPin(v ?? ''),
          ),
          _label('Ulangi PIN Baru'),
          TextFormField(
            controller: _pin2,
            style: const TextStyle(fontSize: 16),
            obscureText: _hidePin2,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dekor(
              'Masukkan ulang 6 angka',
              Icons.lock_reset,
              suffix: _matakan(_hidePin2, () => setState(() => _hidePin2 = !_hidePin2)),
            ),
            validator: (v) => v != _pin.text ? 'PIN tidak sama' : null,
          ),
          const SizedBox(height: 24),
          Opacity(
            opacity: _loading ? 0.7 : 1,
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
                    color: _oranye.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _loading ? null : _submit,
                  child: Center(
                    child: _loading
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
                              Icon(Icons.chat_outlined, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Kirim Kode via WhatsApp',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
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
              'Nomor WhatsApp sudah tidak aktif? Hubungi sekretaris posyandu desa Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _hijau,
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
          child: Form(
            key: _key,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Icon(Icons.lock_reset, color: Colors.white, size: 72),
                      const SizedBox(height: 10),
                      const Text(
                        'Lupa PIN?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Buat PIN baru tanpa harus datang ke posyandu',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _hijauTerang, fontSize: 16.5),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(child: _kartu()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}