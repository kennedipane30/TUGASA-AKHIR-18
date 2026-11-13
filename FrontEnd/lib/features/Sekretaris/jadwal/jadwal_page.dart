import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import 'edit_jadwal_page.dart';
import 'riwayat_jadwal_page.dart';
import 'tambah_jadwal_page.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class JadwalItem {
  final String id;
  final String posyandu;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String lokasi;
  final String status;
  final String alasanBatal;

  JadwalItem({
    required this.id,
    required this.posyandu,
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
      posyandu: j['posyandu']?.toString() ?? '',
      tanggal: tgl ?? DateTime.now(),
      jamMulai: jam(j['jam_mulai']),
      jamSelesai: jam(j['jam_selesai']),
      lokasi: j['lokasi']?.toString() ?? '',
      status: j['status']?.toString() ?? 'terjadwal',
      alasanBatal: j['alasan_batal']?.toString() ?? '',
    );
  }

  bool get aktif => status == 'terjadwal';

  /// Selesai bila jam selesai (atau jam mulai + 4 jam) sudah lewat.
  bool get selesai {
    if (status != 'terjadwal') return status == 'selesai';
    final jam = jamSelesai.isNotEmpty ? jamSelesai : jamMulai;
    final p = jam.split(':');
    final h = int.tryParse(p.isNotEmpty ? p[0] : '') ?? 0;
    final m = int.tryParse(p.length > 1 ? p[1] : '') ?? 0;
    var akhir = DateTime(tanggal.year, tanggal.month, tanggal.day, h, m);
    if (jamSelesai.isEmpty) akhir = akhir.add(const Duration(hours: 4));
    return !DateTime.now().isBefore(akhir);
  }
}

// ---------------------------------------------------------------------------
// HELPER
// ---------------------------------------------------------------------------
final Options opsiJadwal = Options(receiveTimeout: const Duration(seconds: 15));

const hijauTombolJadwal = Color(0xFF065F46); // tombol, sama dengan warna header
const warnaHeaderJadwal = Color(0xFF065F46); // warna header (sama dengan halaman vaksin)
const teksGelapJadwal = Color(0xFF1F2937);
const _oranye = Color(0xFFEA580C);
const _biru = Color(0xFF2B7BB9);

String pesanErrorJadwal(Object e) {
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

String fmtApiJadwal(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fmtJamJadwal(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? parseJamJadwal(String s) {
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

String tglPanjangJadwal(DateTime d) =>
    '${_namaHari[d.weekday - 1]}, ${d.day} ${_namaBulan[d.month - 1]} ${d.year}';

InputDecoration _dekor(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.isiField,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

/// Judul header (gaya teks sama dengan halaman lain).
Widget judulHeaderJadwal(String teks) {
  return Text(
    teks,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: Colors.white,
    ),
  );
}

// ---------------------------------------------------------------------------
// HALAMAN KELOLA JADWAL (SEKRETARIS)
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
      final r = await ApiClient.dio.get('/jadwal', options: opsiJadwal);
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
        _gagal = pesanErrorJadwal(e);
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
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            awal == null ? const AdminTambahJadwalPage() : AdminEditJadwalPage(jadwal: awal),
      ),
    );
    if (ok == true) {
      _snack(awal == null ? 'Jadwal berhasil dibuat' : 'Jadwal berhasil diubah');
      _muat();
    }
  }

  Future<void> _batalkan(JadwalItem j) async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (_) => _DialogBatal(tanggal: tglPanjangJadwal(j.tanggal)),
    );
    if (alasan == null) return;
    try {
      await ApiClient.dio.post('/sekretaris/jadwal/${j.id}/batalkan',
          data: {'alasan': alasan}, options: opsiJadwal);
      _snack('Jadwal dibatalkan');
      _muat();
    } catch (e) {
      _snack(pesanErrorJadwal(e));
    }
  }

  void _bukaRiwayat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminRiwayatJadwalPage()),
    );
  }

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
  // Tombol kembali hanya muncul bila ada halaman sebelumnya.
  // -------------------------------------------------------------------------
  Widget _header() {
    final bisaKembali = Navigator.canPop(context);

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
              // Judul di tengah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: judulHeaderJadwal('Jadwal'),
              ),
              // Tombol kembali di kiri
              if (bisaKembali)
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
    // Jadwal yang sudah lewat tidak ditampilkan di sini, hanya di Riwayat Jadwal.
    final mendatang = _daftar.where((j) => j.aktif && !j.selesai).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));

    return Scaffold(
      backgroundColor: AppColors.latar,
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE6ECE8))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hijauTombolJadwal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _form(),
              child: const Text('Tambah Jadwal Posyandu',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
            ),
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
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_memuat)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_gagal != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.kuningMuda,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE6ECE8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_gagal!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500, fontSize: 16.5)),
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
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE6ECE8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Jadwal Mendatang',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: teksGelapJadwal)),
                                ),
                                Pill('${mendatang.length} jadwal',
                                    bg: AppColors.hijauMuda, fg: AppColors.hijau),
                              ],
                            ),
                            const SizedBox(height: 14),
                            mendatang.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Belum ada jadwal. Tekan "Tambah Jadwal Posyandu" untuk membuat jadwal baru. Jadwal yang sudah lewat ada di Riwayat Jadwal.',
                                      style: TextStyle(
                                          fontSize: 16, color: AppColors.teksRedup),
                                    ),
                                  )
                                : Column(children: [for (final j in mendatang) _kartu(j)]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton('Lihat Riwayat Jadwal',
                            filled: false, onPressed: _bukaRiwayat),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tglPanjangJadwal(j.tanggal),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 17, color: teksGelapJadwal)),
                    const SizedBox(height: 2),
                    Text('$jam WIB',
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.teksRedup)),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.hijau)),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE6ECE8)),
          ),
          Text(j.lokasi.isEmpty ? 'Lokasi belum diisi' : j.lokasi,
              style: const TextStyle(fontSize: 16, height: 1.3, color: teksGelapJadwal)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip('Balita Terdaftar', _biru, const Color(0xFFEAF4FB)),
              _chip('Imunisasi & Gizi', _oranye, const Color(0xFFFFF1E6)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: hijauTombolJadwal,
                      side: const BorderSide(color: hijauTombolJadwal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => _form(awal: j),
                    child: const Text('Edit',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.merah,
                      side: const BorderSide(color: AppColors.merah),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => _batalkan(j),
                    child: const Text('Batalkan',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String teks, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(teks,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: fg)),
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
          Text(widget.tanggal,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 17)),
          const SizedBox(height: 6),
          const Text(
            'Orang tua yang sudah mendaftar akan menerima pemberitahuan bahwa jadwal diperbarui.',
            style: TextStyle(fontSize: 16, color: AppColors.teksRedup),
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