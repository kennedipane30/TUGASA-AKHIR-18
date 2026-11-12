import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/balita_detail_page.dart';
import '../../../core/common_widgets.dart';
import '../../../core/posyandu.dart';
import '../../../core/status_gizi_widget.dart';
import '../../../service/balita_service.dart' show usiaDetail;
import '../../../service/kbm_model.dart';
import '../../auth/auth_provider.dart';
import '../../OrangTua/pendaftaran/orangtua_pendaftaran_page.dart';
import 'bidan_catatan_page.dart';

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
  static const _filter = ['Semua', 'Perlu Catatan', '2T / BGM', 'Selesai'];

  String _aktif = 'Semua';
  JadwalTerdekatData? _jadwal;
  List<_ItemBidan> _data = [];
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

  // Ketuk antrean: tampilkan form catatan bidan.
  Future<void> _bukaForm(_ItemBidan d) async {
    final mulai = _mulaiNanti;
    if (mulai != null) {
      _snack('Sesi belum dimulai. Pendataan dapat dilakukan mulai pukul ${_jamMenit(mulai)} WIB');
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BidanCatatanPage(
          pendaftaranId: d.pendaftaranId,
          nomor: d.kodeNomor,
        ),
      ),
    );

    if (ok == true) _muat();
  }

  // Ketuk ikon: buka detail balita (profil, riwayat penimbangan & kunjungan, vaksin).
  Future<void> _bukaDataAnak(_ItemBidan d) async {
    if (d.anakId.isEmpty) {
      _snack('Data anak tidak ditemukan');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BalitaDetailPage(
          prefix: '/bidan',
          anakId: d.anakId,
          nama: d.nama.isEmpty ? 'Detail Anak' : d.nama,
          bisaKelolaVaksin: true,
          tabAwal: 1,
        ),
      ),
    );
    _muat();
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

    final daftar = switch (_aktif) {
      'Perlu Catatan' => _data.where((d) => !d.selesai).toList(),
      '2T / BGM' => _data.where((d) => d.perluPerhatian).toList(),
      'Selesai' => _data.where((d) => d.selesai).toList(),
      _ => _data,
    };

    final perlu = _data.where((d) => !d.selesai).length;
    final rujuk = _data.where((d) => d.perluPerhatian).length;

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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Pill(
                          labelPos,
                          bg: AppColors.biruMuda,
                          fg: AppColors.biru,
                          icon: Icons.place_outlined,
                        ),
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
                        title: 'Sesi $labelPos',
                        icon: Icons.event_note,
                        trailing: Pill(
                          '$perlu perlu catatan',
                          bg: AppColors.kuningMuda,
                          fg: AppColors.kuning,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatTanggal(j.tanggal)} · ${j.jam} WIB',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            if (j.lokasi.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                j.lokasi,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  color: AppColors.teksRedup,
                                ),
                              ),
                            ],
                            if (rujuk > 0) ...[
                              const SizedBox(height: 8),
                              Pill(
                                '$rujuk anak 2T / BGM perlu diperiksa',
                                bg: AppColors.merahMuda,
                                fg: AppColors.merah,
                                icon: Icons.warning_amber_rounded,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              '${_data.length} anak sudah check-in. Ketuk antrean untuk mengisi catatan, ketuk ikon untuk melihat detail anak.',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.teksRedup,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in _filter)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f),
                                  selected: _aktif == f,
                                  selectedColor: AppColors.hijau,
                                  backgroundColor: Colors.white,
                                  labelStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _aktif == f
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  onSelected: (_) {
                                    setState(() => _aktif = f);
                                  },
                                ),
                              ),
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
                      for (final d in daftar) _kartu(d),
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

  Widget _kartu(_ItemBidan d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _bukaForm(d),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.hijauMuda,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    d.kodeNomor,
                    style: const TextStyle(
                      color: AppColors.hijau,
                      fontWeight: FontWeight.w600,
                      fontSize: 16.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${d.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${d.usia}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.teksRedup,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          d.sudahDiukur
                              ? const Pill(
                                  'Sudah diukur kader',
                                  icon: Icons.straighten,
                                )
                              : const Pill(
                                  'Belum diukur kader',
                                  bg: AppColors.kuningMuda,
                                  fg: AppColors.kuning,
                                ),
                          d.selesai
                              ? const Pill(
                                  'Catatan selesai',
                                  icon: Icons.check,
                                )
                              : const Pill(
                                  'Perlu catatan',
                                  bg: AppColors.biruMuda,
                                  fg: AppColors.biru,
                                ),
                          ...pillPenilaian(d.penilaian, ringkas: true),
                          ...pilGizi(d.statusGizi),
                          if (d.peringatan.isNotEmpty)
                            const Pill(
                              'Ada peringatan',
                              bg: AppColors.merahMuda,
                              fg: AppColors.merah,
                              icon: Icons.warning_amber_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Detail anak',
                  icon: const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppColors.hijau,
                  ),
                  onPressed: () => _bukaDataAnak(d),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}