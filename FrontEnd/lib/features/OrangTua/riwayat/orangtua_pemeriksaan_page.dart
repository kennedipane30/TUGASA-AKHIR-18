import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
String _teks(dynamic v) => v?.toString().trim() ?? '';

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

class _Vaksin {
  final String nama;
  final int dosis;
  final String kondisi;
  final String catatan;
  _Vaksin(this.nama, this.dosis, this.kondisi, this.catatan);
}

class _Suplemen {
  final String nama;
  final String dosis;
  final String catatan;
  _Suplemen(this.nama, this.dosis, this.catatan);
}

class _Pemeriksaan {
  final String pendaftaranId;
  final String anakId;
  final String namaAnak;
  final DateTime? tanggal;
  final String jamMulai;

  final bool adaUkur;
  final double? bb;
  final double? tb;
  final String lk;
  final String lila;
  final int usiaBulan;
  final String caraUkur;

  final bool adaCatatan;
  final bool demam;
  final bool diare;
  final bool batuk;
  final String penyakit;
  final String keluhan;
  final String evaluasi;
  final String saranGizi;
  final String saranAsuh;
  final DateTime? kunjunganUlang;

  final List<_Vaksin> vaksin;
  final List<_Suplemen> suplemen;

  _Pemeriksaan({
    required this.pendaftaranId,
    required this.anakId,
    required this.namaAnak,
    required this.tanggal,
    required this.jamMulai,
    required this.adaUkur,
    required this.bb,
    required this.tb,
    required this.lk,
    required this.lila,
    required this.usiaBulan,
    required this.caraUkur,
    required this.adaCatatan,
    required this.demam,
    required this.diare,
    required this.batuk,
    required this.penyakit,
    required this.keluhan,
    required this.evaluasi,
    required this.saranGizi,
    required this.saranAsuh,
    required this.kunjunganUlang,
    required this.vaksin,
    required this.suplemen,
  });

  static const _namaSuplemen = {
    'vitamin_a': 'Vitamin A',
    'obat_cacing': 'Obat cacing',
    'pmt': 'PMT',
  };

  factory _Pemeriksaan.fromApi(Map<String, dynamic> j, Map<String, String> namaVaksin) {
    final u = j['pengukuran'] is Map ? Map<String, dynamic>.from(j['pengukuran'] as Map) : null;
    final c = j['catatan'] is Map ? Map<String, dynamic>.from(j['catatan'] as Map) : null;

    final vaksin = <_Vaksin>[];
    for (final e in (j['imunisasi'] as List? ?? [])) {
      if (e is! Map) continue;
      final id = _teks(e['jenis_vaksin_id']);
      vaksin.add(_Vaksin(
        namaVaksin[id] ?? 'Vaksin',
        int.tryParse(_teks(e['dosis_ke'])) ?? 1,
        _teks(e['kondisi_anak']),
        _teks(e['catatan']),
      ));
    }

    final suplemen = <_Suplemen>[];
    for (final e in (j['suplemen'] as List? ?? [])) {
      if (e is! Map) continue;
      final jenis = _teks(e['jenis']);
      suplemen.add(_Suplemen(
        _namaSuplemen[jenis] ?? jenis,
        _teks(e['keterangan_dosis']),
        _teks(e['catatan']),
      ));
    }

    return _Pemeriksaan(
      pendaftaranId: _teks(j['pendaftaran_id']),
      anakId: _teks(j['anak_id']),
      namaAnak: _teks(j['nama_anak']).isEmpty ? '-' : _teks(j['nama_anak']),
      tanggal: _tgl(j['tanggal']),
      jamMulai: () {
        final s = _teks(j['jam_mulai']);
        return s.length >= 5 ? s.substring(0, 5) : s;
      }(),
      adaUkur: u != null,
      bb: double.tryParse(_teks(u?['bb_kg'])),
      tb: double.tryParse(_teks(u?['tb_cm'])),
      lk: _num(u?['lingkar_kepala_cm']),
      lila: _num(u?['lila_cm']),
      usiaBulan: int.tryParse(_teks(u?['usia_bulan'])) ?? 0,
      caraUkur: _teks(u?['cara_ukur']),
      adaCatatan: c != null,
      demam: c?['demam'] == true,
      diare: c?['diare'] == true,
      batuk: c?['batuk'] == true,
      penyakit: _teks(c?['penyakit_penyerta']),
      keluhan: _teks(c?['keluhan']),
      evaluasi: _teks(c?['catatan_evaluasi']),
      saranGizi: _teks(c?['saran_gizi']),
      saranAsuh: _teks(c?['saran_pola_asuh']),
      kunjunganUlang: _tgl(c?['tanggal_kunjungan_ulang']),
      vaksin: vaksin,
      suplemen: suplemen,
    );
  }
}

