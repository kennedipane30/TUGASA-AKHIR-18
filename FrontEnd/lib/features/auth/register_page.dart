// lib/features/auth/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/pin_util.dart';
import '../../core/utils/posyandu.dart';
import 'auth_service.dart';

const _hijau = Color(0xFF0B6B4D);
const _hijauGelap = Color(0xFF062B20);
const _hijauTerang = Color(0xFF7FE3C0);
const _teal = Color(0xFF2BB59A);
const _biru = Color(0xFF1E88D6);
const _oranye = Color(0xFFFF7A1A);
const _oranyeGelap = Color(0xFFE8590C);
const _oranyeTerang = Color(0xFFFFA31A);
const _latar = Color(0xFF0B6B4D);
const _isiField = Color(0xFFF3FBF8);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _key = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _nik = TextEditingController();
  final _hp = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();

  String? _posyandu;
  bool _hidePin = true;
  bool _hidePin2 = true;
  bool _setuju = false;
  bool _loading = false;

  @override
  void dispose() {
    _nama.dispose();
    _nik.dispose();
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
    if (!_setuju) {
      _snack('Centang pernyataan kebenaran data terlebih dahulu');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().register(
        _nama.text.trim(),
        _nik.text.trim(),
        _hp.text.trim(),
        _pin.text,
        posyandu: _posyandu ?? '',
      );
      if (!mounted) return;
      _snack('Akun berhasil dibuat. Silakan masuk, lalu lengkapi data keluarga.');
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

  InputDecoration _dekor(String hint, IconData icon,
      {Widget? suffix, String? counter}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 16.5),
      counterText: counter,
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
        child: SizedBox(
          width: double.infinity,
          child: Text(
            teks,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16.5,
              color: Colors.black87,
            ),
          ),
        ),
      );

  Widget _catatan(String teks) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          teks,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
      );

  Widget _judulBagian(int no, String judul) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _hijau,
          ),
          child: Text(
            '$no',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
          judul,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        ),
      ],
    );
  }

  Widget _pemisah() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _teal.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'LANGKAH SELANJUTNYA',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _hijau,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
      );

  // Header disamakan persis dengan halaman login
  Widget _kepala() {
    return Stack(
      children: [
        Padding(
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
        ),
        Positioned(
          top: 0,
          left: 4,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _kartu() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _biru,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Khusus Orang Tua / Wali Balita',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Daftar Akun Orang Tua',
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
              'Buat akun terlebih dahulu. Data keluarga seperti data diri, suami/ayah, dan anak dapat dilengkapi setelah masuk.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 1. Identitas akun
          _judulBagian(1, 'Identitas Akun'),
          _label('Posyandu Tempat Anak Dilayani'),
          DropdownButtonFormField<String>(
            value: _posyandu,
            isExpanded: true,
            isDense: true,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black45),
            hint: const Text(
              'Pilih posyandu',
              style: TextStyle(color: Colors.black38, fontSize: 16.5),
            ),
            decoration: _dekor('', Icons.place_outlined),
            items: itemPosyandu(),
            onChanged: (v) => setState(() => _posyandu = v),
            validator: (v) => v == null ? 'Posyandu wajib dipilih' : null,
          ),
          _catatan(
            'Pendaftaran, jadwal, dan data anak hanya berlaku di posyandu yang dipilih.',
          ),
          _label('Nama Lengkap Ibu / Wali'),
          TextFormField(
            controller: _nama,
            style: const TextStyle(fontSize: 16),
            textCapitalization: TextCapitalization.words,
            decoration: _dekor('Sesuai KTP / Kartu KIA', Icons.person_outline),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
          _label('NIK Ibu / Wali (16 Digit)'),
          TextFormField(
            controller: _nik,
            style: const TextStyle(fontSize: 16),
            keyboardType: TextInputType.number,
            maxLength: 16,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: _dekor(
              'Contoh: 3201234567890001',
              Icons.badge_outlined,
              counter: '${_nik.text.length}/16',
            ),
            validator: (v) =>
                (v == null || v.trim().length != 16) ? 'NIK harus 16 digit' : null,
          ),
          _label('Nomor WhatsApp Aktif'),
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
          _catatan(
            'Digunakan untuk masuk dan pengingat otomatis jadwal imunisasi & vitamin A',
          ),

          _pemisah(),

          // 2. Keamanan akun
          _judulBagian(2, 'Keamanan Akun'),
          _label('Buat PIN Masuk (6 Digit Angka)'),
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
              counter: '',
              suffix: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _hidePin
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black45,
                  size: 20,
                ),
                onPressed: () => setState(() => _hidePin = !_hidePin),
              ),
            ),
            validator: (v) => validasiPin(v ?? ''),
          ),
          _catatan(
            'Gunakan kombinasi angka yang mudah diingat dan sulit ditebak orang lain.',
          ),
          _label('Ulangi PIN Masuk'),
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
              counter: '',
              suffix: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _hidePin2
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black45,
                  size: 20,
                ),
                onPressed: () => setState(() => _hidePin2 = !_hidePin2),
              ),
            ),
            validator: (v) => v != _pin.text ? 'PIN tidak sama' : null,
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE0A8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _setuju,
                  activeColor: _hijau,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (v) => setState(() => _setuju = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      'Saya menyatakan dengan sadar bahwa data yang diisi adalah benar dan sah sesuai KTP / Kartu Keluarga (KK).',
                      style: TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

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
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Memproses...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Buat Akun',
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
              'Sudah memiliki akun terdaftar sebelumnya?',
              style: TextStyle(fontSize: 16.5, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'Masuk di sini',
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
                Flexible(
                  child: Text(
                    'Mendukung pencatatan luring & sinkronisasi otomatis',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: Colors.black45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Form(
            key: _key,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      _kepala(),
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