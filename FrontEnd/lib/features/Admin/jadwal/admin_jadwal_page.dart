import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class JadwalItem {
  final String id;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String lokasi;
  final String status;
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

  /// Jadwal yang sudah lewat (tanggal sebelum hari ini) dianggap selesai.
  bool get selesai {
    final n = DateTime.now();
    final hari = DateTime(n.year, n.month, n.day);
    return status == 'selesai' || (aktif && tanggal.isBefore(hari));
  }
}

// ---------------------------------------------------------------------------
// HELPER
// ---------------------------------------------------------------------------
final Options _opsi = Options(receiveTimeout: const Duration(seconds: 15));

const _hijauTua = Color(0xFF0B3D2E);
const _hijauGelap = Color(0xFF14634A);
const _oranye = Color(0xFFEA580C);
const _biru = Color(0xFF2B7BB9);

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
const _namaHariSingkat = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _namaBulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String _tglPanjang(DateTime d) =>
    '${_namaHari[d.weekday - 1]}, ${d.day} ${_namaBulan[d.month - 1]} ${d.year}';

String _tglRiwayat(DateTime d) =>
    '${_namaHariSingkat[d.weekday - 1].substring(0, 5)}, ${d.day} ${_namaBulan[d.month - 1]} ${d.year}';

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
  bool _semuaRiwayat = false;
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
          .where((j) => j.status != 'dibatalkan')
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
    final alasan = await showDialog<String>(
      context: context,
      builder: (_) => _DialogBatal(tanggal: _tglPanjang(j.tanggal)),
    );
    if (alasan == null) return;
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
    final mendatang = _daftar.where((j) => j.aktif && !j.selesai).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    final riwayat = _daftar.where((j) => j.selesai).toList()
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    final riwayatTampil = _semuaRiwayat ? riwayat : riwayat.take(2).toList();

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Jadwal',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.hijauMuda,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _gagal == null ? AppColors.hijau : AppColors.kuning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(_gagal == null ? 'Online' : 'Offline',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.hijau)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE3E8E5)),
            ),
            child: const Icon(Icons.calendar_month_outlined, size: 19, color: _hijauGelap),
          ),
        ],
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
                backgroundColor: _hijauTua,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _form(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Jadwal Posyandu',
                  style: TextStyle(fontWeight: FontWeight.w800)),
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
            _infoAtas(),
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
                trailing: Pill('${mendatang.length} jadwal',
                    bg: AppColors.hijauMuda, fg: AppColors.hijau),
                child: mendatang.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Belum ada jadwal. Tekan "Tambah Jadwal Posyandu" untuk membuat jadwal baru.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                        ),
                      )
                    : Column(children: [for (final j in mendatang) _kartu(j)]),
              ),
              _broadcast(),
              const SizedBox(height: 12),
              _riwayat(riwayat, riwayatTampil),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoAtas() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F6EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFE5D0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: _hijauGelap, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pendaftaran orang tua dibuka kapan saja setelah jadwal terbit dan check-in dibuka 1 jam sebelum mulai. Hanya satu jadwal per tanggal.',
              style: TextStyle(fontSize: 12, height: 1.4, color: _hijauTua),
            ),
          ),
        ],
      ),
    );
  }

  Widget _broadcast() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F7F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDEBE2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.chat_bubble_outline, color: _hijauGelap, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Broadcast WhatsApp Kader',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: _hijauTua)),
                SizedBox(height: 2),
                Text('Kirim pesan reminder otomatis H-2 ke ibu balita.',
                    style: TextStyle(fontSize: 11, color: AppColors.teksRedup, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _biru,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => soon(context, 'Broadcast WhatsApp'),
              child: const Text('Kirim',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riwayat(List<JadwalItem> semua, List<JadwalItem> tampil) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Riwayat Kegiatan Selesai',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              if (semua.length > 2)
                InkWell(
                  onTap: () => setState(() => _semuaRiwayat = !_semuaRiwayat),
                  child: Text(_semuaRiwayat ? 'Ringkas' : 'Lihat Semua',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _biru)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (tampil.isEmpty)
            const Text('Belum ada kegiatan yang selesai.',
                style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup))
          else
            for (final j in tampil) _barisRiwayat(j),
        ],
      ),
    );
  }

  Widget _barisRiwayat(JadwalItem j) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE3E8E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(j.tanggal.day.toString().padLeft(2, '0'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tglRiwayat(j.tanggal),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                Text(j.lokasi.isEmpty ? 'Posyandu' : j.lokasi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE3E8E5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Selesai',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _kartu(JadwalItem j) {
    final jam = j.jamSelesai.isEmpty ? j.jamMulai : '${j.jamMulai} - ${j.jamSelesai}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.hijauMuda,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_available, color: _hijauGelap, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_tglPanjang(j.tanggal),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 13, color: AppColors.teksRedup),
                        const SizedBox(width: 4),
                        Text('$jam WIB',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.teksRedup)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.hijauMuda,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Terjadwal',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.hijau)),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE6ECE8)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, size: 16, color: AppColors.teksRedup),
              const SizedBox(width: 6),
              Expanded(
                child: Text(j.lokasi.isEmpty ? 'Lokasi belum diisi' : j.lokasi,
                    style: const TextStyle(fontSize: 12, height: 1.3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(Icons.groups_outlined, 'Balita Terdaftar', _biru,
                  const Color(0xFFEAF4FB)),
              _chip(Icons.circle, 'Imunisasi & Gizi', _oranye, const Color(0xFFFFF1E6),
                  kecil: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _hijauGelap,
                      side: const BorderSide(color: _hijauGelap),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _form(awal: j),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Ubah',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.merah,
                      side: const BorderSide(color: AppColors.merah),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _batalkan(j),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Batalkan',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData ikon, String teks, Color fg, Color bg, {bool kecil = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: kecil ? 7 : 13, color: fg),
          const SizedBox(width: 5),
          Text(teks,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DIALOG PEMBATALAN
// ---------------------------------------------------------------------------
class _DialogBatal extends StatefulWidget {
  final String tanggal;
  const _DialogBatal({required this.tanggal});

  @override
  State<_DialogBatal> createState() => _DialogBatalState();
}

class _DialogBatalState extends State<_DialogBatal> {
  final _c = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Batalkan jadwal?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.tanggal, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Orang tua yang sudah mendaftar akan menerima pemberitahuan bahwa jadwal diperbarui.',
            style: TextStyle(fontSize: 12, color: AppColors.teksRedup),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _c,
            maxLines: 2,
            decoration: _dekor('Alasan pembatalan').copyWith(errorText: _err),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.merah, foregroundColor: Colors.white),
          onPressed: () {
            final t = _c.text.trim();
            if (t.isEmpty) {
              setState(() => _err = 'Alasan wajib diisi');
              return;
            }
            Navigator.pop(context, t);
          },
          child: const Text('Batalkan Jadwal'),
        ),
      ],
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
                  'Pendaftaran dibuka kapan saja setelah jadwal terbit dan check-in dibuka 1 jam sebelum mulai.',
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