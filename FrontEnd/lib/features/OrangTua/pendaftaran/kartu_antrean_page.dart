import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/auth_provider.dart';
import '../riwayat/pemeriksaan_page.dart' show OrangTuaPemeriksaanPage;

const _hijauHeader = Color(0xFF065F46);
const _hijauTua = Color(0xFF0B3D2E);
const _teksGelap = Color(0xFF1F2937);
const _oranye2 = Color(0xFFF97316); // titik status "belum check-in"

/// Garis tepi kartu: hitam lembut (sama dengan halaman lain).
const _garis = Color(0xFFB8BEC6);

// ---------------------------------------------------------------------------
// KOMPONEN TAMPILAN JADWAL (putih berbayang, simpel dan rapi)
// ---------------------------------------------------------------------------

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Garis pemisah lembut.
const _garisLembut = Color(0xFFE5E7EB);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

const _hariPekan = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

/// Keterangan hitung mundur: "Hari ini", "Besok", "H-3", atau "Selesai".
String _hitungMundur(DateTime t) {
  final n = DateTime.now();
  final s = DateTime(t.year, t.month, t.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (s == 0) return 'Hari ini';
  if (s == 1) return 'Besok';
  if (s > 1) return 'H-$s';
  return 'Selesai';
}

/// Kepala jadwal: label kecil, hari (kapital), tanggal; keterangan di kanan; garis aksen.
Widget _kepalaJadwal(String label, DateTime t, String tanggal, {String? kanan}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: _aksen)),
                  const SizedBox(height: 4),
                  Text(_hariPekan[t.weekday - 1].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w700,
                          color: _teksGelap)),
                  Text(tanggal,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
                ],
              ),
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(kanan,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w700, color: _hijauHeader)),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Baris keterangan: ikon kecil + "Label : nilai" (nilai lanjut ke samping).
Widget _barisKet(IconData ikon, String label, String nilai) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(ikon, size: 18, color: _aksen),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label : ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _teksGelap),
                ),
                TextSpan(
                  text: nilai.isEmpty ? '-' : nilai,
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 15.5, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

/// Kotak pesan status (teks biasa dalam kartu putih berbayang).
Widget _kotakStatus(String teks, Color warna) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: _bayangan,
    ),
    child: Text(teks,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: warna)),
  );
}

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

  /// Posisi anak dalam pelayanan (dari server): belum_checkin | menunggu_kader |
  /// menunggu_bidan | selesai | tidak_dilayani | batal | tidak_hadir.
  final String tahap;

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
    this.tahap = '',
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
      tahap: j['tahap']?.toString() ?? '',
    );
  }

  /// Selesai dilayani = bidan sudah menyimpan catatan pemeriksaan.
  bool get selesai => status == 'sudah_checkin' && tahap == 'selesai';

  /// Sudah check-in tetapi jadwal berakhir sebelum bidan mencatat.
  bool get tidakDilayani => status == 'sudah_checkin' && tahap == 'tidak_dilayani';

  /// Masih berada dalam antrean pelayanan (perlu dipantau).
  bool get sedangDilayani => status == 'sudah_checkin' && !selesai && !tidakDilayani;

  String get kodeNomor => nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';

  String get idTiket {
    final n = nomor == null ? '000' : nomor.toString().padLeft(3, '0');
    return 'TKT-${tanggal.year}${tanggal.month.toString().padLeft(2, '0')}-$n';
  }

  String get jam => jamSelesai.isEmpty ? jamMulai : '$jamMulai - $jamSelesai';

  String get tanggalPanjang =>
      '${_hari[tanggal.weekday - 1]}, ${tanggal.day} ${_bulan[tanggal.month - 1]} ${tanggal.year}';
}

