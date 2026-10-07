import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/pin_util.dart';
import 'auth_provider.dart';
import 'auth_service.dart';

/// Ubah PIN (orang tua) atau kata sandi (petugas).
class UbahSandiPage extends StatefulWidget {
  const UbahSandiPage({super.key});

  @override
  State<UbahSandiPage> createState() => _UbahSandiPageState();
}

class _UbahSandiPageState extends State<UbahSandiPage> {
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

  bool get _pin => context.read<AuthProvider>().role == 'orang_tua';

  Future<void> _simpan() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final jenis = _pin ? 'PIN' : 'Kata sandi';
      final auth = context.read<AuthProvider>();
      final messenger = ScaffoldMessenger.of(context);
      await AuthService().ubahSandi(_lama.text, _baru.text);
      await auth.restoreSession(); // memperbarui status wajib ganti sandi
      messenger.showSnackBar(SnackBar(content: Text('$jenis berhasil diubah')));
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

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    final jenis = pin ? 'PIN' : 'Kata Sandi';
    final formatter = pin ? [FilteringTextInputFormatter.digitsOnly] : <TextInputFormatter>[];

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Ubah $jenis')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _lama,
              obscureText: _hide,
              keyboardType: pin ? TextInputType.number : TextInputType.text,
              inputFormatters: formatter,
              maxLength: pin ? 6 : null,
              decoration: _dekor('$jenis lama'),
              validator: (v) => (v == null || v.isEmpty) ? '$jenis lama wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _baru,
              obscureText: _hide,
              keyboardType: pin ? TextInputType.number : TextInputType.text,
              inputFormatters: formatter,
              maxLength: pin ? 6 : null,
              decoration: _dekor('$jenis baru'),
              validator: (v) {
                if (pin) return validasiPin(v ?? '');
                return (v == null || v.length < 6) ? 'Minimal 6 karakter' : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ulang,
              obscureText: _hide,
              keyboardType: pin ? TextInputType.number : TextInputType.text,
              inputFormatters: formatter,
              maxLength: pin ? 6 : null,
              decoration: _dekor('Ulangi $jenis baru'),
              validator: (v) => v != _baru.text ? '$jenis tidak sama' : null,
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hijau,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _simpan,
                child: Text(_loading ? 'Menyimpan...' : 'Simpan $jenis baru',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}