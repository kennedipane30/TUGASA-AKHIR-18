import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../service/kbm_model.dart';
import '../../../service/imunisasi_service.dart' show usiaDariLahir;
import '../../OrangTua/pendaftaran/pendaftaran_page.dart';
import 'catat_pengukuran_page.dart';
import 'edit_pengukuran_page.dart';

const hijauHeaderPendataan = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi field & kotak di dalam kartu: hitam lembut.
const _garis = Color(0xFFB8BEC6);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

BoxDecoration _dekorKartu({Color warna = Colors.white}) => BoxDecoration(
      color: warna,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Kepala kartu: judul kapital tebal di kiri, keterangan di kanan, garis aksen di bawah.
Widget _kepala(String judul, {String? kanan}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
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
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                kanan,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: _teksGelap,
                ),
              ),
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
        if (judul != null) _kepala(judul, kanan: kanan),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------

class AntreanKader {
  final String pendaftaranId;
  final String anakId;
  final String nama;
  final String jk;
  final DateTime? tanggalLahir;
  final int usiaBulan;
  final int? nomor;
  final String sumber;
  final bool sudahDiukur;
  final bool sudahDicatatBidan;
  final PenilaianTimbang? penilaian;

  AntreanKader({
    required this.pendaftaranId,
    required this.anakId,
    required this.nama,
    required this.jk,
    required this.tanggalLahir,
    required this.usiaBulan,
    required this.nomor,
    required this.sumber,
    required this.sudahDiukur,
    required this.sudahDicatatBidan,
    this.penilaian,
  });

