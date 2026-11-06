import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../datadiri/data_orang_tua_page.dart' show KeluargaApi, parseTgl;

// Warna tampilan
const _latarHalaman = Color(0xFFF3F5FB);
const _teksGelap = Color(0xFF1E293B);
const _teksAbu = Color(0xFF64748B);
const _hijauTeks = Color(0xFF047857);
const _hijauPil = Color(0xFFDDF5EA);
const _hijauHeader = Color(0xFF065F46);

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

/// Usia dari jumlah bulan (dipakai bila tanggal lahir tidak tersedia).
String _usia(int bln) {
  final th = bln ~/ 12;
  final sisa = bln % 12;
  if (th == 0) return '$bln bulan';
  return sisa == 0 ? '$th tahun' : '$th tahun $sisa bulan';
}

/// Umur dalam bulan penuh pada tanggal [pada] (sama dengan perhitungan server).
int _usiaBulanPenuh(DateTime lahir, DateTime pada) {
  var b = (pada.year - lahir.year) * 12 + pada.month - lahir.month;
  if (pada.day < lahir.day) b--;
  return b < 0 ? 0 : b;
}

DateTime _tambahBulan(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final akhir = DateTime.utc(y, m + 1, 0).day;
  return DateTime.utc(y, m, d.day > akhir ? akhir : d.day);
}