/// Judul header (gaya teks sama dengan halaman lain).
Widget _judulTebal(String teks) {
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

  /// Selama anak masih dalam antrean pelayanan, status disegarkan otomatis.
  Timer? _pantau;

  /// Penanda area tiket yang diubah menjadi gambar (Simpan Tiket / Bagikan).
  final _kunciTiket = GlobalKey();
  bool _menyimpan = false;
  bool _membagikan = false;

  @override
  void initState() {
    super.initState();
    _muat();
    _pantau = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_sibuk && (_kartu?.sedangDilayani ?? false)) _muat(senyap: true);
    });
  }

  @override
  void dispose() {
    _pantau?.cancel();
    super.dispose();
  }

  /// [senyap]: penyegaran otomatis; gangguan jaringan sesaat tidak menampilkan pesan error.
  Future<void> _muat({bool senyap = false}) async {
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
      if (!mounted || senyap) return;
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
  // SIMPAN TIKET & BAGIKAN KE WHATSAPP
  // -------------------------------------------------------------------------

  /// Mengubah tampilan tiket menjadi file PNG (resolusi 3x) di folder sementara.
  Future<File> _gambarTiket(KartuAntreanData k) async {
    await WidgetsBinding.instance.endOfFrame;
    final ro = _kunciTiket.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) {
      throw Exception('Tiket belum siap, coba lagi');
    }
    final ui.Image img = await ro.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (data == null) throw Exception('Gagal membuat gambar tiket');

    final dir = await getTemporaryDirectory();
    final nama = 'Antrean_${k.idTiket}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${dir.path}/$nama');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file;
  }

  /// Simpan Tiket: gambar tiket disimpan ke Galeri, album "PosyanduCare".
  Future<void> _simpanTiket() async {
    final k = _kartu;
    if (k == null || _menyimpan) return;
    setState(() => _menyimpan = true);
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        final izin = await Gal.requestAccess(toAlbum: true);
        if (!izin) {
          _snack('Izin galeri ditolak. Aktifkan di pengaturan HP untuk menyimpan tiket.');
          return;
        }
      }
      final file = await _gambarTiket(k);
      await Gal.putImage(file.path, album: 'PosyanduCare');
      _snack('Tiket tersimpan di Galeri (album PosyanduCare)');
    } on GalException catch (e) {
      _snack(e.type == GalExceptionType.accessDenied
          ? 'Izin galeri ditolak. Aktifkan di pengaturan HP untuk menyimpan tiket.'
          : e.type == GalExceptionType.notEnoughSpace
              ? 'Penyimpanan HP penuh, tiket tidak dapat disimpan'
              : 'Tiket gagal disimpan ke galeri');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  /// Teks yang ikut terkirim bersama gambar tiket.
  String _pesanBagikan(KartuAntreanData k) {
    final b = StringBuffer()
      ..writeln('*Bukti Antrean Posyandu*')
      ..writeln()
      ..writeln('Nama Anak : ${k.namaAnak}')
      ..writeln('Nomor Antrean : ${k.kodeNomor}')
      ..writeln('Tanggal : ${k.tanggalPanjang}');
    if (k.jam.isNotEmpty) b.writeln('Waktu : ${k.jam} WIB');
    if (k.lokasi.isNotEmpty) b.writeln('Lokasi : ${k.lokasi}');
    b
      ..writeln('ID Tiket : ${k.idTiket}')
      ..writeln()
      ..write('Dikirim dari aplikasi PosyanduCare');
    return b.toString();
  }

  /// Bagikan ke WhatsApp: gambar tiket + keterangan dikirim lewat menu bagikan HP
  /// (pilih WhatsApp, lalu kontak atau grup tujuan).
  Future<void> _bagikanWhatsApp() async {
    final k = _kartu;
    if (k == null || _membagikan) return;
    setState(() => _membagikan = true);
    try {
      final file = await _gambarTiket(k);
      if (!mounted) return;
      final kotak = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: _pesanBagikan(k),
          subject: 'Bukti Antrean Posyandu ${k.kodeNomor}',
          sharePositionOrigin:
              kotak == null ? null : kotak.localToGlobal(Offset.zero) & kotak.size,
        ),
      );
    } catch (e) {
      _snack('Tiket gagal dibagikan: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _membagikan = false);
    }
  }

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Imunisasi Anak: polos, judul di tengah)
  // -------------------------------------------------------------------------
  Widget _header() {
    return Container(
      width: double.infinity,
      color: _hijauHeader,
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
                child: _judulTebal('Nomor Antrean'),
              ),
              // Tombol kembali di kiri
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

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final namaUser = (context.read<AuthProvider>().user?['nama'] ?? '').toString();
    final k = _kartu;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.latar,
        body: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    if (_memuat)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_gagal != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.kuningMuda,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _bayangan,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off, color: AppColors.kuning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_gagal!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500, fontSize: 15.5)),
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
                      const SizedBox(height: 6),
                      // Area ini yang menjadi gambar saat disimpan / dibagikan.
                      RepaintBoundary(
                        key: _kunciTiket,
                        child: Container(
                          color: AppColors.latar,
                          padding: const EdgeInsets.all(6),
                          child: _tiket(k, namaUser),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _aksiUtama(k),
                      const SizedBox(height: 12),
                      _aksiTambahan(),
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

  // -------------------------------------------------------------------------
  // TIKET
  // -------------------------------------------------------------------------
  Widget _tiket(KartuAntreanData k, String namaUser) {
    final batal = k.status == 'batal' || k.status == 'tidak_hadir';
    final selesaiAtauLewat = k.selesai || k.tidakDilayani;
    final (teksStatus, warnaTitik) = switch (k.status) {
      'sudah_checkin' => switch (k.tahap) {
          'selesai' => ('Selesai dilayani', _hijauHeader),
          'menunggu_bidan' => ('Menunggu pemeriksaan bidan', AppColors.biru),
          'tidak_dilayani' => ('Tidak dilayani', const Color(0xFFEF4444)),
          _ => ('Menunggu pengukuran kader', const Color(0xFF10B981)),
        },
      'terdaftar' => ('Belum check-in', _oranye2),
      'batal' => ('Antrean dibatalkan', const Color(0xFFEF4444)),
      _ => ('Antrean tidak aktif', const Color(0xFFEF4444)),
    };

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tanggal & sesi
          _kepalaJadwal(
            'JADWAL POSYANDU',
            k.tanggal,
            '${k.tanggal.day} ${_bulan[k.tanggal.month - 1]} ${k.tanggal.year}',
            kanan: batal ? null : _hitungMundur(k.tanggal),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                _barisKet(Icons.schedule, 'Waktu', k.jam.isEmpty ? '' : '${k.jam} WIB'),
                if (k.lokasi.isNotEmpty) _barisKet(Icons.location_on_outlined, 'Lokasi', k.lokasi),
              ],
            ),
          ),

          // Nomor panggilan
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _garisLembut)),
            ),
            child: Column(
              children: [
                const Text(
                  'NOMOR PANGGILAN ANDA',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: _aksen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  k.kodeNomor,
                  style: TextStyle(
                    fontSize: 46,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: (batal || selesaiAtauLewat) ? AppColors.teksRedup : _hijauHeader,
                    decoration: batal ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: warnaTitik, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      teksStatus,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _teksGelap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${k.idTiket}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                    color: AppColors.teksRedup,
                  ),
                ),
              ],
            ),
          ),
          _pemisah(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _kolomNama('Nama Anak', k.namaAnak)),
                const SizedBox(width: 12),
                Expanded(child: _kolomNama('Nama Pendamping', namaUser.isEmpty ? '-' : namaUser)),
              ],
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
            style: const TextStyle(color: _aksen, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(nilai,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _teksGelap, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  /// Garis putus-putus dengan lekukan tiket di kiri dan kanan.
  Widget _pemisah() {
    final latar = AppColors.latar;
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Container(
            width: 11,
            height: 22,
            decoration: BoxDecoration(
              color: latar,
              borderRadius: const BorderRadius.only(
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
                    (_) => Container(width: 5, height: 1.5, color: _garis),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 11,
            height: 22,
            decoration: BoxDecoration(
              color: latar,
              borderRadius: const BorderRadius.only(
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
    if (k.selesai) {
      return Column(
        children: [
          _kotakStatus('Pelayanan selesai. Hasil pemeriksaan bidan sudah dapat dilihat.', _hijauHeader),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hijauHeader,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrangTuaPemeriksaanPage(anakId: k.anakId, pendaftaranId: k.pendaftaranId),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined, size: 21),
              label: const Text('Lihat Hasil Pemeriksaan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
            ),
          ),
        ],
      );
    }
    if (k.tidakDilayani) {
      return _kotakStatus(
          'Sesi berakhir sebelum anak diperiksa bidan. Silakan hubungi bidan atau kader posyandu.',
          AppColors.merah);
    }
    if (k.status == 'sudah_checkin') {
      return _kotakStatus(
          k.tahap == 'menunggu_bidan'
              ? 'Pengukuran selesai. Silakan menunggu dipanggil bidan.'
              : 'Check-in berhasil. Silakan menunggu dipanggil kader.',
          _hijauHeader);
    }
    if (k.status == 'batal') {
      return _kotakStatus('Pendaftaran ini telah dibatalkan', AppColors.merah);
    }
    if (k.status == 'tidak_hadir') {
      return _kotakStatus('Anak tidak hadir pada sesi ini', AppColors.merah);
    }

    final aktifCheckin = k.bolehCheckin && !_sibuk;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.merah,
                    side: BorderSide(
                        color: AppColors.merah.withValues(alpha: (k.bolehBatal && !_sibuk) ? 1 : 0.5),
                        width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _batal,
                  child: const Text('Batalkan',
                      maxLines: 1,
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
                    backgroundColor: aktifCheckin ? _hijauHeader : _hijauHeader.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _checkin,
                  child: Text(
                    _sibuk ? 'Memproses...' : 'Check-in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (!k.bolehCheckin && k.checkinBuka != null) ...[
          const SizedBox(height: 8),
          Text('Check-in dibuka pukul ${formatJam(k.checkinBuka!)} WIB (1 jam sebelum jadwal dimulai)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.teksRedup)),
        ],
      ],
    );
  }

  Widget _tombolKecil(IconData ikon, String teks, VoidCallback onTap, {bool proses = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: proses ? null : onTap,
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
            if (proses)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _hijauTua),
              )
            else
              Icon(ikon, size: 15, color: _hijauTua),
            const SizedBox(width: 6),
            Flexible(
              child: Text(teks,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: _hijauTua)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _tombolKecil(
                      Icons.download_outlined,
                      _menyimpan ? 'Menyimpan...' : 'Simpan Tiket',
                      _simpanTiket,
                      proses: _menyimpan)),
              const SizedBox(width: 8),
              Expanded(
                  child: _tombolKecil(
                      Icons.directions_walk, 'Petunjuk Arah', () => soon(context, 'Petunjuk arah'))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _tombolKecil(
                Icons.share_outlined,
                _membagikan ? 'Menyiapkan gambar...' : 'Bagikan Bukti Antrean ke WhatsApp',
                _bagikanWhatsApp,
                proses: _membagikan),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            icon: const Icon(Icons.arrow_back, size: 14, color: AppColors.teksRedup),
            label: const Text('Kembali ke Beranda Posyandu',
                style: TextStyle(fontSize: 14, color: AppColors.teksRedup)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCAN CHECK-IN LANGSUNG (dipakai tombol "Scan Sekarang" di beranda)
// ---------------------------------------------------------------------------
/// Membuka kamera, memindai QR posyandu, lalu check-in anak [anakId] pada
/// jadwal [jadwalId]. Mengembalikan true bila check-in berhasil.
Future<bool> scanCheckin(BuildContext context,
    {required String jadwalId, required String anakId}) async {
  final kode = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const _LayarScanQr()),
  );
  if (kode == null || kode.isEmpty || !context.mounted) return false;
  final pesan = ScaffoldMessenger.of(context);
  void snack(String m) => pesan
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
  try {
    await ApiClient.dio.post(
      '/jadwal/$jadwalId/scan',
      data: {'anak_id': anakId, 'kode_qr': kode.trim()},
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );
    snack('Check-in berhasil. Anda masuk ke antrean pendataan kader.');
    return true;
  } catch (e) {
    snack(_pesanError(e));
    return false;
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
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}