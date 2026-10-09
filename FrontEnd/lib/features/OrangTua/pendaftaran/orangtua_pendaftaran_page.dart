import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import 'orangtua_kartu_antrean_page.dart';

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
// KONSTANTA TAMPILAN
// ---------------------------------------------------------------------------
const _hijauTua = Color(0xFF0B3D2E);
const _hijauGelap = Color(0xFF14634A);
const _hijauAksen = Color(0xFF1F7A5C);
const _oranye1 = Color(0xFFEA580C);
const _oranye2 = Color(0xFFF97316);

const _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember'
];
const _singkatHari = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];

String _tglPanjang(DateTime d) => '${d.day} ${_namaBulan[d.month - 1]} ${d.year}';
String _jamMenit(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// HALAMAN PENDAFTARAN (ORANG TUA)
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
  int _idx = 0; // anak terpilih (tampilan)

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
        if (j == null || _idx >= j.anak.length) _idx = 0;
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

  Future<void> _bukaKartu(String jadwalId, String anakId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => KartuAntreanPage(jadwalId: jadwalId, anakId: anakId)),
    );
    if (mounted) _muat();
  }

  Future<void> _daftar(AnakStatusJadwal a) async {
    final j = _jadwal;
    if (j == null || _sibuk != null) return;
    setState(() => _sibuk = a.anakId);
    var berhasil = false;
    try {
      await ApiClient.dio.post(
        '/jadwal/${j.id}/daftar',
        data: {'anak_id': a.anakId},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      berhasil = true;
      _snack('Pendaftaran berhasil. Kartu antrean Anda sudah terbit.');
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
    if (berhasil && mounted) {
      await _bukaKartu(j.id, a.anakId);
    }
  }

  Future<void> _batal(AnakStatusJadwal a) async {
    final j = _jadwal;
    if (j == null || _sibuk != null) return;
    final ya = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan pendaftaran?'),
        content: Text('Pendaftaran ${a.nama} akan dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ya != true) return;
    setState(() => _sibuk = a.anakId);
    try {
      await ApiClient.dio.post(
        '/jadwal/${j.id}/batal',
        data: {'anak_id': a.anakId},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      _snack('Pendaftaran dibatalkan');
      await _muat();
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final j = _jadwal;
    final punyaAnak = !_memuat && _gagal == null && j != null && j.anak.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.latar,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _muat,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _header(),
              const SizedBox(height: 14),
              if (_memuat)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_gagal != null)
                _kartuPesan(
                  warna: AppColors.kuningMuda,
                  ikon: Icons.cloud_off,
                  ikonWarna: AppColors.kuning,
                  teks: _gagal!,
                  aksi: TextButton(
                    onPressed: () {
                      setState(() => _memuat = true);
                      _muat();
                    },
                    child: const Text('Coba lagi'),
                  ),
                )
              else if (j == null)
                _kartuPesan(
                  warna: Colors.white,
                  ikon: Icons.event_busy,
                  ikonWarna: AppColors.teksRedup,
                  teks:
                      'Belum ada jadwal posyandu mendatang. Pendaftaran dapat dilakukan setelah admin menerbitkan jadwal.',
                )
              else ...[
                _kartuJadwal(j),
                const SizedBox(height: 20),
                if (j.anak.isEmpty)
                  _kartuPesan(
                    warna: Colors.white,
                    ikon: Icons.child_care,
                    ikonWarna: AppColors.teksRedup,
                    teks: 'Belum ada data anak. Lengkapi data keluarga di beranda terlebih dahulu.',
                  )
                else ...[
                  _judulProfil(),
                  const SizedBox(height: 10),
                  _kartuAnak(j, j.anak[_idx.clamp(0, j.anak.length - 1)]),
                  const SizedBox(height: 14),
                  _kartuPetunjuk(),
                  const SizedBox(height: 12),
                  _kartuOffline(),
                ],
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: punyaAnak
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _barAksi(j, j.anak[_idx.clamp(0, j.anak.length - 1)]),
              ),
            )
          : null,
    );
  }

  // -------------------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------------------
   Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE3E8E5)),
            ),
            child: const Icon(Icons.arrow_back, color: _hijauGelap, size: 21),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7F0E3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.how_to_reg, size: 13, color: _hijauGelap),
                    SizedBox(width: 5),
                    Text('Pendaftaran Posyandu',
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w700, color: _hijauGelap)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sesi Pendaftaran\nPosyandu',
                style: TextStyle(
                    fontSize: 25, height: 1.15, fontWeight: FontWeight.w800, color: _hijauTua),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E8E5)),
          ),
          child: const Icon(Icons.calendar_month, color: _hijauGelap, size: 21),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // KARTU JADWAL (HERO)
  // -------------------------------------------------------------------------
  Widget _kartuJadwal(JadwalTerdekatData j) {
    final infoTeks = [
      'Pendaftaran dapat dilakukan kapan saja.',
      if (j.checkinBuka != null)
        'Check-in dengan scan QR di posyandu dibuka 1 jam sebelum mulai (${_jamMenit(j.checkinBuka!)} WIB).',
    ].join(' ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_hijauTua, _hijauGelap],
        ),
        boxShadow: [
          BoxShadow(color: _hijauTua.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'Sesi Terdekat • ${_namaBulan[j.tanggal.month - 1]} ${j.tanggal.year}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TANGGAL & SESI PELAKSANAAN',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 9.5,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tglPanjang(j.tanggal),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(_singkatHari[j.tanggal.weekday - 1],
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700)),
                    Text(j.tanggal.day.toString().padLeft(2, '0'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _tileInfo(Icons.schedule, 'Waktu', '${j.jam} WIB')),
              const SizedBox(width: 10),
              Expanded(
                  child: _tileInfo(
                      Icons.place_outlined, 'Lokasi', j.lokasi.isEmpty ? '-' : j.lokasi)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [_oranye1, _oranye2]),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INFORMASI PENTING',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(infoTeks,
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileInfo(IconData ikon, String label, String nilai) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(ikon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600)),
                Text(nilai,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // PROFIL BALITA
  // -------------------------------------------------------------------------
  Widget _judulProfil() {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: _hijauGelap, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Profil Balita Terpilih',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _hijauTua)),
        ),
        InkWell(
          onTap: () => _snack('Tambah anak baru dilakukan melalui data keluarga di beranda'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 13, color: _oranye1),
              SizedBox(width: 3),
              Text('Anak Baru',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _oranye1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kartuAnak(JadwalTerdekatData j, AnakStatusJadwal a) {
    final (label, bg, fg) = labelStatusHadir(a.status);
    final banyak = j.anak.length > 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECE8)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFD7F0E3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.child_care, color: _hijauGelap, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800, color: _hijauTua)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(label,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
                ),
                if (a.nomorAntrean != null && a.status != 'belum_daftar') ...[
                  const SizedBox(height: 6),
                  Text('Nomor antrean #${a.nomorAntrean}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _sibuk != null
                ? null
                : () {
                    if (banyak) {
                      setState(() => _idx = (_idx + 1) % j.anak.length);
                    } else {
                      _snack('Hanya ada satu data anak');
                    }
                  },
            child: Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.isiField,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(Icons.swap_horiz, size: 19, color: _hijauGelap),
                  SizedBox(height: 2),
                  Text('Ganti',
                      style: TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w700, color: _hijauGelap)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // KARTU INFORMASI
  // -------------------------------------------------------------------------
  Widget _kartuPetunjuk() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFDDEEF9),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.qr_code_scanner, color: AppColors.biru, size: 23),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Petunjuk Check-in Mandiri',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _hijauTua)),
                SizedBox(height: 3),
                Text(
                  'Kartu antrean muncul setelah pendaftaran. Scan QR di posyandu untuk check-in, lalu data anak masuk ke antrean pendataan kader.',
                  style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.teksRedup),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFD5DBD8)),
            ),
            child: const Icon(Icons.confirmation_number_outlined, size: 15, color: _hijauGelap),
          ),
        ],
      ),
    );
  }

  Widget _kartuOffline() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F6EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFE5D0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white,
            child: Icon(Icons.sync, size: 16, color: _hijauAksen),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: 'Offline-Ready: ',
                      style: TextStyle(fontWeight: FontWeight.w800, color: _hijauTua)),
                  TextSpan(
                      text:
                          'Kartu antrean dapat dibuka kembali kapan saja. Data otomatis tersinkronisasi ke server pada saat sinyal tersedia.',
                      style: TextStyle(color: _hijauGelap)),
                ],
              ),
              style: TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuPesan({
    required Color warna,
    required IconData ikon,
    required Color ikonWarna,
    required String teks,
    Widget? aksi,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: Row(
        children: [
          Icon(ikon, color: ikonWarna),
          const SizedBox(width: 10),
          Expanded(
            child: Text(teks,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.4)),
          ),
          if (aksi != null) aksi,
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // TOMBOL AKSI BAWAH
  // -------------------------------------------------------------------------
  Widget _tombolUtama({
    required String teks,
    required IconData ikon,
    required VoidCallback onTap,
    bool aktif = true,
  }) {
    return Opacity(
      opacity: aktif ? 1 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [_oranye1, _oranye2]),
            boxShadow: [
              BoxShadow(
                  color: _oranye1.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Flexible(
                child: Text(teks,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barAksi(JadwalTerdekatData j, AnakStatusJadwal a) {
    final proses = _sibuk == a.anakId;
    final lock = _sibuk != null;

    if (a.status == 'sudah_checkin') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Pill('Check-in selesai, menunggu dipanggil kader',
              bg: AppColors.hijauMuda, fg: AppColors.hijau, icon: Icons.check_circle),
          const SizedBox(height: 8),
          _tombolUtama(
            teks: 'Lihat Kartu Antrean',
            ikon: Icons.confirmation_number_outlined,
            onTap: () => _bukaKartu(j.id, a.anakId),
          ),
        ],
      );
    }

    if (a.status == 'terdaftar') {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: _tombolUtama(
              teks: 'Kartu Antrean',
              ikon: Icons.confirmation_number_outlined,
              aktif: !lock,
              onTap: lock ? () {} : () => _bukaKartu(j.id, a.anakId),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: AppButton(
                proses ? 'Memproses...' : 'Batalkan',
                filled: false,
                color: AppColors.merah,
                icon: Icons.close,
                onPressed: (!a.bolehBatal || lock)
                    ? () => _snack('Pendaftaran tidak dapat dibatalkan')
                    : () => _batal(a),
              ),
            ),
          ),
        ],
      );
    }

    if (a.status == 'tidak_hadir') {
      return const Pill('Anak tidak hadir pada sesi ini',
          bg: AppColors.merahMuda, fg: AppColors.merah);
    }

    return _tombolUtama(
      teks: proses ? 'Memproses...' : 'Daftarkan Balita Ini Sekarang',
      ikon: Icons.how_to_reg,
      aktif: a.bolehDaftar && !lock,
      onTap: (!a.bolehDaftar || lock)
          ? () => _snack(a.bolehDaftar ? 'Sedang memproses...' : 'Pendaftaran sudah ditutup')
          : () => _daftar(a),
    );
  }
}