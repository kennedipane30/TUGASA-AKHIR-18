import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/pin_util.dart';
import 'auth_provider.dart';
import 'auth_service.dart';

/// Ubah PIN masuk (semua role).
/// [wajib] true bila dibuka otomatis karena PIN dibuat/direset petugas.
class UbahPinPage extends StatefulWidget {
  final bool wajib;
  const UbahPinPage({super.key, this.wajib = false});

  @override
  State<UbahPinPage> createState() => _UbahPinPageState();
}

class _UbahPinPageState extends State<UbahPinPage> {
  final _key = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool _hide = true;
  bool _loading = false;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final messenger = ScaffoldMessenger.of(context);
      await AuthService().ubahPin(_lama.text, _baru.text);
      await auth.restoreSession(); // memperbarui status wajib ganti PIN
      messenger.showSnackBar(const SnackBar(content: Text('PIN berhasil diubah')));
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dekor(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16.5),
        counterText: '',
        filled: true,
        fillColor: AppColors.isiField,
        suffixIcon: IconButton(
          icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hide = !_hide),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  TextFormField _isian(TextEditingController c, String label, String? Function(String?) cek) {
    return TextFormField(
      controller: c,
      style: const TextStyle(fontSize: 16.5, letterSpacing: 4),
      obscureText: _hide,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 6,
      decoration: _dekor(label),
      validator: cek,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: !widget.wajib,
        title: const Text('Ubah PIN', style: TextStyle(fontSize: 19)),
        actions: [
          if (widget.wajib)
            TextButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              child: const Text('Keluar'),
            ),
        ],
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.wajib)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.kuningMuda,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PIN Anda dibuat oleh petugas. Demi keamanan, buat PIN baru sebelum melanjutkan.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            _isian(_lama, widget.wajib ? 'PIN dari petugas' : 'PIN lama',
                (v) => (v == null || v.isEmpty) ? 'PIN lama wajib diisi' : null),
            const SizedBox(height: 14),
            _isian(_baru, 'PIN baru', (v) {
              final pesan = validasiPin(v ?? '');
              if (pesan != null) return pesan;
              return v == _lama.text ? 'PIN baru harus berbeda dari PIN lama' : null;
            }),
            const SizedBox(height: 14),
            _isian(_ulang, 'Ulangi PIN baru',
                (v) => v != _baru.text ? 'PIN tidak sama' : null),
            const SizedBox(height: 6),
            const Text(
              'PIN 6 digit angka, tidak boleh kembar (111111), berurutan (123456), atau berulang (121212).',
              style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup, height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hijau,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _simpan,
                child: Text(_loading ? 'Menyimpan...' : 'Simpan PIN baru',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}