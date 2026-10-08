import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class AnakStatusJadwal {
  final String anakId;
  final String nama;
  final String status; // belum_daftar | terdaftar | sudah_checkin | tidak_hadir
  final int? nomorAntrean;
  final bool bolehDaftar;
  final bool bolehBatal;
  final bool bolehCheckin;

  AnakStatusJadwal({
    required this.anakId,
    required this.nama,
    required this.status,
    required this.nomorAntrean,
    required this.bolehDaftar,
    required this.bolehBatal,
    required this.bolehCheckin,
  });

  factory AnakStatusJadwal.fromApi(Map<String, dynamic> j) => AnakStatusJadwal(
        anakId: j['anak_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        status: j['status_kehadiran']?.toString() ?? 'belum_daftar',
        nomorAntrean: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
        bolehDaftar: j['boleh_daftar'] == true,
        bolehBatal: j['boleh_batal'] == true,
        bolehCheckin: j['boleh_checkin'] == true,
      );
}

class JadwalTerdekatData {
  final String id;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String lokasi;
  final DateTime? pendaftaranBuka;
  final DateTime? checkinBuka;
  final List<AnakStatusJadwal> anak;

  JadwalTerdekatData({
    required this.id,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.lokasi,
    required this.pendaftaranBuka,
    required this.checkinBuka,
    required this.anak,
  });

  static String _jam(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  static DateTime? _waktu(dynamic v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal();

  /// GET /jadwal/terdekat. Mengembalikan null bila tidak ada jadwal aktif
  /// (jadwal berstatus dibatalkan tidak pernah ditampilkan).
  static Future<JadwalTerdekatData?> ambil() async {
    final r = await ApiClient.dio
        .get('/jadwal/terdekat', options: Options(receiveTimeout: const Duration(seconds: 15)));
    dynamic d = r.data;
    if (d is Map && d.containsKey('data')) d = d['data'];
    if (d is! Map) return null;

    final jRaw = d['jadwal'];
    if (jRaw is! Map) return null;
    final j = Map<String, dynamic>.from(jRaw);
    if ((j['status']?.toString() ?? 'terjadwal') != 'terjadwal') return null;

    final t = j['tanggal']?.toString() ?? '';
    final tgl = t.length >= 10 ? DateTime.tryParse(t.substring(0, 10)) : null;
    if (tgl == null) return null;

    final anak = ((d['anak'] as List?) ?? [])
        .map((e) => AnakStatusJadwal.fromApi(Map<String, dynamic>.from(e as Map)))
        .toList();

    return JadwalTerdekatData(
      id: j['id']?.toString() ?? '',
      tanggal: tgl,
      jamMulai: _jam(j['jam_mulai']),
      jamSelesai: _jam(j['jam_selesai']),
      lokasi: j['lokasi']?.toString() ?? '',
      pendaftaranBuka: _waktu(d['pendaftaran_dibuka_pada']),
      checkinBuka: _waktu(d['checkin_dibuka_pada']),
      anak: anak,
    );
  }

  String get jam => jamSelesai.isEmpty ? jamMulai : '$jamMulai - $jamSelesai';
}

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

(String, Color, Color) labelStatusHadir(String s) {
  switch (s) {
    case 'terdaftar':
      return ('Terdaftar', AppColors.biruMuda, AppColors.biru);
    case 'sudah_checkin':
      return ('Sudah check-in', AppColors.hijauMuda, AppColors.hijau);
    case 'tidak_hadir':
      return ('Tidak hadir', AppColors.merahMuda, AppColors.merah);
    default:
      return ('Belum daftar', AppColors.isiField, AppColors.teksRedup);
  }
}

// ---------------------------------------------------------------------------
// HALAMAN PENDAFTARAN & CHECK-IN (ORANG TUA)
// ---------------------------------------------------------------------------
class OrangTuaPendaftaranPage extends StatefulWidget {
  const OrangTuaPendaftaranPage({super.key});

  @override
  State<OrangTuaPendaftaranPage> createState() => _OrangTuaPendaftaranPageState();
}

class _OrangTuaPendaftaranPageState extends State<OrangTuaPendaftaranPage> {
  JadwalTerdekatData? _jadwal;
  bool _memuat = true;
  String? _gagal;
  String? _sibuk; // anakId yang sedang diproses

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      if (!mounted) return;
      setState(() {
        _jadwal = j;
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

  Future<void> _aksi(AnakStatusJadwal a, String jalur, String sukses) async {
    final j = _jadwal;
    if (j == null || _sibuk != null) return;
    setState(() => _sibuk = a.anakId);
    try {
      await ApiClient.dio.post(
        '/jadwal/${j.id}/$jalur',
        data: {'anak_id': a.anakId},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      _snack(sukses);
      await _muat();
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Pendaftaran Posyandu',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
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
            else if (_jadwal == null)
              SectionCard(
                title: 'Jadwal Posyandu',
                icon: Icons.event_busy,
                child: const Text(
                  'Belum ada jadwal posyandu mendatang. Pendaftaran dapat dilakukan setelah admin membuat jadwal.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                ),
              )
            else ...[
              _kartuJadwal(_jadwal!),
              if (_jadwal!.anak.isEmpty)
                SectionCard(
                  title: 'Data Anak',
                  icon: Icons.child_care,
                  child: const Text(
                    'Belum ada data anak. Lengkapi data keluarga di beranda terlebih dahulu.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                  ),
                )
              else
                for (final a in _jadwal!.anak) _kartuAnak(_jadwal!, a),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kartuJadwal(JadwalTerdekatData j) {
    return SectionCard(
      title: 'Jadwal Posyandu Terdekat',
      icon: Icons.event_note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${formatTanggal(j.tanggal)} · ${j.jam} WIB',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          if (j.lokasi.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(j.lokasi, style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.kuningMuda,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              [
                if (j.pendaftaranBuka != null)
                  'Pendaftaran dibuka ${formatTanggal(j.pendaftaranBuka!)}.',
                if (j.checkinBuka != null)
                  'Check-in dibuka 1 jam sebelum mulai (${formatJam(j.checkinBuka!)}).',
              ].join(' '),
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuAnak(JadwalTerdekatData j, AnakStatusJadwal a) {
    final (label, bg, fg) = labelStatusHadir(a.status);
    final proses = _sibuk == a.anakId;
    final lock = _sibuk != null;

    Widget aksi;
    if (a.status == 'sudah_checkin') {
      aksi = const Pill('Check-in selesai, menunggu panggilan kader',
          bg: AppColors.hijauMuda, fg: AppColors.hijau, icon: Icons.check_circle);
    } else if (a.status == 'terdaftar') {
      aksi = Row(
        children: [
          Expanded(
            child: AppButton(
              proses ? 'Memproses...' : 'Check-in',
              icon: Icons.login,
              onPressed: (!a.bolehCheckin || lock)
                  ? () => _snack(a.bolehCheckin
                      ? 'Sedang memproses...'
                      : 'Check-in dibuka pukul ${j.checkinBuka == null ? '-' : formatJam(j.checkinBuka!)}')
                  : () => _aksi(a, 'checkin', 'Check-in berhasil'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(
              'Batalkan',
              filled: false,
              color: AppColors.merah,
              icon: Icons.close,
              onPressed: (!a.bolehBatal || lock)
                  ? () => _snack('Pendaftaran tidak dapat dibatalkan')
                  : () => _aksi(a, 'batal', 'Pendaftaran dibatalkan'),
            ),
          ),
        ],
      );
    } else if (a.status == 'tidak_hadir') {
      aksi = const Pill('Anak tidak hadir pada sesi ini',
          bg: AppColors.merahMuda, fg: AppColors.merah);
    } else {
      aksi = AppButton(
        proses ? 'Memproses...' : 'Daftarkan ${a.nama}',
        icon: Icons.how_to_reg,
        onPressed: (!a.bolehDaftar || lock)
            ? () => _snack(a.bolehDaftar
                ? 'Sedang memproses...'
                : 'Pendaftaran belum dibuka atau sudah ditutup')
            : () => _aksi(a, 'daftar', 'Pendaftaran berhasil disimpan'),
      );
    }

    return SectionCard(
      title: a.nama,
      icon: Icons.child_care,
      trailing: Pill(label, bg: bg, fg: fg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.nomorAntrean != null && a.status != 'belum_daftar') ...[
            Text('Nomor antrean #${a.nomorAntrean}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 8),
          ],
          aksi,
        ],
      ),
    );
  }
}