import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';

const _hijau = Color(0xFF0B6B4D);
const _latar = Color(0xFFF3F2FB);
const _isiField = Color(0xFFEDEBF7);

// Daftar sementara. Ganti dengan data dari API jika endpoint posyandu sudah dibuat.
const _daftarPosyandu = <String>[
  'Posyandu Melati 1',
  'Posyandu Melati 2',
  'Posyandu Mawar',
];

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _key = GlobalKey<FormState>();
  final _nik = TextEditingController();
  final _nama = TextEditingController();
  final _hp = TextEditingController();
  final _namaBalita = TextEditingController();
  final _tglLahir = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();

  String? _wilayah;
  String? _jk; // 'L' atau 'P'
  bool _hidePin = true;
  bool _hidePin2 = true;
  bool _setuju = false;
  bool _loading = false;

  @override
  void dispose() {
    _nik.dispose();
    _nama.dispose();
    _hp.dispose();
    _namaBalita.dispose();
    _tglLahir.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pilihTanggal() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
    );
    if (d != null) {
      _tglLahir.text =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    if (!_setuju) {
      _snack('Centang pernyataan kebenaran data terlebih dahulu');
      return;
    }
    setState(() => _loading = true);
    try {
      // Backend saat ini menyimpan: nama, NIK, No. HP, dan kata sandi (PIN).
      await AuthService().register(
        _nama.text.trim(),
        _nik.text.trim(),
        _hp.text.trim(),
        _pin.text,
      );
      if (!mounted) return;
      _snack('Pendaftaran berhasil, silakan masuk');
      Navigator.pop(context);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dekor(String hint, IconData icon,
      {Widget? suffix, String? counter}) {
    return InputDecoration(
      hintText: hint,
      counterText: counter,
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

  Widget _label(String teks, {bool wajib = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 12),
        child: Text.rich(
          TextSpan(
            text: teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            children: [
              if (wajib)
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );

  Widget _kartu({required Widget child, Color warna = Colors.white}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: warna,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );

  Widget _judulBagian(int no, String judul, String badge, Color warnaBadge) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFE3F4EC),
          child: Text('$no',
              style: const TextStyle(
                  color: _hijau, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(judul,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: warnaBadge,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badge,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _hijau)),
        ),
      ],
    );
  }

  Widget _pilihJk(String kode, String teks, IconData icon) {
    final aktif = _jk == kode;
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: aktif ? const Color(0xFFE3F4EC) : _isiField,
          side: BorderSide(color: aktif ? _hijau : Colors.transparent),
          foregroundColor: aktif ? _hijau : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => setState(() => _jk = kode),
        icon: Icon(icon, size: 18),
        label: Text(teks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _latar,
      body: SafeArea(
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _hijau,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.child_care, color: Colors.white, size: 20),
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

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('PORTAL MANDIRI BALITA',
                      style: TextStyle(
                          color: _hijau, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Daftar Akun Orang Tua',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Text(
                    'Pendaftaran mandiri khusus keluarga balita untuk memantau KMS & imunisasi rutin secara berkala.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),

                // Info
                _kartu(
                  warna: const Color(0xFFE3F4EC),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user, color: _hijau),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Khusus Orang Tua / Wali Balita',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            SizedBox(height: 4),
                            Text(
                              'Pendaftaran mandiri ini hanya diperuntukkan bagi Orang Tua/Wali. Untuk akun Kader Posyandu & Tenaga Bidan dibuatkan resmi oleh Puskesmas/Admin Wilayah.',
                              style: TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 1. Identitas
                _kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _judulBagian(1, 'Identitas Orang Tua / Wali', 'Wajib Diisi',
                          const Color(0xFFE3F4EC)),
                      _label('NIK Ibu / Wali (16 Digit)', wajib: true),
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
                      _label('Nama Lengkap Ibu / Wali', wajib: true),
                      TextFormField(
                        controller: _nama,
                        textCapitalization: TextCapitalization.words,
                        decoration: _dekor('Sesuai KTP / Kartu KIA (Contoh: Siti Rahmawati)',
                            Icons.person_outline),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                      ),
                      _label('Nomor WhatsApp Aktif', wajib: true),
                      TextFormField(
                        controller: _hp,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration:
                            _dekor('Contoh: 081234567890', Icons.phone_outlined),
                        validator: (v) => (v == null || v.trim().length < 10)
                            ? 'No. WhatsApp tidak valid'
                            : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Digunakan untuk pengingat otomatis jadwal imunisasi & vitamin A',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                      _label('Wilayah Domisili (Pilih Posyandu Terdekat)', wajib: true),
                      DropdownButtonFormField<String>(
                        value: _wilayah,
                        isExpanded: true,
                        decoration: _dekor(
                            '-- Pilih unit Posyandu di lingkungan', Icons.location_on_outlined),
                        items: _daftarPosyandu
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _wilayah = v),
                      ),
                    ],
                  ),
                ),

                // 2. Data balita
                _kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _judulBagian(2, 'Data Balita Pertama', 'Dapat Dilengkapi Nanti',
                          const Color(0xFFFFF1CC)),
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Bisa Anda lewati terlebih dahulu bila Buku KIA anak sedang tidak di dekat Anda.',
                          style: TextStyle(fontSize: 12.5, color: Colors.black54),
                        ),
                      ),
                      _label('Nama Lengkap Balita'),
                      TextFormField(
                        controller: _namaBalita,
                        textCapitalization: TextCapitalization.words,
                        decoration: _dekor('Contoh: Muhammad Rayhan', Icons.child_care),
                      ),
                      _label('Tanggal Lahir Anak'),
                      TextFormField(
                        controller: _tglLahir,
                        readOnly: true,
                        onTap: _pilihTanggal,
                        decoration: _dekor('dd/mm/yyyy', Icons.calendar_today_outlined),
                      ),
                      _label('Jenis Kelamin'),
                      Row(
                        children: [
                          _pilihJk('L', 'Laki-laki', Icons.male),
                          const SizedBox(width: 10),
                          _pilihJk('P', 'Perempuan', Icons.female),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Keamanan akun
                _kartu(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _judulBagian(3, 'Keamanan Akun Keluarga', 'PIN 6 Digit',
                          const Color(0xFFE3F4EC)),
                      _label('Buat PIN Masuk (6 Digit Angka)', wajib: true),
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
                            icon: Icon(_hidePin
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hidePin = !_hidePin),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.length != 6) ? 'PIN harus 6 digit angka' : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'Gunakan kombinasi angka yang mudah diingat dan sulit ditebak orang lain.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                      _label('Ulangi PIN Masuk', wajib: true),
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
                            icon: Icon(_hidePin2
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hidePin2 = !_hidePin2),
                          ),
                        ),
                        validator: (v) => v != _pin.text ? 'PIN tidak sama' : null,
                      ),
                    ],
                  ),
                ),

                // Pernyataan
                _kartu(
                  warna: const Color(0xFFFFF7E6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _setuju,
                        activeColor: _hijau,
                        onChanged: (v) => setState(() => _setuju = v ?? false),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Saya menyatakan dengan sadar bahwa data yang diisi adalah benar dan sah sesuai Kartu Keluarga (KK) serta Buku KIA fisik balita kami.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol daftar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hijau,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.person_add_alt_1),
                      label: Text(_loading ? 'Memproses...' : 'Daftar Sekarang',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Sudah memiliki akun terdaftar sebelumnya? ',
                            style: TextStyle(fontSize: 12.5)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Masuk di sini',
                              style: TextStyle(
                                  color: _hijau,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}