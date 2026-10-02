import 'package:flutter/material.dart';
import 'auth_service.dart';

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
  final _pw = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nama.dispose();
    _nik.dispose();
    _hp.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().register(
          _nama.text.trim(), _nik.text.trim(), _hp.text.trim(), _pw.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pendaftaran berhasil, silakan masuk')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Orang Tua')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nama,
              decoration: const InputDecoration(labelText: 'Nama lengkap'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            TextFormField(
              controller: _nik,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'NIK (16 digit)'),
              validator: (v) =>
                  (v == null || v.trim().length != 16) ? 'NIK harus 16 digit' : null,
            ),
            TextFormField(
              controller: _hp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. HP'),
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? 'No. HP tidak valid' : null,
            ),
            TextFormField(
              controller: _pw,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Kata sandi (min. 6 karakter)'),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: const Text('Daftar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}