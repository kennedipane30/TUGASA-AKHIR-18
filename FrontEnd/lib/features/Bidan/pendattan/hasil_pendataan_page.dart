import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/posyandu.dart';
import '../../../core/widgets/status_gizi_widget.dart';
import '../../../service/balita_service.dart' show usiaDetail;
import '../../../service/kbm_model.dart';
import '../../auth/auth_provider.dart';
import '../../OrangTua/pendaftaran/pendaftaran_page.dart';
import 'catat_pemeriksaan_page.dart';

const _hijauHeader = Color(0xFF065F46);

class _ItemBidan {
  final String pendaftaranId;
  final String anakId;
  final String nama;
  final String jk;
  final DateTime? tanggalLahir;
  final int usiaBulan;
  final int? nomor;
  final bool sudahDiukur;
  final String peringatan;
  final bool selesai;
  final PenilaianTimbang? penilaian;
  final Map<String, dynamic>? statusGizi;

  _ItemBidan({
    required this.pendaftaranId,
    required this.anakId,
    required this.nama,
    required this.jk,
    required this.tanggalLahir,
    required this.usiaBulan,
    required this.nomor,
    required this.sudahDiukur,
    required this.peringatan,
    required this.selesai,
    this.penilaian,
    this.statusGizi,
  });