// ---------------------------------------------------------------------------
// HALAMAN DAFTAR PEMERIKSAAN (BERDASARKAN TANGGAL)
// ---------------------------------------------------------------------------
class OrangTuaPemeriksaanPage extends StatefulWidget {
  const OrangTuaPemeriksaanPage({super.key});

  @override
  State<OrangTuaPemeriksaanPage> createState() => _OrangTuaPemeriksaanPageState();
}

class _OrangTuaPemeriksaanPageState extends State<OrangTuaPemeriksaanPage> {
  List<_Pemeriksaan> _data = [];
  bool _memuat = true;
  String? _gagal;
  String _anakAktif = ''; // kosong = semua anak

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<Map<String, String>> _muatNamaVaksin() async {
    try {
      final r = await ApiClient.dio.get('/vaksin',
          options: Options(receiveTimeout: const Duration(seconds: 15)));
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      final peta = <String, String>{};
      if (d is List) {
        for (final e in d) {
          if (e is Map) peta[_teks(e['id'])] = _teks(e['nama']);
        }
      }
      return peta;
    } catch (_) {
      return {};
    }
  }

  Future<void> _muat() async {
    try {
      final namaVaksin = await _muatNamaVaksin();
      final r = await ApiClient.dio.get('/riwayat',
          options: Options(receiveTimeout: const Duration(seconds: 15)));
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      final list = <_Pemeriksaan>[];
      if (d is List) {
        for (final e in d) {
          if (e is Map) {
            list.add(_Pemeriksaan.fromApi(Map<String, dynamic>.from(e), namaVaksin));
          }
        }
      }
      list.sort((a, b) {
        final ta = a.tanggal ?? DateTime(1970);
        final tb = b.tanggal ?? DateTime(1970);
        return tb.compareTo(ta);
      });
      if (!mounted) return;
      setState(() {
        _data = list;
        _gagal = null;
        _memuat = false;
        if (_anakAktif.isNotEmpty && !list.any((e) => e.anakId == _anakAktif)) {
          _anakAktif = '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesanError(e);
        _memuat = false;
      });
    }
  }

  void _buka(_Pemeriksaan p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _DetailPemeriksaanPage(data: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anak = <String, String>{};
    for (final p in _data) {
      anak[p.anakId] = p.namaAnak;
    }
    final daftar = _anakAktif.isEmpty
        ? _data
        : _data.where((p) => p.anakId == _anakAktif).toList();

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Riwayat Pemeriksaan',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_memuat)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
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
            else if (_data.isEmpty)
              const SectionCard(
                title: 'Belum ada hasil pemeriksaan',
                icon: Icons.monitor_heart_outlined,
                child: Text(
                  'Hasil pemeriksaan muncul di sini setelah bidan menyimpan catatan pemeriksaan anak Anda di posyandu.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                ),
              )
            else ...[
              if (anak.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('', 'Semua'),
                        for (final e in anak.entries) _chip(e.key, e.value),
                      ],
                    ),
                  ),
                ),
              for (final p in daftar) _kartu(p),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String id, String label) {
    final dipilih = _anakAktif == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: dipilih,
        selectedColor: AppColors.hijau,
        backgroundColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: dipilih ? Colors.white : Colors.black87,
        ),
        onSelected: (_) => setState(() => _anakAktif = id),
      ),
    );
  }

  Widget _kartu(_Pemeriksaan p) {
    final t = p.tanggal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _buka(p),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.hijauMuda,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(t == null ? '-' : t.day.toString().padLeft(2, '0'),
                          style: const TextStyle(
                              color: AppColors.hijau,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                      Text(t == null ? '' : bulanSingkat(t),
                          style: const TextStyle(
                              color: AppColors.hijau,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t == null ? '-' : formatTanggal(t),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(
                        '${p.namaAnak}${p.adaUkur ? ' · ${_usia(p.usiaBulan)}' : ''}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup),
                      ),
                      if (p.adaUkur) ...[
                        const SizedBox(height: 2),
                        Text('BB ${_num(p.bb)} kg · TB ${_num(p.tb)} cm',
                            style: const TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (p.adaCatatan)
                            const Pill('Ada catatan bidan', icon: Icons.sticky_note_2_outlined),
                          if (p.vaksin.isNotEmpty)
                            Pill('${p.vaksin.length} vaksin',
                                bg: AppColors.biruMuda, fg: AppColors.biru),
                          if (p.suplemen.isNotEmpty)
                            Pill('${p.suplemen.length} suplemen',
                                bg: AppColors.kuningMuda, fg: AppColors.kuning),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.teksRedup),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HALAMAN DETAIL PEMERIKSAAN
// ---------------------------------------------------------------------------
class _DetailPemeriksaanPage extends StatelessWidget {
  final _Pemeriksaan data;
  const _DetailPemeriksaanPage({required this.data});

  Widget _blok(String judul, String isi, {IconData icon = Icons.notes}) {
    if (isi.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.hijauMuda,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.hijau),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.hijau)),
                const SizedBox(height: 3),
                Text(isi, style: const TextStyle(fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final t = d.tanggal;
    final gejala = [
      if (d.demam) 'Demam',
      if (d.diare) 'Diare',
      if (d.batuk) 'Batuk',
    ];
    final adaIsiCatatan = d.evaluasi.isNotEmpty ||
        d.saranGizi.isNotEmpty ||
        d.saranAsuh.isNotEmpty ||
        d.keluhan.isNotEmpty ||
        d.penyakit.isNotEmpty ||
        gejala.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Detail Pemeriksaan',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SectionCard(
            title: d.namaAnak,
            icon: Icons.child_care,
            trailing: Pill(t == null ? '-' : formatTanggal(t)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.adaUkur)
                  Text(
                    'Usia ${_usia(d.usiaBulan)}${d.caraUkur.isEmpty ? '' : ' · diukur ${d.caraUkur}'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.teksRedup),
                  ),
                if (d.jamMulai.isNotEmpty)
                  Text('Sesi posyandu pukul ${d.jamMulai} WIB',
                      style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
              ],
            ),
          ),
          if (d.adaUkur)
            SectionCard(
              title: 'Hasil Pengukuran',
              icon: Icons.straighten,
              child: Row(
                children: [
                  Expanded(child: StatBox(nilai: _num(d.bb), label: 'Berat\n(kg)')),
                  const SizedBox(width: 8),
                  Expanded(child: StatBox(nilai: _num(d.tb), label: 'Tinggi/Panjang\n(cm)')),
                  const SizedBox(width: 8),
                  Expanded(child: StatBox(nilai: d.lk, label: 'Lingkar Kepala\n(cm)')),
                  const SizedBox(width: 8),
                  Expanded(child: StatBox(nilai: d.lila, label: 'LiLA\n(cm)')),
                ],
              ),
            ),
          SectionCard(
            title: 'Catatan Bidan',
            icon: Icons.medical_information_outlined,
            child: !d.adaCatatan || !adaIsiCatatan
                ? const Text('Bidan belum menuliskan catatan untuk kunjungan ini.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (gejala.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final g in gejala)
                                Pill(g, bg: AppColors.merahMuda, fg: AppColors.merah),
                            ],
                          ),
                        ),
                      _blok('Penyakit penyerta', d.penyakit, icon: Icons.healing_outlined),
                      _blok('Keluhan', d.keluhan, icon: Icons.sick_outlined),
                      _blok('Evaluasi bidan', d.evaluasi, icon: Icons.fact_check_outlined),
                      _blok('Saran gizi', d.saranGizi, icon: Icons.restaurant_outlined),
                      _blok('Saran pola asuh', d.saranAsuh,
                          icon: Icons.family_restroom_outlined),
                    ],
                  ),
          ),
          if (d.kunjunganUlang != null)
            SectionCard(
              color: AppColors.biruMuda,
              child: Row(
                children: [
                  const Icon(Icons.event_repeat, color: AppColors.biru),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kunjungan ulang',
                            style: TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                        Text(formatTanggal(d.kunjunganUlang!),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (d.vaksin.isNotEmpty)
            SectionCard(
              title: 'Imunisasi Hari Ini',
              icon: Icons.vaccines_outlined,
              child: Column(
                children: [
                  for (final v in d.vaksin)
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
                          Text('${v.nama} · Dosis ${v.dosis}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          if (v.kondisi.isNotEmpty)
                            Text('Kondisi: ${v.kondisi}',
                                style: const TextStyle(fontSize: 11.5)),
                          if (v.catatan.isNotEmpty)
                            Text('Catatan: ${v.catatan}',
                                style: const TextStyle(fontSize: 11.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (d.suplemen.isNotEmpty)
            SectionCard(
              title: 'Suplemen Hari Ini',
              icon: Icons.medication_outlined,
              child: Column(
                children: [
                  for (final s in d.suplemen)
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
                          Text(s.nama,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          if (s.dosis.isNotEmpty)
                            Text('Dosis: ${s.dosis}',
                                style: const TextStyle(fontSize: 11.5)),
                          if (s.catatan.isNotEmpty)
                            Text('Catatan: ${s.catatan}',
                                style: const TextStyle(fontSize: 11.5)),
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
}