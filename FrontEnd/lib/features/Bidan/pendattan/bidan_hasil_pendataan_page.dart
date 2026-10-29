import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../core/posyandu.dart';
import '../../auth/auth_provider.dart';
import '../../OrangTua/pendaftaran/orangtua_pendaftaran_page.dart';
import 'bidan_catatan_page.dart';
import 'bidan_data_anak_page.dart';

const _hijauHeader = Color(0xFF0B6043);

class _ItemBidan {
  final String pendaftaranId;
  final String anakId;
  final String nama;
  final String jk;
  final int usiaBulan;
  final int? nomor;
  final bool sudahDiukur;
  final String peringatan;
  final bool selesai;

  _ItemBidan({
    required this.pendaftaranId,
    required this.anakId,
    required this.nama,
    required this.jk,
    required this.usiaBulan,
    required this.nomor,
    required this.sudahDiukur,
    required this.peringatan,
    required this.selesai,
  });

  factory _ItemBidan.fromApi(Map<String, dynamic> j) => _ItemBidan(
        pendaftaranId: j['pendaftaran_id']?.toString() ?? '',
        anakId: j['anak_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        jk: j['jenis_kelamin']?.toString() ?? '',
        usiaBulan: int.tryParse(j['usia_bulan']?.toString() ?? '') ?? 0,
        nomor: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
        sudahDiukur: j['sudah_diukur'] == true,
        peringatan: j['peringatan_validasi']?.toString() ?? '',
        selesai: j['status_catatan']?.toString() == 'selesai',
      );

  String get kodeNomor =>
      nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';

  String get usia => usiaBulan >= 12
      ? '${usiaBulan ~/ 12} th ${usiaBulan % 12} bln'
      : '$usiaBulan bln';
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

class BidanHasilPendataanPage extends StatefulWidget {
  const BidanHasilPendataanPage({super.key});

  @override
  State<BidanHasilPendataanPage> createState() =>
      _BidanHasilPendataanPageState();
}

class _BidanHasilPendataanPageState extends State<BidanHasilPendataanPage> {
  static const _filter = ['Semua', 'Perlu Catatan', 'Selesai'];

  String _aktif = 'Semua';
  JadwalTerdekatData? _jadwal;
  List<_ItemBidan> _data = [];
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
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

  // Ketuk ikon: tampilkan data pencatatan anak (halaman terpisah).
  void _bukaDataAnak(_ItemBidan d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BidanDataAnakPage(
          pendaftaranId: d.pendaftaranId,
          nomor: d.kodeNomor,
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

    final daftar = switch (_aktif) {
      'Perlu Catatan' => _data.where((d) => !d.selesai).toList(),
      'Selesai' => _data.where((d) => d.selesai).toList(),
      _ => _data,
    };

    final perlu = _data.where((d) => !d.selesai).length;

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text(
          'Hasil Pendataan',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: _hijauHeader,
        surfaceTintColor: _hijauHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _hijauHeader,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
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
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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
                    fontSize: 12.5,
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
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (j.lokasi.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        j.lokasi,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.teksRedup,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${_data.length} anak sudah check-in. Ketuk antrean untuk mengisi catatan, ketuk ikon untuk melihat data pencatatan anak.',
                      style: const TextStyle(
                        fontSize: 11.5,
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
                            fontWeight: FontWeight.w700,
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
                  width: 52,
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
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        '${d.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${d.usia}',
                        style: const TextStyle(
                          fontSize: 11,
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
                  tooltip: 'Data pencatatan anak',
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