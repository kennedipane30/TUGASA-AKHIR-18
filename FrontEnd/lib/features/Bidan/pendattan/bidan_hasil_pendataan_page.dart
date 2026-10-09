import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../OrangTua/pendaftaran/orangtua_pendaftaran_page.dart';
import 'bidan_catatan_page.dart';

class _ItemBidan {
  final String pendaftaranId;
  final String anakId;
  final String nama;
  final String jk;
  final int usiaBulan;
  final int? nomor;
  final double bb;
  final double tb;
  final String peringatan;
  final bool selesai;

  _ItemBidan({
    required this.pendaftaranId,
    required this.anakId,
    required this.nama,
    required this.jk,
    required this.usiaBulan,
    required this.nomor,
    required this.bb,
    required this.tb,
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
        bb: double.tryParse(j['bb_kg']?.toString() ?? '') ?? 0,
        tb: double.tryParse(j['tb_cm']?.toString() ?? '') ?? 0,
        peringatan: j['peringatan_validasi']?.toString() ?? '',
        selesai: j['status_catatan']?.toString() == 'selesai',
      );

  String get kodeNomor => nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';
  String get usia => usiaBulan >= 12 ? '${usiaBulan ~/ 12} th ${usiaBulan % 12} bln' : '$usiaBulan bln';
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
  State<BidanHasilPendataanPage> createState() => _BidanHasilPendataanPageState();
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
        final r = await ApiClient.dio.get('/bidan/jadwal/${j.id}/pengukuran',
            options: Options(receiveTimeout: const Duration(seconds: 15)));
        dynamic d = r.data;
        if (d is Map && d.containsKey('data')) d = d['data'];
        if (d is List) {
          list = d
              .map((e) => _ItemBidan.fromApi(Map<String, dynamic>.from(e as Map)))
              .toList();
          list.sort((a, b) => (a.nomor ?? 1 << 30).compareTo(b.nomor ?? 1 << 30));
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

  Future<void> _buka(_ItemBidan d) async {
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

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Hasil Pendataan', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
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
            else if (j == null)
              SectionCard(
                title: 'Jadwal Posyandu',
                icon: Icons.event_busy,
                child: const Text(
                  'Belum ada jadwal posyandu aktif.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                ),
              )
            else ...[
              SectionCard(
                title: 'Sesi Posyandu',
                icon: Icons.event_note,
                trailing: Pill('$perlu perlu catatan',
                    bg: AppColors.kuningMuda, fg: AppColors.kuning),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatTanggal(j.tanggal)} · ${j.jam} WIB',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    if (j.lokasi.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(j.lokasi,
                          style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Hanya anak yang sudah didata kader yang muncul di sini.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.teksRedup),
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
                              color: _aktif == f ? Colors.white : Colors.black87),
                          onSelected: (_) => setState(() => _aktif = f),
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
                      child: Text('Belum ada data dari kader',
                          style: TextStyle(color: AppColors.teksRedup)),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _buka(d),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.hijauMuda,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(d.kodeNomor,
                          style: const TextStyle(
                              color: AppColors.hijau,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nama,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13.5)),
                          Text('${d.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${d.usia}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.teksRedup)),
                        ],
                      ),
                    ),
                    d.selesai
                        ? const Pill('Selesai', icon: Icons.check)
                        : const Pill('Perlu catatan',
                            bg: AppColors.kuningMuda, fg: AppColors.kuning),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: StatBox(
                            nilai: d.bb.toString(), label: 'BB (kg)', bg: AppColors.latar)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: StatBox(
                            nilai: d.tb.toString(), label: 'TB (cm)', bg: AppColors.latar)),
                  ],
                ),
                if (d.peringatan.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.merahMuda,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.merah, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(d.peringatan, style: const TextStyle(fontSize: 11.5))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}