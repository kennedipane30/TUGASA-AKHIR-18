import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

// Warna tampilan
const _latarHalaman = Color(0xFFF3F5FB);
const _teksGelap = Color(0xFF1E293B);
const _teksAbu = Color(0xFF64748B);
const _hijauTeks = Color(0xFF047857);
const _hijauPil = Color(0xFFDDF5EA);

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
// KOMPONEN TAMPILAN BERSAMA
// ---------------------------------------------------------------------------
class _Kartu extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  const _Kartu({
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E293B), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _KepalaKartu extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String judul;
  const _KepalaKartu({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.judul,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: fg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(judul,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _teksGelap)),
        ),
      ],
    );
  }
}

AppBar _appBar(String judul) => AppBar(
      title: Text(judul,
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 20, color: _teksGelap)),
      backgroundColor: _latarHalaman,
      foregroundColor: _teksGelap,
      elevation: 0,
      scrolledUnderElevation: 0,
    );

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
  String _anakAktif = '';

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
      backgroundColor: _latarHalaman,
      appBar: _appBar('Riwayat Pemeriksaan'),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_memuat)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_gagal != null)
              _Kartu(
                color: AppColors.kuningMuda,
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: AppColors.kuning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_gagal!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
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
              const _Kartu(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KepalaKartu(
                      icon: Icons.monitor_heart_outlined,
                      bg: _hijauPil,
                      fg: _hijauTeks,
                      judul: 'Belum ada hasil pemeriksaan',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Hasil pemeriksaan muncul di sini setelah bidan menyimpan catatan pemeriksaan anak Anda di posyandu.',
                      style: TextStyle(fontSize: 12.5, color: _teksAbu),
                    ),
                  ],
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
        selectedColor: _hijauTeks,
        backgroundColor: Colors.white,
        showCheckmark: false,
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: dipilih ? Colors.white : _teksGelap,
        ),
        onSelected: (_) => setState(() => _anakAktif = id),
      ),
    );
  }

  Widget _kartu(_Pemeriksaan p) {
    final t = p.tanggal;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E293B), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _buka(p),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _hijauPil,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(t == null ? '-' : t.day.toString().padLeft(2, '0'),
                          style: const TextStyle(
                              color: _hijauTeks,
                              fontWeight: FontWeight.w800,
                              fontSize: 19)),
                      Text(t == null ? '' : bulanSingkat(t),
                          style: const TextStyle(
                              color: _hijauTeks,
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
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _teksGelap)),
                      const SizedBox(height: 2),
                      Text(
                        '${p.namaAnak}${p.adaUkur ? ' · ${_usia(p.usiaBulan)}' : ''}',
                        style: const TextStyle(fontSize: 12, color: _teksAbu),
                      ),
                      if (p.adaUkur) ...[
                        const SizedBox(height: 2),
                        Text('BB ${_num(p.bb)} kg · TB ${_num(p.tb)} cm',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _teksGelap)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (p.adaCatatan)
                            const Pill('Ada catatan bidan',
                                icon: Icons.sticky_note_2_outlined),
                          if (p.vaksin.isNotEmpty)
                            Pill('${p.vaksin.length} vaksin',
                                bg: AppColors.biruMuda, fg: AppColors.biru),
                          if (p.suplemen.isNotEmpty)
                            Pill('${p.suplemen.length} suplemen',
                                bg: const Color(0xFFFFEBD6),
                                fg: const Color(0xFFC2410C)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _teksAbu),
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
        color: const Color(0xFFEAF8F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _hijauTeks),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: _hijauTeks)),
                const SizedBox(height: 3),
                Text(isi,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.4, color: _teksGelap)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotakUkur(String nilai, String label, Color bg, Color border, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text(nilai,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 14),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _itemSuplemenVaksin(String judul, List<String> baris) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBD6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF7C99B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFFC2410C))),
          for (final b in baris)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(b,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A3412))),
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
      backgroundColor: _latarHalaman,
      appBar: _appBar('Detail Pemeriksaan'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Identitas anak
          _Kartu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(d.namaAnak,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _teksGelap)),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _hijauPil,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t == null ? '-' : formatTanggal(t),
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _hijauTeks)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (d.adaUkur)
                  Text(
                    'Usia ${_usia(d.usiaBulan)}${d.caraUkur.isEmpty ? '' : ' · diukur ${d.caraUkur}'}',
                    style: const TextStyle(fontSize: 12, color: _teksAbu),
                  ),
                if (d.jamMulai.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Sesi posyandu pukul ${d.jamMulai} WIB',
                      style: const TextStyle(fontSize: 12, color: _teksAbu)),
                ],
              ],
            ),
          ),

          // Hasil pengukuran
          if (d.adaUkur)
            _Kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _KepalaKartu(
                    icon: Icons.straighten,
                    bg: Color(0xFFDDF5EA),
                    fg: _hijauTeks,
                    judul: 'Hasil Pengukuran',
                  ),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kotakUkur(_num(d.bb), 'Berat\n(kg)',
                            const Color(0xFFE3F2FD), const Color(0xFFBFDFF7),
                            const Color(0xFF0369A1)),
                        const SizedBox(width: 8),
                        _kotakUkur(_num(d.tb), 'Tinggi/\nPanjang\n(cm)',
                            const Color(0xFFE6F8EF), const Color(0xFFBDEBD3),
                            const Color(0xFF047857)),
                        const SizedBox(width: 8),
                        _kotakUkur(d.lk, 'Lingkar\nKepala\n(cm)',
                            const Color(0xFFFFF1E3), const Color(0xFFF9D3AE),
                            const Color(0xFFEA580C)),
                        const SizedBox(width: 8),
                        _kotakUkur(d.lila, 'LiLA\n(cm)',
                            const Color(0xFFFDEAF1), const Color(0xFFF6C9D9),
                            const Color(0xFFE11D48)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Catatan bidan
          _Kartu(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _KepalaKartu(
                  icon: Icons.assignment_outlined,
                  bg: Color(0xFFE8EAFE),
                  fg: Color(0xFF4F46E5),
                  judul: 'Catatan Bidan',
                ),
                const SizedBox(height: 12),
                if (!d.adaCatatan || !adaIsiCatatan)
                  const Text('Bidan belum menuliskan catatan untuk kunjungan ini.',
                      style: TextStyle(fontSize: 12, color: _teksAbu))
                else ...[
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
              ],
            ),
          ),

          // Kunjungan ulang
          if (d.kunjunganUlang != null)
            _Kartu(
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
                            style: TextStyle(fontSize: 11, color: _teksAbu)),
                        Text(formatTanggal(d.kunjunganUlang!),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _teksGelap)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Imunisasi
          if (d.vaksin.isNotEmpty)
            _Kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _KepalaKartu(
                    icon: Icons.vaccines_outlined,
                    bg: Color(0xFFE3F2FD),
                    fg: Color(0xFF0369A1),
                    judul: 'Imunisasi Hari Ini',
                  ),
                  for (final v in d.vaksin)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDFF7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${v.nama} · Dosis ${v.dosis}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF0369A1))),
                          if (v.kondisi.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Kondisi: ${v.kondisi}',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Color(0xFF075985))),
                            ),
                          if (v.catatan.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Catatan: ${v.catatan}',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Color(0xFF075985))),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Suplemen
          if (d.suplemen.isNotEmpty)
            _Kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _KepalaKartu(
                    icon: Icons.medication_outlined,
                    bg: Color(0xFFFFEBD6),
                    fg: Color(0xFFEA580C),
                    judul: 'Suplemen Hari Ini',
                  ),
                  for (final s in d.suplemen)
                    _itemSuplemenVaksin(s.nama, [
                      if (s.dosis.isNotEmpty) 'Dosis: ${s.dosis}',
                      if (s.catatan.isNotEmpty) 'Catatan: ${s.catatan}',
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}