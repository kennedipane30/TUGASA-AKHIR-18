// lib/features/auth/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/pin_util.dart';
import 'auth_service.dart';

const _hijau = Color(0xFF0B6B4D);
const _hijauGelap = Color(0xFF05503B);
const _hijauTeal = Color(0xFF0B6B7A);
const _latar = Color(0xFFF3F2FB);
const _isiField = Color(0xFFF2FBF7);
const _garisField = Color(0xFF8FD9C0);
const _oranye = Color(0xFFFF7A12);
const _oranyeGelap = Color(0xFFE85D04);

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

  OutlineInputBorder _garis(Color warna, {double lebar = 1.5}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: warna, width: lebar),
      );

  InputDecoration _dekor(String hint, IconData icon, {Widget? suffix, String? counter}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13.5),
      counterText: counter,
      prefixIcon: Icon(icon, color: _hijau.withOpacity(0.75)),
      suffixIcon: suffix,
      filled: true,
      fillColor: _isiField,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      border: _garis(_garisField),
      enabledBorder: _garis(_garisField),
      focusedBorder: _garis(_hijau, lebar: 2),
      errorBorder: _garis(Colors.red.shade300),
      focusedErrorBorder: _garis(Colors.red.shade400, lebar: 2),
    );
  }

  Widget _label(String teks, String tag, {bool oranye = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(teks,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF1F2933))),
            ),
            Text(tag,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    color: oranye ? _oranye : Colors.black45)),
          ],
        ),
      );

  Widget _judulBagian(int no, String judul, String badge) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_hijau, Color(0xFF14946B)]),
          ),
          child: Text('$no',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(judul,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: _hijauTeal)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE6EEFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badge,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF3563D6))),
        ),
      ],
    );
  }

  Widget _pemisah() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6EEFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('LANGKAH SELANJUTNYA',
                  style: TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF3563D6))),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
      );

  Widget _header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hijauGelap, _hijau],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 72),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.28)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_outlined, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Mode Offline Siap Digunakan',
                    style: TextStyle(
                        color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1FA67C), Color(0xFF0B7A58)],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 14),
          const Text('Posyandu Care',
              style: TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Aplikasi Pemantauan Tumbuh Kembang Anak & KIA Digital',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFBDEBD9), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuUtama() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text('Daftar Akun Orang Tua',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: _hijauTeal)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(colors: [_hijau, _oranye]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Buat akun terlebih dahulu. Data keluarga seperti data diri, suami/ayah, dan anak dapat dilengkapi setelah masuk.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12.5, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),

          // Info khusus orang tua
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F7B56),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Khusus Orang Tua / Wali Balita',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: Colors.white)),
                      SizedBox(height: 4),
                      Text(
                        'Akun Kader Posyandu & Tenaga Bidan dibuatkan resmi oleh Puskesmas/Admin Wilayah.',
                        style: TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 1. Identitas akun
          _judulBagian(1, 'Identitas Akun', 'Wajib Diisi'),
          _label('Nama Lengkap Ibu / Wali', 'Wajib'),
          TextFormField(
            controller: _nama,
            textCapitalization: TextCapitalization.words,
            decoration: _dekor('Sesuai KTP / Kartu KIA', Icons.person_outline),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
          ),
          _label('NIK Ibu / Wali (16 Digit)', 'Wajib'),
          TextFormField(
            controller: _nik,
            keyboardType: TextInputType.number,
            maxLength: 16,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: _dekor('Contoh: 3201234567890001', Icons.badge_outlined,
                counter: '${_nik.text.length}/16'),
            validator: (v) =>
                (v == null || v.trim().length != 16) ? 'NIK harus 16 digit' : null,
          ),
          _label('Nomor WhatsApp Aktif', 'Wajib'),
          TextFormField(
            controller: _hp,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dekor('Contoh: 081234567890', Icons.phone_outlined),
            validator: (v) =>
                (v == null || v.trim().length < 10) ? 'No. WhatsApp tidak valid' : null,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Digunakan untuk masuk dan pengingat otomatis jadwal imunisasi & vitamin A',
              style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
            ),
          ),

          _pemisah(),

          // 2. Keamanan akun
          _judulBagian(2, 'Keamanan Akun', 'PIN 6 Digit'),
          _label('Buat PIN Masuk (6 Digit Angka)', 'Enkripsi Lokal', oranye: false),
          TextFormField(
            controller: _pin,
            obscureText: _hidePin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dekor(
              'Ketik 6 angka rahasia',
              Icons.lock_outline,
              counter: '',
              suffix: IconButton(
                icon: Icon(
                  _hidePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _hijau,
                ),
                onPressed: () => setState(() => _hidePin = !_hidePin),
              ),
            ),
            validator: (v) => validasiPin(v ?? ''),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Gunakan kombinasi angka yang mudah diingat dan sulit ditebak orang lain.',
              style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
            ),
          ),
          _label('Ulangi PIN Masuk', 'Wajib'),
          TextFormField(
            controller: _pin2,
            obscureText: _hidePin2,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dekor(
              'Masukkan ulang 6 angka',
              Icons.lock_reset,
              counter: '',
              suffix: IconButton(
                icon: Icon(
                  _hidePin2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _hijau,
                ),
                onPressed: () => setState(() => _hidePin2 = !_hidePin2),
              ),
            ),
            validator: (v) => v != _pin.text ? 'PIN tidak sama' : null,
          ),
          const SizedBox(height: 16),

          // Pernyataan
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  onChanged: (v) => setState(() => _setuju = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      'Saya menyatakan dengan sadar bahwa data yang diisi adalah benar dan sah sesuai KTP / Kartu Keluarga (KK).',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tombol
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: _loading
                    ? [Colors.orange.shade200, Colors.orange.shade300]
                    : const [_oranye, _oranyeGelap],
              ),
              boxShadow: _loading
                  ? null
                  : const [
                      BoxShadow(
                          color: Color(0x55FF7A12), blurRadius: 14, offset: Offset(0, 6)),
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
                                  strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Text('Memproses...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Buat Akun',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: Colors.white, size: 19),
                          ],
                        ),
                ),
              ),
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
      body: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _header(),
              Transform.translate(
                offset: const Offset(0, -40),
                child: _kartuUtama(),
              ),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Sudah memiliki akun terdaftar sebelumnya? ',
                          style: TextStyle(fontSize: 12.5)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text('Masuk di sini',
                            style: TextStyle(
                                color: _oranye,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}