import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../auth/auth_provider.dart';

const _hijauTua = Color(0xFF0B3D2E);
const _hijauGelap = Color(0xFF14634A);
const _oranye1 = Color(0xFFEA580C);
const _oranye2 = Color(0xFFF97316);
const _biruTombol = Color(0xFF2B7BB9);

const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
  'Agustus', 'September', 'Oktober', 'November', 'Desember'
];
const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

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

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class KartuAntreanData {
  final String pendaftaranId;
  final String anakId;
  final String namaAnak;
  final String jadwalId;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String lokasi;
  final int? nomor;
  final String status; // terdaftar | sudah_checkin | batal | tidak_hadir
  final DateTime? checkinBuka;
  final DateTime? waktuCheckin;
  final bool bolehBatal;
  final bool bolehCheckin;

  KartuAntreanData({
    required this.pendaftaranId,
    required this.anakId,
    required this.namaAnak,
    required this.jadwalId,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.lokasi,
    required this.nomor,
    required this.status,
    required this.checkinBuka,
    required this.waktuCheckin,
    required this.bolehBatal,
    required this.bolehCheckin,
  });

  static String _jam(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  factory KartuAntreanData.fromApi(Map<String, dynamic> j) {
    final t = j['tanggal']?.toString() ?? '';
    return KartuAntreanData(
      pendaftaranId: j['pendaftaran_id']?.toString() ?? '',
      anakId: j['anak_id']?.toString() ?? '',
      namaAnak: j['nama_anak']?.toString() ?? '-',
      jadwalId: j['jadwal_id']?.toString() ?? '',
      tanggal: (t.length >= 10 ? DateTime.tryParse(t.substring(0, 10)) : null) ?? DateTime.now(),
      jamMulai: _jam(j['jam_mulai']),
      jamSelesai: _jam(j['jam_selesai']),
      lokasi: j['lokasi']?.toString() ?? '',
      nomor: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
      status: j['status_kehadiran']?.toString() ?? 'terdaftar',
      checkinBuka: DateTime.tryParse(j['checkin_dibuka_pada']?.toString() ?? '')?.toLocal(),
      waktuCheckin: DateTime.tryParse(j['waktu_checkin']?.toString() ?? '')?.toLocal(),
      bolehBatal: j['boleh_batal'] == true,
      bolehCheckin: j['boleh_checkin'] == true,
    );
  }

  String get kodeNomor => nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';

  String get idTiket {
    final n = nomor == null ? '000' : nomor.toString().padLeft(3, '0');
    return 'TKT-${tanggal.year}${tanggal.month.toString().padLeft(2, '0')}-$n';
  }

  String get jam => jamSelesai.isEmpty ? jamMulai : '$jamMulai - $jamSelesai';

  String get tanggalPanjang =>
      '${_hari[tanggal.weekday - 1]}, ${tanggal.day} ${_bulan[tanggal.month - 1]} ${tanggal.year}';
}

// ---------------------------------------------------------------------------
// HALAMAN KARTU NOMOR ANTREAN
// ---------------------------------------------------------------------------
class KartuAntreanPage extends StatefulWidget {
  final String jadwalId;
  final String anakId;

  const KartuAntreanPage({super.key, required this.jadwalId, required this.anakId});

  @override
  State<KartuAntreanPage> createState() => _KartuAntreanPageState();
}

class _KartuAntreanPageState extends State<KartuAntreanPage> {
  KartuAntreanData? _kartu;
  bool _memuat = true;
  bool _sibuk = false;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final r = await ApiClient.dio.get(
        '/jadwal/${widget.jadwalId}/kartu',
        queryParameters: {'anak_id': widget.anakId},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      if (!mounted) return;
      setState(() {
        _kartu = KartuAntreanData.fromApi(Map<String, dynamic>.from(d as Map));
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

  Future<void> _checkin() async {
    final k = _kartu;
    if (k == null || _sibuk) return;
    if (!k.bolehCheckin) {
      final buka = k.checkinBuka;
      _snack(buka == null
          ? 'Check-in belum dapat dilakukan'
          : 'Check-in dibuka pukul ${formatJam(buka)} WIB (1 jam sebelum jadwal dimulai)');
      return;
    }
    final kode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _LayarScanQr()),
    );
    if (kode == null || kode.isEmpty) return;

    setState(() => _sibuk = true);
    try {
      await ApiClient.dio.post(
        '/jadwal/${k.jadwalId}/scan',
        data: {'anak_id': k.anakId, 'kode_qr': kode.trim()},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      _snack('Check-in berhasil. Anda masuk ke antrean pendataan kader.');
      await _muat();
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _batal() async {
    final k = _kartu;
    if (k == null || _sibuk) return;
    if (!k.bolehBatal) {
      _snack('Pendaftaran tidak dapat dibatalkan');
      return;
    }
    final ya = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan antrean?'),
        content: Text('Pendaftaran ${k.namaAnak} pada ${k.tanggalPanjang} akan dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ya != true) return;

    setState(() => _sibuk = true);
    try {
      await ApiClient.dio.post(
        '/jadwal/${k.jadwalId}/batal',
        data: {'anak_id': k.anakId},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      _snack('Pendaftaran dibatalkan');
      await _muat();
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final namaUser = (context.read<AuthProvider>().user?['nama'] ?? '').toString();
    final k = _kartu;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE3E8E5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.confirmation_number_outlined, size: 16, color: _hijauGelap),
              SizedBox(width: 6),
              Text('Kartu Nomor Antrean',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _hijauTua)),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            if (_memuat)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
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
            else if (k != null) ...[
              _bannerOffline(),
              const SizedBox(height: 12),
              _tiket(k, namaUser),
              const SizedBox(height: 14),
              _aksiUtama(k),
              const SizedBox(height: 12),
              _aksiTambahan(),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // BANNER OFFLINE
  // -------------------------------------------------------------------------
  Widget _bannerOffline() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E8E5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFD7F0E3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cloud_done_outlined, size: 19, color: _hijauGelap),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SIAP AKSES OFFLINE',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: _hijauTua, letterSpacing: 0.4)),
                SizedBox(height: 2),
                Text('Nomor antrean tersimpan valid dan dapat dibuka kembali.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.teksRedup, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD7F0E3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Tersimpan',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _hijauGelap)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // TIKET
  // -------------------------------------------------------------------------
  (String, Color) _labelStatus(String s) {
    switch (s) {
      case 'sudah_checkin':
        return ('SUDAH CHECK-IN', const Color(0xFF34D399));
      case 'batal':
        return ('DIBATALKAN', const Color(0xFFF87171));
      case 'tidak_hadir':
        return ('TIDAK HADIR', const Color(0xFFF87171));
      default:
        return ('TERKONFIRMASI', const Color(0xFF34D399));
    }
  }

  Widget _tiket(KartuAntreanData k, String namaUser) {
    final (labelStatus, warnaStatus) = _labelStatus(k.status);
    final batal = k.status == 'batal' || k.status == 'tidak_hadir';

    return Container(
      decoration: BoxDecoration(
        color: _hijauTua,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: _hijauTua.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: warnaStatus),
                          const SizedBox(width: 5),
                          Text(labelStatus,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text('ID: ${k.idTiket}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.place, size: 17, color: Color(0xFFFB923C)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(k.lokasi.isEmpty ? 'Posyandu' : k.lokasi,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.calendar_month, color: Colors.white, size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(k.tanggalPanjang,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                            Text('Sesi (${k.jam} WIB)',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.75), fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      const Text('NOMOR PANGGILAN ANDA',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.teksRedup)),
                      const SizedBox(height: 4),
                      Text(k.kodeNomor,
                          style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: batal ? AppColors.teksRedup : _hijauTua,
                              decoration: batal ? TextDecoration.lineThrough : null)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _oranye2,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              k.status == 'sudah_checkin'
                                  ? 'Menunggu panggilan kader'
                                  : k.status == 'terdaftar'
                                      ? 'Belum check-in'
                                      : 'Antrean tidak aktif',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800, color: _hijauTua),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _pemisah(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(child: _kolomNama('Nama Balita', k.namaAnak)),
                  const SizedBox(width: 10),
                  Expanded(child: _kolomNama('Nama Pendamping', namaUser.isEmpty ? '-' : namaUser)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kolomNama(String label, String nilai) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 9.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(nilai,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _pemisah() {
    const latar = Color(0xFFF1F4F2);
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Container(
            width: 11,
            height: 22,
            decoration: const BoxDecoration(
              color: latar,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                final n = (c.maxWidth / 9).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    n,
                    (_) => Container(width: 5, height: 1.5, color: Colors.white.withOpacity(0.35)),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 11,
            height: 22,
            decoration: const BoxDecoration(
              color: latar,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // AKSI: CHECK-IN & BATALKAN
  // -------------------------------------------------------------------------
  Widget _aksiUtama(KartuAntreanData k) {
    if (k.status == 'sudah_checkin') {
      return const Pill('Check-in berhasil. Silakan menunggu dipanggil kader.',
          bg: AppColors.hijauMuda, fg: AppColors.hijau, icon: Icons.check_circle);
    }
    if (k.status == 'batal') {
      return const Pill('Pendaftaran ini telah dibatalkan',
          bg: AppColors.merahMuda, fg: AppColors.merah);
    }
    if (k.status == 'tidak_hadir') {
      return const Pill('Anak tidak hadir pada sesi ini',
          bg: AppColors.merahMuda, fg: AppColors.merah);
    }

    final aktifCheckin = k.bolehCheckin && !_sibuk;
    return Column(
      children: [
        Opacity(
          opacity: aktifCheckin ? 1 : 0.65,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _checkin,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [_oranye1, _oranye2]),
                boxShadow: [
                  BoxShadow(
                      color: _oranye1.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white, size: 19),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _sibuk ? 'Memproses...' : 'Cek in Sekarang (Scan QR di Posyandu)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!k.bolehCheckin && k.checkinBuka != null) ...[
          const SizedBox(height: 6),
          Text('Check-in dibuka pukul ${formatJam(k.checkinBuka!)} WIB (1 jam sebelum jadwal dimulai)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
        ],
        const SizedBox(height: 10),
        Opacity(
          opacity: (k.bolehBatal && !_sibuk) ? 1 : 0.6,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _batal,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _biruTombol.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, color: _biruTombol, size: 18),
                  SizedBox(width: 8),
                  Text('Batalkan Antrean',
                      style: TextStyle(
                          color: _biruTombol, fontSize: 13.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tombolKecil(IconData ikon, String teks, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, size: 15, color: _hijauTua),
            const SizedBox(width: 6),
            Flexible(
              child: Text(teks,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: _hijauTua)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aksiTambahan() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _tombolKecil(
                      Icons.download_outlined, 'Simpan Tiket', () => soon(context, 'Simpan tiket'))),
              const SizedBox(width: 8),
              Expanded(
                  child: _tombolKecil(
                      Icons.directions_walk, 'Petunjuk Arah', () => soon(context, 'Petunjuk arah'))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _tombolKecil(Icons.share_outlined, 'Bagikan Bukti Antrean ke WhatsApp',
                () => soon(context, 'Bagikan ke WhatsApp')),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.arrow_back, size: 14, color: AppColors.teksRedup),
            label: const Text('Kembali ke Beranda Posyandu',
                style: TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LAYAR KAMERA: ORANG TUA MEMINDAI QR JADWAL DI POSYANDU
// ---------------------------------------------------------------------------
class _LayarScanQr extends StatefulWidget {
  const _LayarScanQr();

  @override
  State<_LayarScanQr> createState() => _LayarScanQrState();
}

class _LayarScanQrState extends State<_LayarScanQr> {
  final MobileScannerController _c = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _selesai = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _deteksi(BarcodeCapture cap) {
    if (_selesai) return;
    for (final b in cap.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _selesai = true;
        Navigator.pop(context, v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR di Posyandu'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _c.toggleTorch()),
          IconButton(icon: const Icon(Icons.cameraswitch), onPressed: () => _c.switchCamera()),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _c,
            onDetect: _deteksi,
            errorBuilder: (ctx, error, child) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kamera tidak dapat dibuka. Izinkan akses kamera pada pengaturan perangkat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Text(
              'Arahkan kamera ke QR check-in yang dipasang di lokasi posyandu',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}