  factory _ItemBidan.fromApi(Map<String, dynamic> j) => _ItemBidan(
        pendaftaranId: j['pendaftaran_id']?.toString() ?? '',
        anakId: j['anak_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        jk: j['jenis_kelamin']?.toString() ?? '',
        tanggalLahir: _tglLahir(j['tanggal_lahir']),
        usiaBulan: int.tryParse(j['usia_bulan']?.toString() ?? '') ?? 0,
        nomor: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
        sudahDiukur: j['sudah_diukur'] == true,
        peringatan: j['peringatan_validasi']?.toString() ?? '',
        selesai: j['status_catatan']?.toString() == 'selesai',
        penilaian: PenilaianTimbang.dari(j['penilaian']),
        statusGizi: petaGizi(j['status_gizi']),
      );

  bool get perluPerhatian =>
      penilaian?.perluRujuk == true || masalahGiziBerat(statusGizi);

  String get kodeNomor =>
      nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';

  /// Usia detail, mis. "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan".
  String get usia {
    if (tanggalLahir != null) return usiaDetail(tanggalLahir);
    final th = usiaBulan ~/ 12;
    final bl = usiaBulan % 12;
    if (th == 0) return '$usiaBulan bulan';
    return bl == 0 ? '$th tahun' : '$th tahun $bl bulan';
  }
}

DateTime? _tglLahir(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
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

/// Waktu mulai sesi posyandu dari tanggal jadwal dan teks jam ("08:00" / "08:00 - 12:00").
DateTime? _waktuMulaiSesi(DateTime? tanggal, String jam) {
  if (tanggal == null) return null;
  final m = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(jam);
  if (m == null) return null;
  return DateTime(tanggal.year, tanggal.month, tanggal.day,
      int.parse(m.group(1)!), int.parse(m.group(2)!));
}

String _jamMenit(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Pesan di bagian atas halaman bila sesi posyandu belum dimulai.
Widget _bannerBelumMulai(DateTime mulai) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.kuningMuda,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.kuning.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule, color: AppColors.kuning),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sesi posyandu belum dimulai',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                'Pendataan dapat dilakukan mulai ${formatTanggal(mulai)} '
                'pukul ${_jamMenit(mulai)} WIB.',
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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

class BidanHasilPendataanPage extends StatefulWidget {
  const BidanHasilPendataanPage({super.key});

  @override
  State<BidanHasilPendataanPage> createState() =>
      _BidanHasilPendataanPageState();
}

class _BidanHasilPendataanPageState extends State<BidanHasilPendataanPage> {

  JadwalTerdekatData? _jadwal;
  List<_ItemBidan> _data = [];

  /// Filter daftar: false = Belum Dicatat, true = Sudah Dicatat.
  bool _lihatSudah = false;
  bool _memuat = true;
  String? _gagal;
  Timer? _jam;

  @override
  void initState() {
    super.initState();
    _muat();
    // Cek ulang setiap 30 detik agar pendataan terbuka otomatis saat sesi dimulai.
    _jam = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _jam?.cancel();
    super.dispose();
  }

  /// Waktu mulai sesi bila sesi BELUM dimulai; null bila pendataan sudah boleh.
  DateTime? get _mulaiNanti {
    final j = _jadwal;
    if (j == null) return null;
    final mulai = _waktuMulaiSesi(j.tanggal, j.jam);
    if (mulai == null || !DateTime.now().isBefore(mulai)) return null;
    return mulai;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      var list = <_ItemBidan>[];

      if (j != null) {
        final r = await ApiClient.dio.get(
          '/bidan/jadwal/${j.id}/pengukuran',
          options: Options(
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

        dynamic d = r.data;
        if (d is Map && d.containsKey('data')) d = d['data'];

        if (d is List) {
          list = d
              .map(
                (e) => _ItemBidan.fromApi(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();

          list.sort(
            (a, b) => (a.nomor ?? 1 << 30).compareTo(b.nomor ?? 1 << 30),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _jadwal = j;
        _data = list;
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

  // Ketuk antrean: catatan belum ada -> Catat Pemeriksaan, sudah ada -> Edit Pemeriksaan.
  /// Antrean berikutnya yang harus dicatat: nomor terkecil yang catatannya belum selesai.
  _ItemBidan? get _giliran {
    _ItemBidan? g;
    for (final d in _data) {
      if (d.selesai || d.nomor == null) continue;
      if (g == null || d.nomor! < g.nomor!) g = d;
    }
    return g;
  }

  Future<void> _bukaForm(_ItemBidan d) async {
    final mulai = _mulaiNanti;
    if (mulai != null) {
      _snack('Sesi belum dimulai. Pendataan dapat dilakukan mulai pukul ${_jamMenit(mulai)} WIB');
      return;
    }
    // Pencatatan harus berurutan sesuai nomor antrean.
    final g = _giliran;
    if (!d.selesai && g != null && g.pendaftaranId != d.pendaftaranId) {
      _snack('Catat sesuai urutan. Selesaikan antrean ${g.kodeNomor} terlebih dahulu.');
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => d.selesai
            ? EditPemeriksaanPage(
                pendaftaranId: d.pendaftaranId,
                nomor: d.kodeNomor,
              )
            : CatatPemeriksaanPage(
                pendaftaranId: d.pendaftaranId,
                nomor: d.kodeNomor,
              ),
      ),
    );

    if (ok == true) _muat();
  }

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
  // Tanpa tombol kembali, sama seperti sebelumnya (halaman tab).
  // -------------------------------------------------------------------------
  Widget _header() {
    return Container(
      width: double.infinity,
      color: _hijauHeader,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: _judulTebal('Hasil Pendataan'),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos =
        (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();

    final labelPos = pos.isEmpty
        ? 'Posyandu belum ditetapkan'
        : 'Posyandu ${labelPosyandu(pos)}';

    final j = _jadwal;
    final mulaiNanti = _mulaiNanti;

    // Tanpa filter: daftar dibagi menjadi Belum Dicatat dan Sudah Dicatat.
    // Penilaian 2T / BGM dan status gizi dilihat di halaman Catat / Edit Pemeriksaan.
    final daftar = _data;

    return Scaffold(
      backgroundColor: AppColors.latar,
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
                    if (!_memuat && _gagal == null && mulaiNanti != null)
                      _bannerBelumMulai(mulaiNanti),
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
                            const Icon(
                              Icons.cloud_off,
                              color: AppColors.kuning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _gagal!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16.5,
                                ),
                              ),
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
                    else if (j == null)
                      SectionCard(
                        title: 'Jadwal Posyandu',
                        icon: Icons.event_busy,
                        child: Text(
                          'Belum ada jadwal aktif untuk $labelPos.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.teksRedup,
                          ),
                        ),
                      )
                    else ...[
                      SectionCard(
                        title: 'Sesi Posyandu',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _barisSesi('Tanggal', formatTanggal(j.tanggal)),
                            const SizedBox(height: 4),
                            _barisSesi('Pukul', '${j.jam} WIB'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (daftar.isEmpty)
                        const SectionCard(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Belum ada anak yang check-in',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  color: AppColors.teksRedup,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (daftar.isNotEmpty) ...[
                        _filterCatat(
                          sudah: _lihatSudah,
                          jumlahBelum: daftar.where((d) => !d.selesai).length,
                          jumlahSudah: daftar.where((d) => d.selesai).length,
                          onPilih: (v) => setState(() => _lihatSudah = v),
                        ),
                        if (!daftar.any((d) => d.selesai == _lihatSudah))
                          SectionCard(
                            child: Text(
                              _lihatSudah ? 'Belum ada catatan yang selesai.' : 'Semua anak sudah dicatat.',
                              style: const TextStyle(fontSize: 16, color: AppColors.teksRedup),
                            ),
                          ),
                        for (final d in daftar.where((d) => d.selesai == _lihatSudah)) _kartu(d),
                      ],
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

  /// Kartu antrean: hanya nomor antrean dan status. Nama anak dan status gizi
  /// tidak ditampilkan di daftar; semuanya tetap tampil di halaman Catat / Edit.
  Widget _kartu(_ItemBidan d) {
    final selesai = d.selesai;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selesai ? AppColors.hijauMuda : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _bukaForm(d),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selesai ? const Color(0xFFBFE5D0) : const Color(0xFFE6ECE8)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.kodeNomor,
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (!selesai && _mulaiNanti == null && _giliran?.pendaftaranId == d.pendaftaranId) ...[
                            const SizedBox(height: 4),
                            const Text('Catat sekarang', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu baris keterangan sesi: "Tanggal : 13 November 2026" (titik dua sejajar).
Widget _barisSesi(String label, String nilai) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(label, style: const TextStyle(fontSize: 17, color: AppColors.teksRedup)),
        ),
        const Text(': ', style: TextStyle(fontSize: 17, color: AppColors.teksRedup)),
        Expanded(
          child: Text(nilai, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ],
    );

/// Filter daftar: "Belum Dicatat (n)" | "Sudah Dicatat (n)".
Widget _filterCatat({
  required bool sudah,
  required int jumlahBelum,
  required int jumlahSudah,
  required ValueChanged<bool> onPilih,
}) {
  Widget chip(String label, bool nilai) {
    final aktif = sudah == nilai;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: aktif,
        showCheckmark: false,
        selectedColor: const Color(0xFF065F46),
        backgroundColor: Colors.white,
        side: BorderSide(color: aktif ? const Color(0xFF065F46) : const Color(0xFFE6ECE8)),
        labelStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: aktif ? Colors.white : const Color(0xFF0F172A),
        ),
        onSelected: (_) => onPilih(nilai),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Belum Dicatat ($jumlahBelum)', false),
          chip('Sudah Dicatat ($jumlahSudah)', true),
        ],
      ),
    ),
  );
}