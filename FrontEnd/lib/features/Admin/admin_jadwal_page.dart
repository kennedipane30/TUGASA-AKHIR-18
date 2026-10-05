import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class JadwalItem {
  final String id;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String lokasi;
  final String status; // terjadwal | dibatalkan | ...
  final String alasanBatal;

  JadwalItem({
    required this.id,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.lokasi,
    required this.status,
    required this.alasanBatal,
  });

  factory JadwalItem.fromApi(Map<String, dynamic> j) {
    final t = j['tanggal']?.toString() ?? '';
    final tgl = t.length >= 10 ? DateTime.tryParse(t.substring(0, 10)) : null;
    String jam(dynamic v) {
      final s = v?.toString() ?? '';
      return s.length >= 5 ? s.substring(0, 5) : s;
    }

    return JadwalItem(
      id: j['id']?.toString() ?? '',
      tanggal: tgl ?? DateTime.now(),
      jamMulai: jam(j['jam_mulai']),
      jamSelesai: jam(j['jam_selesai']),
      lokasi: j['lokasi']?.toString() ?? '',
      status: j['status']?.toString() ?? 'terjadwal',
      alasanBatal: j['alasan_batal']?.toString() ?? '',
    );
  }

  bool get aktif => status == 'terjadwal';
}

// ---------------------------------------------------------------------------
// HELPER
// ---------------------------------------------------------------------------
final Options _opsi = Options(receiveTimeout: const Duration(seconds: 15));

String _pesanError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server tidak merespons. Periksa koneksi dan alamat server.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server.';
      default:
        return 'Terjadi kesalahan (kode ${e.response?.statusCode ?? '-'}).';
    }
  }
  return 'Terjadi kesalahan: $e';
}

List<dynamic> _ambilList(dynamic d) {
  if (d is List) return d;
  if (d is Map) {
    for (final k in ['data', 'jadwal', 'items']) {
      if (d[k] is List) return d[k] as List;
    }
  }
  return [];
}

