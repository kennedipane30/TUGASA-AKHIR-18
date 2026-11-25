import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/status_gizi_widget.dart';
import '../datadiri/data_orang_tua_page.dart' show KeluargaApi, parseTgl;

part 'pemeriksaan_detail_page.dart';

// Warna tampilan
const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);
const _teksAbu = Color(0xFF64748B);

/// Garis tepi kotak di dalam kartu: hitam lembut.
const _garis = Color(0xFFB8BEC6);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

const _namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

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

class _Imunisasi {
  final String nama;
  final int dosis;
  final String kondisi;
  final String catatan;

  _Imunisasi(this.nama, this.dosis, this.kondisi, this.catatan);
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

  final List<_Imunisasi> imunisasi;
  final List<_Suplemen> suplemen;
  final Map<String, dynamic>? statusGizi;

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
    required this.imunisasi,
    required this.suplemen,
    required this.statusGizi,
  });

  static const _namaSuplemen = {
    'vitamin_a': 'Vitamin A',
    'obat_cacing': 'Obat cacing',
    'pmt': 'PMT',
  };

  factory _Pemeriksaan.fromApi(
    Map<String, dynamic> j,
    Map<String, String> namaImunisasi,
    Map<String, DateTime> lahirAnak,
  ) {
    final u = j['pengukuran'] is Map
        ? Map<String, dynamic>.from(j['pengukuran'] as Map)
        : null;
    final c = j['catatan'] is Map
        ? Map<String, dynamic>.from(j['catatan'] as Map)
        : null;

    final imunisasi = <_Imunisasi>[];
    for (final e in (j['imunisasi'] as List? ?? [])) {
      if (e is! Map) continue;
      final id = _teks(e['jenis_vaksin_id']);
      final kondisi = switch (_teks(e['kondisi_anak'])) {
        'sehat' => 'Sehat',
        'demam_ringan' => 'Demam ringan',
        final x => x,
      };
      imunisasi.add(
        _Imunisasi(
          namaImunisasi[id] ?? 'Imunisasi',
          int.tryParse(_teks(e['dosis_ke'])) ?? 1,
          kondisi,
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
      // Keluhan dari pendataan kader (data lama: dari catatan bidan).
      keluhan: _teks(u?['keluhan']).isNotEmpty ? _teks(u?['keluhan']) : _teks(c?['keluhan']),
      evaluasi: _teks(c?['catatan_evaluasi']),
      saranGizi: _teks(c?['saran_gizi']),
      saranAsuh: _teks(c?['saran_pola_asuh']),
      kunjunganUlang: _tgl(c?['tanggal_kunjungan_ulang']),
      imunisasi: imunisasi,
      suplemen: suplemen,
      statusGizi: petaGizi(j['status_gizi']),
    );
  }
}

// ---------------------------------------------------------------------------
// KOMPONEN TAMPILAN BERSAMA (seragam dengan halaman lain)
// ---------------------------------------------------------------------------
BoxDecoration _dekorKartu({Color warna = Colors.white}) => BoxDecoration(
      color: warna,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Kepala kartu: judul kapital tebal (dan sub judul) di kiri, keterangan di kanan,
/// lalu garis aksen di bawahnya.
Widget _kepala(String judul, {String? sub, String? kanan}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: _teksGelap,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
                ],
              ),
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(kanan,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Kartu putih berbayang; [judul] opsional.
Widget _kartu({
  String? judul,
  String? sub,
  String? kanan,
  Color warna = Colors.white,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    decoration: _dekorKartu(warna: warna),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (judul != null) _kepala(judul, sub: sub, kanan: kanan),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ],
    ),
  );
}

/// Baris "Label : nilai" (hitam tebal, nilai lanjut ke samping).
Widget _barisInfo(String label, String nilai, {double lebar = 130}) {
  const gaya = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.35, color: _teksGelap);
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: lebar, child: Text(label, style: gaya)),
        const Text(': ', style: gaya),
        Expanded(child: Text(nilai.isEmpty ? '-' : nilai, style: gaya)),
      ],
    ),
  );
}

