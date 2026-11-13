import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'jadwal_page.dart';

// ---------------------------------------------------------------------------
// HALAMAN EDIT JADWAL (halaman penuh)
// ---------------------------------------------------------------------------
class AdminEditJadwalPage extends StatefulWidget {
  final JadwalItem jadwal;
  const AdminEditJadwalPage({super.key, required this.jadwal});

  @override
  State<AdminEditJadwalPage> createState() => _AdminEditJadwalPageState();
}

class _AdminEditJadwalPageState extends State<AdminEditJadwalPage> {
  final _key = GlobalKey<FormState>();
  final _tgl = TextEditingController();
  final _mulai = TextEditingController();
  final _selesai = TextEditingController();
  final _lokasi = TextEditingController();
  DateTime? _tanggal;
  bool _menyimpan = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.jadwal;
    _tanggal = a.tanggal;
    _tgl.text = tglPanjangJadwal(a.tanggal);
    _mulai.text = a.jamMulai;
    _selesai.text = a.jamSelesai;
    _lokasi.text = a.lokasi;
  }

  @override
  void dispose() {
    _tgl.dispose();
    _mulai.dispose();
    _selesai.dispose();
    _lokasi.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final now = DateTime.now();
    final awal = _tanggal ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: awal.isBefore(now) ? now : awal,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) {
      setState(() {
        _tanggal = d;
        _tgl.text = tglPanjangJadwal(d);
      });
    }
  }

  Future<void> _pilihJam(TextEditingController c) async {
    final t = await showTimePicker(
      context: context,
      initialTime: parseJamJadwal(c.text) ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => c.text = fmtJamJadwal(t));
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (!_key.currentState!.validate()) return;

    setState(() {
      _menyimpan = true;
      _error = null;
    });

    // Posyandu tidak dikirim: backend memakai posyandu akun sekretaris.
    final body = {
      'tanggal': fmtApiJadwal(_tanggal!),
      'jam_mulai': _mulai.text.trim(),
      'jam_selesai': _selesai.text.trim(),
      'lokasi': _lokasi.text.trim(),
    };

    try {
      await ApiClient.dio
          .put('/sekretaris/jadwal/${widget.jadwal.id}', data: body, options: opsiJadwal);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _error = pesanErrorJadwal(e);
      });
    }
  }

  Widget _label(String teks) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(teks,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: teksGelapJadwal)),
      );

  InputDecoration _dekorForm(String hint) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 16, color: Colors.black38),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: b(const Color(0xFFD7E6DD), 1.2),
      enabledBorder: b(const Color(0xFFD7E6DD), 1.2),
      focusedBorder: b(hijauTombolJadwal, 1.6),
      errorBorder: b(AppColors.merah, 1.2),
      focusedErrorBorder: b(AppColors.merah, 1.6),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      color: warnaHeaderJadwal,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: judulHeaderJadwal('Edit Jadwal'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE6ECE8))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: hijauTombolJadwal,
                      side: const BorderSide(color: hijauTombolJadwal, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _menyimpan ? null : () => Navigator.pop(context),
                    child: const Text('Batal',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hijauTombolJadwal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _menyimpan ? null : _simpan,
                    child: Text(
                      _menyimpan ? 'Menyimpan...' : 'Simpan Perubahan',
                      maxLines: 1,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Form(
                key: _key,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE6ECE8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Tanggal Pelaksanaan'),
                          TextFormField(
                            controller: _tgl,
                            readOnly: true,
                            onTap: _pilihTanggal,
                            decoration: _dekorForm('Pilih tanggal'),
                            validator: (v) =>
                                _tanggal == null ? 'Tanggal wajib dipilih' : null,
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Jam Mulai'),
                                    TextFormField(
                                      controller: _mulai,
                                      readOnly: true,
                                      onTap: () => _pilihJam(_mulai),
                                      decoration: _dekorForm('08:00'),
                                      validator: (v) =>
                                          (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Jam Selesai'),
                                    TextFormField(
                                      controller: _selesai,
                                      readOnly: true,
                                      onTap: () => _pilihJam(_selesai),
                                      decoration: _dekorForm('11:30'),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return null;
                                        if (v.compareTo(_mulai.text) <= 0) {
                                          return 'Harus setelah jam mulai';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _label('Lokasi'),
                          TextFormField(
                            controller: _lokasi,
                            textCapitalization: TextCapitalization.words,
                            decoration: _dekorForm('Contoh: Balai Desa'),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.merah, fontSize: 16)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}