  factory AntreanKader.fromApi(Map<String, dynamic> j) => AntreanKader(
        pendaftaranId: j['pendaftaran_id']?.toString() ?? '',
        anakId: j['anak_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        jk: j['jenis_kelamin']?.toString() ?? '',
        tanggalLahir: _tglLahir(j['tanggal_lahir']),
        usiaBulan: int.tryParse(j['usia_bulan']?.toString() ?? '') ?? 0,
        nomor: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
        sumber: j['sumber']?.toString() ?? '',
        sudahDiukur: j['sudah_diukur'] == true,
        sudahDicatatBidan: j['sudah_dicatat_bidan'] == true,
        penilaian: PenilaianTimbang.dari(j['penilaian']),
      );

  String get kodeNomor =>
      nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';

  /// Usia detail, mis. "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan".
  String get usia {
    final lahir = tanggalLahir;
    if (lahir != null) return usiaDariLahir(lahir, DateTime.now());
    final th = usiaBulan ~/ 12;
    final bl = usiaBulan % 12;
    if (th == 0) return '$usiaBulan bulan';
    return bl == 0 ? '$th tahun' : '$th tahun $bl bulan';
  }

  /// GET /kader/jadwal/:id/antrean (anak yang sudah check-in lewat scan orang tua),
  /// diurutkan berdasarkan nomor antrean.
  static Future<List<AntreanKader>> ambil(String jadwalId) async {
    final r = await ApiClient.dio.get(
      '/kader/jadwal/$jadwalId/antrean',
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    dynamic d = r.data;
    if (d is Map && d.containsKey('data')) d = d['data'];
    if (d is! List) return [];

    final list = d
        .map(
          (e) => AntreanKader.fromApi(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    list.sort(
      (a, b) => (a.nomor ?? 1 << 30).compareTo(b.nomor ?? 1 << 30),
    );

    return list;
  }
}

String pesanErrorPendataan(Object e) {
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
    decoration: _dekorKartu(warna: AppColors.kuningMuda),
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

DateTime? _tglLahir(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

/// Judul header (gaya teks sama dengan halaman lain).
Widget judulHeaderPendataan(String teks) {
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
// HALAMAN ANTREAN PENDATAAN (KADER)
// ---------------------------------------------------------------------------

class KaderPendataanPage extends StatefulWidget {
  const KaderPendataanPage({super.key});

  @override
  State<KaderPendataanPage> createState() => _KaderPendataanPageState();
}

class _KaderPendataanPageState extends State<KaderPendataanPage> {
  JadwalTerdekatData? _jadwal;
  List<AntreanKader> _antrean = [];

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

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      final list =
          j == null ? <AntreanKader>[] : await AntreanKader.ambil(j.id);

      if (!mounted) return;

      setState(() {
        _jadwal = j;
        _antrean = list;
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _gagal = pesanErrorPendataan(e);
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

  /// Antrean berikutnya yang harus diukur: nomor terkecil yang belum diukur.
  AntreanKader? get _giliran {
    AntreanKader? g;
    for (final a in _antrean) {
      if (a.sudahDiukur || a.nomor == null) continue;
      if (g == null || a.nomor! < g.nomor!) g = a;
    }
    return g;
  }

  Future<void> _ukur(AntreanKader a) async {
    final mulai = _mulaiNanti;
    if (mulai != null) {
      _snack('Sesi belum dimulai. Pendataan dapat dilakukan mulai pukul ${_jamMenit(mulai)} WIB');
      return;
    }
    // Pengukuran harus berurutan sesuai nomor antrean.
    final g = _giliran;
    if (!a.sudahDiukur && g != null && g.pendaftaranId != a.pendaftaranId) {
      _snack('Catat sesuai urutan. Selesaikan antrean ${g.kodeNomor} terlebih dahulu.');
      return;
    }
    if (a.sudahDicatatBidan) {
      _snack('Antrean ${a.kodeNomor} sudah dicatat bidan dan tidak dapat diubah');
      return;
    }

    // Belum diukur: halaman Catat. Sudah diukur: halaman Edit.
    final hasil = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => a.sudahDiukur
            ? EditPengukuranPage(anak: a)
            : CatatPengukuranPage(anak: a),
      ),
    );

    if (hasil != null) {
      await _muat();
      if (!mounted) return;
      AntreanKader? baru;
      for (final x in _antrean) {
        if (x.pendaftaranId == a.pendaftaranId) baru = x;
      }
      final p = baru?.penilaian;
      if (p == null) {
        _snack(
          hasil.isEmpty
              ? 'Data pengukuran tersimpan dan diteruskan ke bidan'
              : 'Data tersimpan dan diteruskan ke bidan. Perhatian: $hasil',
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Hasil Penimbangan · ${a.kodeNomor}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KotakPenilaian(p: p),
                if (hasil.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Perhatian: $hasil', style: const TextStyle(fontSize: 16.5, color: AppColors.kuning)),
                ],
                const SizedBox(height: 10),
                const Text('Data tersimpan dan diteruskan ke bidan.',
                    style: TextStyle(fontSize: 16.5, color: AppColors.teksRedup)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ],
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Imunisasi Anak: polos, judul di tengah)
  // -------------------------------------------------------------------------
  Widget _header() {
    return Container(
      width: double.infinity,
      color: hijauHeaderPendataan,
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
                child: judulHeaderPendataan('Pendataan'),
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
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final j = _jadwal;
    final mulaiNanti = _mulaiNanti;

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
                    // Pesan "sesi belum dimulai" hanya muncul bila sudah ada anak yang check-in.
                    if (!_memuat && _gagal == null && mulaiNanti != null && _antrean.isNotEmpty)
                      _bannerBelumMulai(mulaiNanti),
                    if (_memuat)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_gagal != null)
                      _kartu(
                        warna: AppColors.kuningMuda,
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
                      _kartu(
                        judul: 'Jadwal Posyandu',
                        child: const Text(
                          'Belum ada jadwal posyandu aktif. Antrean pendataan muncul setelah admin menerbitkan jadwal.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.teksRedup,
                          ),
                        ),
                      )
                    else ...[
                      // Kartu Sesi Posyandu disembunyikan.
                      if (_antrean.isEmpty)
                        _kartu(
                          child: const Text(
                            'Belum ada anak. Data anak masuk ke sini setelah orang tua melakukan check-in dengan scan QR.',
                            style: TextStyle(fontSize: 16, color: AppColors.teksRedup),
                          ),
                        )
                      else ...[
                        _filterCatat(
                          sudah: _lihatSudah,
                          jumlahBelum: _antrean.where((a) => !a.sudahDiukur).length,
                          jumlahSudah: _antrean.where((a) => a.sudahDiukur).length,
                          onPilih: (v) => setState(() => _lihatSudah = v),
                        ),
                        if (!_antrean.any((a) => a.sudahDiukur == _lihatSudah))
                          _kartu(
                            child: Text(
                              _lihatSudah ? 'Belum ada anak yang dicatat.' : 'Semua anak sudah dicatat.',
                              style: const TextStyle(fontSize: 16, color: AppColors.teksRedup),
                            ),
                          ),
                        for (final a in _antrean.where((a) => a.sudahDiukur == _lihatSudah)) _baris(a),
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

  /// Kartu antrean: hanya nomor antrean dan status (nama anak tidak
  /// ditampilkan di daftar; tetap tampil di halaman Catat / Edit).
  Widget _baris(AntreanKader a) {
    final belumMulai = _mulaiNanti != null;
    final selesai = a.sudahDiukur;
    final giliran = !selesai && !belumMulai && _giliran?.pendaftaranId == a.pendaftaranId;
    final status = a.sudahDicatatBidan
        ? 'Sudah dicatat bidan'
        : selesai
            ? 'Sudah diukur'
            : giliran
                ? 'Catat sekarang'
                : 'Menunggu giliran';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: _dekorKartu(),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _ukur(a),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: giliran
                        ? hijauHeaderPendataan
                        : (selesai ? _aksen : Colors.transparent),
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.kodeNomor,
                          style: const TextStyle(
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: _teksGelap,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: (selesai || giliran) ? hijauHeaderPendataan : AppColors.teksRedup,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!a.sudahDicatatBidan)
                    Text(
                      selesai ? 'Ubah' : 'Catat',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: _aksen,
                        decoration: TextDecoration.underline,
                        decorationColor: _aksen,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        side: BorderSide(color: aktif ? const Color(0xFF065F46) : _garis, width: 1.2),
        labelStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: aktif ? Colors.white : _teksGelap,
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