/// Tautan "Lihat detail" (hijau lembut bergaris bawah).
const _tautanDetail = Text(
  'Lihat detail',
  style: TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: _aksen,
    decoration: TextDecoration.underline,
    decorationColor: _aksen,
  ),
);

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

/// Header hijau polos: tombol kembali di kiri, judul di tengah.
Widget _header(BuildContext context, String judul) {
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
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal(judul),
              ),
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
    ),
  );
}

// ---------------------------------------------------------------------------
// HALAMAN 1: RIWAYAT PEMERIKSAAN (DAFTAR KUNJUNGAN)
// ---------------------------------------------------------------------------
class OrangTuaPemeriksaanPage extends StatefulWidget {
  final String? anakId;

  /// Bila diisi (mis. dari notifikasi), detail pemeriksaan kunjungan ini langsung dibuka.
  final String? pendaftaranId;

  const OrangTuaPemeriksaanPage({super.key, this.anakId, this.pendaftaranId});

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
  bool _sudahBukaAwal = false;

  bool get _terkunci => widget.anakId != null && widget.anakId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<Map<String, String>> _muatNamaImunisasi() async {
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
      final namaImunisasi = await _muatNamaImunisasi();
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
                namaImunisasi,
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
      _bukaAwal();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesanError(e);
        _memuat = false;
      });
    }
  }

  // Dari notifikasi: langsung buka detail kunjungan yang dituju (sekali saja).
  void _bukaAwal() {
    final id = widget.pendaftaranId;
    if (_sudahBukaAwal || id == null || id.isEmpty) return;
    _sudahBukaAwal = true;
    final i = _data.indexWhere((e) => e.pendaftaranId == id);
    if (i < 0) return;
    final p = _data[i];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _buka(p);
    });
  }

  void _buka(_Pemeriksaan p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _DetailRiwayatPage(data: p)),
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
      body: Column(
        children: [
          _header(context, 'Riwayat Pemeriksaan'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_memuat)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_gagal != null)
                    _kartu(
                      warna: AppColors.kuningMuda,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _gagal!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 16, color: _teksGelap),
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
                    _kartu(
                      child: const Text(
                        'Belum ada riwayat pemeriksaan. Hasil muncul di sini setelah anak Anda ditimbang dan diukur di posyandu.',
                        style: TextStyle(fontSize: 15.5, height: 1.4, color: _teksAbu),
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
                              for (final e in anak.entries) _chip(e.key, e.value),
                            ],
                          ),
                        ),
                      ),
                    for (final p in daftar) _kartuRiwayat(p),
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
        selectedColor: _hijauHeader,
        backgroundColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(color: dipilih ? _hijauHeader : _garis, width: 1.2),
        labelStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: dipilih ? Colors.white : _teksGelap,
        ),
        onSelected: (_) => setState(() => _anakAktif = id),
      ),
    );
  }

  /// Kartu satu kunjungan: hari di atas, tanggal di bawah, jam di kanan.
  Widget _kartuRiwayat(_Pemeriksaan p) {
    final t = p.tanggal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: _dekorKartu(),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _buka(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kepala(
                  t == null ? '-' : _namaHari[t.weekday - 1],
                  sub: t == null ? null : formatTanggal(t),
                  kanan: p.jamMulai.isEmpty ? null : '${p.jamMulai} WIB',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _barisInfo('Nama', p.namaAnak, lebar: 70),
                      if (p.adaUkur) _barisInfo('Usia', p.usiaTeks, lebar: 70),
                      if (p.adaUkur)
                        _barisInfo('Hasil',
                            'BB ${_num(p.bb)} kg · TB ${_num(p.tb)} cm',
                            lebar: 70),
                      BarisPilGizi(p.statusGizi),
                      const SizedBox(height: 6),
                      const Align(alignment: Alignment.centerRight, child: _tautanDetail),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}