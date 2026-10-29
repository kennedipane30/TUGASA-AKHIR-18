import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

const _hijauHeader = Color(0xFF0B6043);

String _t(dynamic v) => v?.toString().trim() ?? '';

String _num(dynamic v) {
  final d = double.tryParse(v?.toString() ?? '');
  if (d == null) return '-';
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
}

DateTime? _tgl(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

String _fmt(dynamic v) {
  final d = _tgl(v);
  return d == null ? '-' : formatTanggal(d);
}

String _usia(int bln) =>
    bln >= 12 ? '${bln ~/ 12} th ${bln % 12} bln' : '$bln bln';

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

/// Bidan: data pencatatan satu anak pada sesi posyandu
/// (identitas, hasil ukur kader, kunjungan sebelumnya, catatan bidan,
/// dan riwayat imunisasi).
class BidanDataAnakPage extends StatefulWidget {
  final String pendaftaranId;
  final String nomor;

  const BidanDataAnakPage({
    super.key,
    required this.pendaftaranId,
    required this.nomor,
  });

  @override
  State<BidanDataAnakPage> createState() => _BidanDataAnakPageState();
}

class _BidanDataAnakPageState extends State<BidanDataAnakPage> {
  Map<String, dynamic>? _d;
  Map<String, String> _namaVaksin = {};
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final opsi = Options(
        receiveTimeout: const Duration(seconds: 15),
      );

      final r = await ApiClient.dio.get(
        '/bidan/pendaftaran/${widget.pendaftaranId}',
        options: opsi,
      );

      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];

      final peta = <String, String>{};

      try {
        final rv = await ApiClient.dio.get(
          '/vaksin',
          options: opsi,
        );

        dynamic v = rv.data;
        if (v is Map && v.containsKey('data')) v = v['data'];

        if (v is List) {
          for (final e in v) {
            if (e is Map) {
              peta[_t(e['id'])] = _t(e['nama']);
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _d = Map<String, dynamic>.from(d as Map);
        _namaVaksin = peta;
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

  Map<String, dynamic>? _peta(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  Widget _baris(String l, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                l,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.teksRedup,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v.isEmpty ? '-' : v,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _blok(
    String judul,
    String isi, {
    Color bg = AppColors.hijauMuda,
  }) {
    if (isi.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isi,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ukuran(String judul, Map<String, dynamic> u) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatBox(
                nilai: _num(u['bb_kg']),
                label: 'BB (kg)',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: StatBox(
                nilai: _num(u['tb_cm']),
                label: 'TB (cm)',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: StatBox(
                nilai: _num(u['lingkar_kepala_cm']),
                label: 'LK (cm)',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: StatBox(
                nilai: _num(u['lila_cm']),
                label: 'LiLA (cm)',
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: Text(
          'Data Anak · ${widget.nomor}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
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
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : _gagal != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _gagal!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          'Coba Lagi',
                          icon: Icons.refresh,
                          onPressed: () {
                            setState(() => _memuat = true);
                            _muat();
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _muat,
                  child: _isi(),
                ),
    );
  }

  Widget _isi() {
    final d = _d!;
    final anak = _peta(d['anak']) ?? {};
    final ukur = _peta(d['pengukuran']);
    final prev = _peta(d['pengukuran_sebelumnya']);
    final cat = _peta(d['catatan']);
    final usia = int.tryParse(_t(d['usia_bulan'])) ?? 0;
    final jk = _t(anak['jenis_kelamin']) == 'P' ? 'Perempuan' : 'Laki-laki';
    final peringatan = _t(ukur?['peringatan_validasi']);
    final riwayat = (d['riwayat_imunisasi'] as List?) ?? [];
    final imunHariIni = (d['imunisasi'] as List?) ?? [];
    final suplemen = (d['suplemen'] as List?) ?? [];

    final gejala = [
      if (cat?['demam'] == true) 'Demam',
      if (cat?['diare'] == true) 'Diare',
      if (cat?['batuk'] == true) 'Batuk',
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: _t(anak['nama']).isEmpty ? '-' : _t(anak['nama']),
          icon: Icons.child_care,
          trailing: Pill('Antrean ${widget.nomor}'),
          child: Column(
            children: [
              _baris('Jenis kelamin', jk),
              _baris('Tanggal lahir', _fmt(anak['tanggal_lahir'])),
              _baris('Usia', _usia(usia)),
              _baris('NIK anak', _t(anak['nik'])),
              _baris(
                'Berat lahir',
                _t(anak['berat_lahir_kg']).isEmpty
                    ? ''
                    : '${_num(anak['berat_lahir_kg'])} kg',
              ),
              _baris(
                'Panjang lahir',
                _t(anak['panjang_lahir_cm']).isEmpty
                    ? ''
                    : '${_num(anak['panjang_lahir_cm'])} cm',
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Hasil Pengukuran Kader',
          icon: Icons.straighten,
          trailing: ukur == null
              ? const Pill(
                  'Belum diukur',
                  bg: AppColors.kuningMuda,
                  fg: AppColors.kuning,
                )
              : const Pill(
                  'Tercatat',
                  icon: Icons.check,
                ),
          child: ukur == null
              ? const Text(
                  'Kader belum mencatat pengukuran anak ini.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.teksRedup,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ukuran('Hari ini', ukur),
                    const SizedBox(height: 10),
                    _baris('Cara ukur', _t(ukur['cara_ukur'])),
                    _baris(
                      'ASI eksklusif',
                      ukur['asi_eksklusif'] == true ? 'Ya' : 'Tidak',
                    ),
                    _baris(
                      'Sedang sakit',
                      ukur['sedang_sakit'] == true ? 'Ya' : 'Tidak',
                    ),
                    _blok(
                      'Keluhan (kader)',
                      _t(ukur['keluhan']),
                      bg: AppColors.latar,
                    ),
                    _blok(
                      'Catatan kader',
                      _t(ukur['catatan']),
                      bg: AppColors.latar,
                    ),
                    _blok(
                      'Peringatan validasi',
                      peringatan,
                      bg: AppColors.merahMuda,
                    ),
                  ],
                ),
        ),
        if (prev != null)
          SectionCard(
            title: 'Kunjungan Sebelumnya',
            icon: Icons.history,
            trailing: Text(
              _fmt(prev['tanggal_ukur']),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.teksRedup,
              ),
            ),
            child: _ukuran('Sebelumnya', prev),
          ),
        SectionCard(
          title: 'Catatan Bidan',
          icon: Icons.medical_information_outlined,
          trailing: cat == null
              ? const Pill(
                  'Belum ada',
                  bg: AppColors.biruMuda,
                  fg: AppColors.biru,
                )
              : const Pill(
                  'Tersimpan',
                  icon: Icons.check,
                ),
          child: cat == null
              ? const Text(
                  'Catatan bidan belum diisi. Ketuk antrean untuk mengisi.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.teksRedup,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gejala.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final g in gejala)
                              Pill(
                                g,
                                bg: AppColors.merahMuda,
                                fg: AppColors.merah,
                              ),
                          ],
                        ),
                      ),
                    _blok(
                      'Penyakit penyerta',
                      _t(cat['penyakit_penyerta']),
                    ),
                    _blok('Keluhan', _t(cat['keluhan'])),
                    _blok('Evaluasi', _t(cat['catatan_evaluasi'])),
                    _blok('Saran gizi', _t(cat['saran_gizi'])),
                    _blok('Saran pola asuh', _t(cat['saran_pola_asuh'])),
                    if (_tgl(cat['tanggal_kunjungan_ulang']) != null)
                      _baris(
                        'Kunjungan ulang',
                        _fmt(cat['tanggal_kunjungan_ulang']),
                      ),
                  ],
                ),
        ),
        if (imunHariIni.isNotEmpty || suplemen.isNotEmpty)
          SectionCard(
            title: 'Diberikan Hari Ini',
            icon: Icons.vaccines_outlined,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in imunHariIni)
                  if (e is Map)
                    Pill(
                      '${_namaVaksin[_t(e['jenis_vaksin_id'])] ?? 'Vaksin'} dosis ${_t(e['dosis_ke'])}',
                      bg: AppColors.biruMuda,
                      fg: AppColors.biru,
                      icon: Icons.vaccines,
                    ),
                for (final e in suplemen)
                  if (e is Map)
                    Pill(
                      _t(e['jenis']).replaceAll('_', ' '),
                      bg: AppColors.kuningMuda,
                      fg: AppColors.kuning,
                    ),
              ],
            ),
          ),
        SectionCard(
          title: 'Riwayat Imunisasi',
          icon: Icons.history,
          trailing: Pill(
            '${riwayat.length}',
            bg: AppColors.hijauMuda,
            fg: AppColors.hijau,
          ),
          child: riwayat.isEmpty
              ? const Text(
                  'Belum ada riwayat imunisasi.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.teksRedup,
                  ),
                )
              : Column(
                  children: [
                    for (final e in riwayat)
                      if (e is Map)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.latar,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_namaVaksin[_t(e['jenis_vaksin_id'])] ?? 'Vaksin'} · Dosis ${_t(e['dosis_ke'])}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _fmt(e['tanggal_pemberian']),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.teksRedup,
                                ),
                              ),
                              if (_t(e['kondisi_anak']).isNotEmpty)
                                Text(
                                  'Kondisi: ${_t(e['kondisi_anak'])}',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                            ],
                          ),
                        ),
                  ],
                ),
        ),
      ],
    );
  }
}