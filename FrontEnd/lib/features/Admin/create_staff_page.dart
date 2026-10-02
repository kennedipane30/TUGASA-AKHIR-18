import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class CreateStaffPage extends StatefulWidget {
  const CreateStaffPage({super.key});

  @override
  State<CreateStaffPage> createState() => _CreateStaffPageState();
}

class _CreateStaffPageState extends State<CreateStaffPage> {
  final _key = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _username = TextEditingController();
  final _pw = TextEditingController();
  String _role = 'kader';
  bool _loading = false;

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().createStaff(
        nama: _nama.text.trim(),
        username: _username.text.trim(),
        password: _pw.text,
        role: _role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Akun $_role berhasil dibuat')));
      _nama.clear();
      _username.clear();
      _pw.clear();
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
      appBar: AppBar(title: const Text('Buat Akun Kader / Bidan')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'kader', child: Text('Kader')),
                DropdownMenuItem(value: 'bidan', child: Text('Bidan')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            TextFormField(
              controller: _nama,
              decoration: const InputDecoration(labelText: 'Nama lengkap'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username (min. 4)'),
              validator: (v) =>
                  (v == null || v.trim().length < 4) ? 'Minimal 4 karakter' : null,
            ),
            TextFormField(
              controller: _pw,
              decoration:
                  const InputDecoration(labelText: 'Kata sandi awal (min. 6)'),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: const Text('Buat Akun'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}