String _fmtApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtJam(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseJam(String s) {
  final p = s.split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

const _namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _namaBulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String _tglPanjang(DateTime d) =>
    '${_namaHari[d.weekday - 1]}, ${d.day} ${_namaBulan[d.month - 1]} ${d.year}';

InputDecoration _dekor(String label, {String? hint, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, color: Colors.grey.shade600),
    filled: true,
    fillColor: AppColors.isiField,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

// ---------------------------------------------------------------------------
// HALAMAN KELOLA JADWAL (ADMIN)
// ---------------------------------------------------------------------------
class AdminJadwalPage extends StatefulWidget {
  const AdminJadwalPage({super.key});

  @override
  State<AdminJadwalPage> createState() => _AdminJadwalPageState();
}

class _AdminJadwalPageState extends State<AdminJadwalPage> {
  List<JadwalItem> _daftar = [];
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final r = await ApiClient.dio.get('/jadwal', options: _opsi);
      final list = _ambilList(r.data)
          .map((e) => JadwalItem.fromApi(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        _daftar = list;
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesanError(e);
        _memuat = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _form({JadwalItem? awal}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FormJadwal(awal: awal),
    );
    if (ok == true) {
      _snack(awal == null ? 'Jadwal berhasil dibuat' : 'Jadwal berhasil diubah');
      _muat();
    }
  }

  Future<void> _batalkan(JadwalItem j) async {
    final c = TextEditingController();
    final alasan = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan jadwal?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tglPanjang(j.tanggal), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              maxLines: 2,
              decoration: _dekor('Alasan pembatalan'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kembali')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.merah, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Batalkan Jadwal'),
          ),
        ],
      ),
    );
    c.dispose();
    if (alasan == null) return;
    if (alasan.isEmpty) {
      _snack('Alasan pembatalan wajib diisi');
      return;
    }
    try {
      await ApiClient.dio
          .post('/admin/jadwal/${j.id}/batalkan', data: {'alasan': alasan}, options: _opsi);
      _snack('Jadwal dibatalkan');
      _muat();
    } catch (e) {
      _snack(_pesanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final aktif = _daftar.where((j) => j.aktif).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    final riwayat = _daftar.where((j) => !j.aktif).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Jadwal & Agenda',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hijau,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _form(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Jadwal Posyandu',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SectionCard(
              color: AppColors.hijauMuda,
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.hijau),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pendaftaran orang tua dibuka 7 hari sebelum pelaksanaan dan check-in dibuka 1 jam sebelum mulai. Hanya satu jadwal per tanggal.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (_memuat)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_gagal != null)
              SectionCard(
                color: AppColors.kuningMuda,
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: AppColors.kuning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_gagal!,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _memuat = true);
                        _muat();
                      },
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else ...[
              SectionCard(
                title: 'Jadwal Mendatang',
                icon: Icons.event,
                trailing: Pill('${aktif.length} jadwal',
                    bg: AppColors.hijauMuda, fg: AppColors.hijau),
                child: aktif.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Belum ada jadwal. Tekan "Tambah Jadwal Posyandu" untuk membuat jadwal baru.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                        ),
                      )
                    : Column(children: [for (final j in aktif) _kartu(j)]),
              ),
              if (riwayat.isNotEmpty)
                SectionCard(
                  title: 'Riwayat & Dibatalkan',
                  icon: Icons.history,
                  child: Column(children: [for (final j in riwayat) _kartu(j)]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kartu(JadwalItem j) {
    final batal = j.status == 'dibatalkan';
    final jam = j.jamSelesai.isEmpty ? j.jamMulai : '${j.jamMulai} - ${j.jamSelesai}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: batal ? AppColors.merahMuda : AppColors.hijauMuda,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(batal ? Icons.event_busy : Icons.event_available,
                    color: batal ? AppColors.merah : AppColors.hijau, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_tglPanjang(j.tanggal),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text('$jam WIB',
                        style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              batal
                  ? const Pill('Dibatalkan', bg: AppColors.merahMuda, fg: AppColors.merah)
                  : Pill(j.status == 'terjadwal' ? 'Terjadwal' : j.status,
                      bg: AppColors.hijauMuda, fg: AppColors.hijau),
            ],
          ),
          if (j.lokasi.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 16, color: AppColors.teksRedup),
                const SizedBox(width: 4),
                Expanded(child: Text(j.lokasi, style: const TextStyle(fontSize: 12))),
              ],
            ),
          ],
          if (batal && j.alasanBatal.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Alasan: ${j.alasanBatal}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.merah)),
          ],
          if (j.aktif) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton('Ubah',
                      icon: Icons.edit_outlined,
                      filled: false,
                      onPressed: () => _form(awal: j)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton('Batalkan',
                      icon: Icons.close,
                      filled: false,
                      color: AppColors.merah,
                      onPressed: () => _batalkan(j)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORM TAMBAH / UBAH JADWAL (bottom sheet)
// ---------------------------------------------------------------------------
class _FormJadwal extends StatefulWidget {
  final JadwalItem? awal;
  const _FormJadwal({this.awal});

  @override
  State<_FormJadwal> createState() => _FormJadwalState();
}

class _FormJadwalState extends State<_FormJadwal> {
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
    final a = widget.awal;
    if (a != null) {
      _tanggal = a.tanggal;
      _tgl.text = _tglPanjang(a.tanggal);
      _mulai.text = a.jamMulai;
      _selesai.text = a.jamSelesai;
      _lokasi.text = a.lokasi;
    } else {
      _mulai.text = '08:00';
      _selesai.text = '11:30';
    }
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
      firstDate: widget.awal == null ? DateTime(now.year, now.month, now.day) : DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) {
      setState(() {
        _tanggal = d;
        _tgl.text = _tglPanjang(d);
      });
    }
  }

  Future<void> _pilihJam(TextEditingController c) async {
    final t = await showTimePicker(
      context: context,
      initialTime: _parseJam(c.text) ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => c.text = _fmtJam(t));
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (!_key.currentState!.validate()) return;

    setState(() {
      _menyimpan = true;
      _error = null;
    });

    final body = {
      'tanggal': _fmtApi(_tanggal!),
      'jam_mulai': _mulai.text.trim(),
      'jam_selesai': _selesai.text.trim(),
      'lokasi': _lokasi.text.trim(),
    };

    try {
      if (widget.awal == null) {
        await ApiClient.dio.post('/admin/jadwal', data: body, options: _opsi);
      } else {
        await ApiClient.dio.put('/admin/jadwal/${widget.awal!.id}', data: body, options: _opsi);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _error = _pesanError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.awal == null ? 'Tambah Jadwal Posyandu' : 'Ubah Jadwal Posyandu',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _tgl,
                readOnly: true,
                onTap: _pilihTanggal,
                decoration: _dekor('Tanggal pelaksanaan',
                    hint: 'Pilih tanggal', icon: Icons.calendar_today_outlined),
                validator: (v) => _tanggal == null ? 'Tanggal wajib dipilih' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mulai,
                      readOnly: true,
                      onTap: () => _pilihJam(_mulai),
                      decoration: _dekor('Jam mulai', icon: Icons.schedule),
                      validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _selesai,
                      readOnly: true,
                      onTap: () => _pilihJam(_selesai),
                      decoration: _dekor('Jam selesai', icon: Icons.schedule),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (v.compareTo(_mulai.text) <= 0) return 'Harus setelah jam mulai';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lokasi,
                textCapitalization: TextCapitalization.words,
                decoration: _dekor('Lokasi', hint: 'Contoh: Balai Warga RW 05',
                    icon: Icons.place_outlined),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.kuningMuda,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Pendaftaran dibuka 7 hari sebelumnya dan check-in 1 jam sebelumnya. Orang tua, kader, dan bidan akan menerima notifikasi.',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.merah, fontSize: 12.5)),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton('Batal',
                        filled: false, onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(_menyimpan ? 'Menyimpan...' : 'Simpan',
                        icon: Icons.check, onPressed: _menyimpan ? () {} : _simpan),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}