/// Usia detail: "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan", "2 tahun".
String _teksUsia(DateTime lahir, DateTime pada) {
  final a = DateTime.utc(lahir.year, lahir.month, lahir.day);
  final b = DateTime.utc(pada.year, pada.month, pada.day);
  if (b.isBefore(a)) return '0 hari';

  var bulan = (b.year - a.year) * 12 + b.month - a.month;
  if (_tambahBulan(a, bulan).isAfter(b)) bulan--;
  final hari = b.difference(_tambahBulan(a, bulan)).inDays;
  final tahun = bulan ~/ 12;
  final sisa = bulan % 12;

  if (bulan == 0) return '$hari hari';
  if (tahun == 0) return hari == 0 ? '$bulan bulan' : '$bulan bulan $hari hari';
  return sisa == 0 ? '$tahun tahun' : '$tahun tahun $sisa bulan';
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
  final String usiaTeks;
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
    required this.usiaTeks,
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

  factory _Pemeriksaan.fromApi(
    Map<String, dynamic> j,
    Map<String, String> namaVaksin,
    Map<String, DateTime> lahirAnak,
  ) {
    final u = j['pengukuran'] is Map
        ? Map<String, dynamic>.from(j['pengukuran'] as Map)
        : null;
    final c = j['catatan'] is Map
        ? Map<String, dynamic>.from(j['catatan'] as Map)
        : null;

    final vaksin = <_Vaksin>[];
    for (final e in (j['imunisasi'] as List? ?? [])) {
      if (e is! Map) continue;
      final id = _teks(e['jenis_vaksin_id']);
      vaksin.add(
        _Vaksin(
          namaVaksin[id] ?? 'Vaksin',
          int.tryParse(_teks(e['dosis_ke'])) ?? 1,
          _teks(e['kondisi_anak']),
          _teks(e['catatan']),
        ),
      );
    }

    final suplemen = <_Suplemen>[];
    for (final e in (j['suplemen'] as List? ?? [])) {
      if (e is! Map) continue;
      final jenis = _teks(e['jenis']);
      suplemen.add(
        _Suplemen(
          _namaSuplemen[jenis] ?? jenis,
          _teks(e['keterangan_dosis']),
          _teks(e['catatan']),
        ),
      );
    }

    // Usia dihitung dari tanggal lahir anak dan tanggal ukur (bukan angka tersimpan).
    final lahir = lahirAnak[_teks(j['anak_id'])];
    final tglUkur = _tgl(u?['tanggal_ukur']) ?? _tgl(j['tanggal']);
    final usiaTersimpan = int.tryParse(_teks(u?['usia_bulan'])) ?? 0;
    final usiaBulan = (lahir != null && tglUkur != null)
        ? _usiaBulanPenuh(lahir, tglUkur)
        : usiaTersimpan;
    final usiaTeks = (lahir != null && tglUkur != null)
        ? _teksUsia(lahir, tglUkur)
        : _usia(usiaTersimpan);

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
      usiaBulan: usiaBulan,
      usiaTeks: usiaTeks,
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
          BoxShadow(
            color: Color(0x0F1E293B),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Judul kartu polos (tanpa ikon).
class _KepalaKartu extends StatelessWidget {
  final String judul;

  const _KepalaKartu({required this.judul});

  @override
  Widget build(BuildContext context) {
    return Text(
      judul,
      style: const TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w900,
        color: Colors.black,
      ),
    );
  }
}

/// Judul header ekstra tebal (sama seperti halaman Akun).
Widget _judulTebal(String teks) {
  const ukuran = 20.0;
  const jarak = 1.2;

  return Stack(
    children: [
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        ),
      ),
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Color(0x40000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    ],
  );
}

// Header bagian atas: judul di tengah.
Widget _header(
  BuildContext context,
  String judul, {
  String? sub,
}) {
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
    child: Container(
      width: double.infinity,
      color: _hijauHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.maybePop(context),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _judulTebal(judul),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xE6FFFFFF),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// HALAMAN DAFTAR PEMERIKSAAN (BERDASARKAN TANGGAL)
// ---------------------------------------------------------------------------
class OrangTuaPemeriksaanPage extends StatefulWidget {
  final String? anakId;

  const OrangTuaPemeriksaanPage({super.key, this.anakId});

  @override
  State<OrangTuaPemeriksaanPage> createState() =>
      _OrangTuaPemeriksaanPageState();
}

class _OrangTuaPemeriksaanPageState
    extends State<OrangTuaPemeriksaanPage> {
  List<_Pemeriksaan> _data = [];
  bool _memuat = true;
  String? _gagal;
  String _anakAktif = '';

  bool get _terkunci => widget.anakId != null && widget.anakId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<Map<String, String>> _muatNamaVaksin() async {
    try {
      final r = await ApiClient.dio.get(
        '/vaksin',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
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

  Future<Map<String, DateTime>> _muatTanggalLahir() async {
    try {
      final model = KeluargaApi.keModel(await KeluargaApi.ambil());
      final peta = <String, DateTime>{};
      for (final a in model.anak) {
        final lahir = parseTgl(a.tglLahir);
        if (a.id != null && lahir != null) peta[a.id.toString()] = lahir;
      }
      return peta;
    } catch (_) {
      return {};
    }
  }

  Future<void> _muat() async {
    try {
      final namaVaksin = await _muatNamaVaksin();
      final lahirAnak = await _muatTanggalLahir();
      final r = await ApiClient.dio.get(
        '/riwayat',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];

      final list = <_Pemeriksaan>[];
      if (d is List) {
        for (final e in d) {
          if (e is Map) {
            list.add(
              _Pemeriksaan.fromApi(
                Map<String, dynamic>.from(e),
                namaVaksin,
                lahirAnak,
              ),
            );
          }
        }
      }

      list.sort((a, b) {
        final ta = a.tanggal ?? DateTime(1970);
        final tb = b.tanggal ?? DateTime(1970);
        return tb.compareTo(ta);
      });

      if (_terkunci) {
        list.removeWhere((e) => e.anakId != widget.anakId);
      }

      if (!mounted) return;
      setState(() {
        _data = list;
        _gagal = null;
        _memuat = false;
        if (_anakAktif.isNotEmpty &&
            !list.any((e) => e.anakId == _anakAktif)) {
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
      body: Column(
        children: [
          _header(
            context,
            _terkunci && _data.isNotEmpty
                ? 'Riwayat ${_data.first.namaAnak}'
                : 'Riwayat Pemeriksaan',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
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
                                fontSize: 15.5,
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
                  else if (_data.isEmpty)
                    const _Kartu(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _KepalaKartu(judul: 'Belum ada hasil pemeriksaan'),
                          SizedBox(height: 10),
                          Text(
                            'Hasil pemeriksaan muncul di sini setelah bidan menyimpan catatan pemeriksaan anak Anda di posyandu.',
                            style: TextStyle(
                              fontSize: 15,
                              color: _teksAbu,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (!_terkunci && anak.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _chip('', 'Semua'),
                              for (final e in anak.entries)
                                _chip(e.key, e.value),
                            ],
                          ),
                        ),
                      ),
                    for (final p in daftar) _kartu(p),
                  ],
                ],
              ),
            ),
          ),
        ],
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
          fontSize: 15,
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
          BoxShadow(
            color: Color(0x0F1E293B),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _buka(p),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t == null ? '-' : formatTanggal(t),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: _teksGelap,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.namaAnak}${p.adaUkur ? ' · ${p.usiaTeks}' : ''}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          color: _teksAbu,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _hijauTeks,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isi,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: _teksGelap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotakUkur(
    String nilai,
    String label,
    Color bg,
    Color border,
    Color fg,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text(
              nilai,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemSuplemen(String judul, List<String> baris) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5DFA8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _teksGelap,
                  ),
                ),
                for (final b in baris)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
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
      backgroundColor: _latarHalaman,
      body: Column(
        children: [
          _header(context, 'Detail Pemeriksaan'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                // Identitas anak
                _Kartu(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.namaAnak,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _teksGelap,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _hijauPil,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFBDEBD3),
                              ),
                            ),
                            child: Text(
                              t == null ? '-' : formatTanggal(t),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _hijauTeks,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (d.adaUkur)
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 15,
                              color: _teksAbu,
                            ),
                            children: [
                              TextSpan(text: 'Usia ${d.usiaTeks}'),
                              if (d.caraUkur.isNotEmpty) ...[
                                const TextSpan(text: '  ·  '),
                                TextSpan(
                                  text: 'diukur ${d.caraUkur}',
                                  style: const TextStyle(
                                    color: Color(0xFF2B7BB9),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (d.jamMulai.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFEEF1F6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sesi posyandu pukul ${d.jamMulai} WIB',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _teksAbu,
                          ),
                        ),
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
                        const _KepalaKartu(judul: 'Hasil Pengukuran'),
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _kotakUkur(
                                _num(d.bb),
                                'Berat\n(kg)',
                                const Color(0xFFE3F2FD),
                                const Color(0xFFBFDFF7),
                                const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 8),
                              _kotakUkur(
                                _num(d.tb),
                                'Tinggi/\nPanjang (cm)',
                                const Color(0xFFE6F8EF),
                                const Color(0xFFBDEBD3),
                                const Color(0xFF059669),
                              ),
                              const SizedBox(width: 8),
                              _kotakUkur(
                                d.lk,
                                'Lingkar\nKepala (cm)',
                                const Color(0xFFFFF4DC),
                                const Color(0xFFF9E0A8),
                                const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              _kotakUkur(
                                d.lila,
                                'LiLA\n(cm)',
                                const Color(0xFFFDEAF1),
                                const Color(0xFFF6C9D9),
                                const Color(0xFFE11D48),
                              ),
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
                      const _KepalaKartu(judul: 'Catatan Bidan'),
                      const SizedBox(height: 10),
                      if (!d.adaCatatan || !adaIsiCatatan)
                        const SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Bidan belum menuliskan catatan untuk kunjungan ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF2B7BB9),
                            ),
                          ),
                        )
                      else ...[
                        if (gejala.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
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
                          d.penyakit,
                          icon: Icons.healing_outlined,
                        ),
                        _blok(
                          'Keluhan',
                          d.keluhan,
                          icon: Icons.sick_outlined,
                        ),
                        _blok(
                          'Evaluasi bidan',
                          d.evaluasi,
                          icon: Icons.fact_check_outlined,
                        ),
                        _blok(
                          'Saran gizi',
                          d.saranGizi,
                          icon: Icons.restaurant_outlined,
                        ),
                        _blok(
                          'Saran pola asuh',
                          d.saranAsuh,
                          icon: Icons.family_restroom_outlined,
                        ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kunjungan ulang',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: _teksAbu,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatTanggal(d.kunjunganUlang!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: _teksGelap,
                                ),
                              ),
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
                        const _KepalaKartu(judul: 'Imunisasi Hari Ini'),
                        for (final v in d.vaksin)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F7FD),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFDCEAF7),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.nama,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF2B7BB9),
                                        ),
                                      ),
                                      if (v.kondisi.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Kondisi: ${v.kondisi}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF075985),
                                            ),
                                          ),
                                        ),
                                      if (v.catatan.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Catatan: ${v.catatan}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF075985),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD6E9F8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Dosis ${v.dosis}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2B7BB9),
                                    ),
                                  ),
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
                        const _KepalaKartu(judul: 'Suplemen Hari Ini'),
                        for (final s in d.suplemen)
                          _itemSuplemen(s.nama, [
                            if (s.dosis.isNotEmpty) 'Dosis: ${s.dosis}',
                            if (s.catatan.isNotEmpty) 'Catatan: ${s.catatan}',
                          ]),
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