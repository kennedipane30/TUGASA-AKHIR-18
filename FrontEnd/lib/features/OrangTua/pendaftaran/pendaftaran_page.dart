import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../riwayat/pemeriksaan_page.dart' show OrangTuaPemeriksaanPage;
import 'kartu_antrean_page.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------

/// Satu item rencana pelayanan: imunisasi, Vitamin A, atau obat cacing.
class RencanaItemJadwal {
  final String jenis; // imunisasi | vitamin_a | obat_cacing
  final String kode;
  final String jenisVaksinId; // hanya untuk imunisasi
  final String nama;
  final int dosisKe;
  final String keterangan;
  final bool terlambat;

  RencanaItemJadwal({
    required this.jenis,
    required this.kode,
    this.jenisVaksinId = '',
    required this.nama,
    required this.dosisKe,
    required this.keterangan,
    required this.terlambat,
  });

  factory RencanaItemJadwal.fromApi(Map<String, dynamic> j) => RencanaItemJadwal(
        jenis: j['jenis']?.toString() ?? '',
        kode: j['kode']?.toString() ?? '',
        jenisVaksinId: j['jenis_vaksin_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        dosisKe: int.tryParse(j['dosis_ke']?.toString() ?? '') ?? 0,
        keterangan: j['keterangan']?.toString() ?? '',
        terlambat: j['terlambat'] == true,
      );
}

/// Rencana imunisasi & suplemen anak pada jadwal posyandu (dihitung server).
class RencanaAnakJadwal {
  final List<RencanaItemJadwal> imunisasi;
  final List<RencanaItemJadwal> suplemen;
  final List<RencanaItemJadwal> keFaskes;

  RencanaAnakJadwal({
    required this.imunisasi,
    required this.suplemen,
    required this.keFaskes,
  });

  static List<RencanaItemJadwal> _daftar(dynamic v) => ((v as List?) ?? [])
      .whereType<Map>()
      .map((e) => RencanaItemJadwal.fromApi(Map<String, dynamic>.from(e)))
      .toList();

  factory RencanaAnakJadwal.fromApi(Map<String, dynamic> j) => RencanaAnakJadwal(
        imunisasi: _daftar(j['imunisasi']),
        suplemen: _daftar(j['suplemen']),
        keFaskes: _daftar(j['ke_faskes']),
      );

  bool get kosong => imunisasi.isEmpty && suplemen.isEmpty && keFaskes.isEmpty;
}

class AnakStatusJadwal {
  final String anakId;
  final String nama;
  final String status; // belum_daftar | terdaftar | sudah_checkin | tidak_hadir
  final int? nomorAntrean;
  final bool bolehDaftar;
  final bool bolehBatal;
  final bool bolehCheckin;
  final RencanaAnakJadwal? rencana;

  /// Posisi dalam pelayanan (dari server): belum_daftar | belum_checkin | menunggu_kader |
  /// menunggu_bidan | selesai | tidak_dilayani | tidak_hadir.
  final String tahap;

  /// Id pendaftaran (ada bila anak sudah terdaftar); dipakai membuka hasil pemeriksaan.
  final String pendaftaranId;

  AnakStatusJadwal({
    required this.anakId,
    required this.nama,
    required this.status,
    required this.nomorAntrean,
    required this.bolehDaftar,
    required this.bolehBatal,
    required this.bolehCheckin,
    this.rencana,
    this.tahap = '',
    this.pendaftaranId = '',
  });

  /// Bidan sudah menyimpan catatan pemeriksaan = selesai dilayani.
  bool get selesai => status == 'sudah_checkin' && tahap == 'selesai';

  /// Sudah check-in, jadwal berakhir sebelum bidan mencatat.
  bool get tidakDilayani => status == 'sudah_checkin' && tahap == 'tidak_dilayani';

  /// Status yang ditampilkan: untuk anak yang sudah check-in mengikuti tahap pelayanan.
  String get statusTampil => (status == 'sudah_checkin' && tahap.isNotEmpty) ? tahap : status;

  factory AnakStatusJadwal.fromApi(Map<String, dynamic> j) =>
      AnakStatusJadwal(
        anakId: j['anak_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        status: j['status_kehadiran']?.toString() ?? 'belum_daftar',
        nomorAntrean: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
        bolehDaftar: j['boleh_daftar'] == true,
        bolehBatal: j['boleh_batal'] == true,
        bolehCheckin: j['boleh_checkin'] == true,
        tahap: j['tahap']?.toString() ?? '',
        pendaftaranId: j['kartu'] is Map ? (j['kartu']['pendaftaran_id']?.toString() ?? '') : '',
        rencana: j['rencana'] is Map
            ? RencanaAnakJadwal.fromApi(Map<String, dynamic>.from(j['rencana'] as Map))
            : null,
      );
}

class JadwalTerdekatData {
  final String id;
  final DateTime tanggal;
  final String jamMulai;
  final String jamSelesai;
  final String lokasi;
  final DateTime? pendaftaranBuka;
  final DateTime? checkinBuka;
  final List<AnakStatusJadwal> anak;

  JadwalTerdekatData({
    required this.id,
    required this.tanggal,
    required this.jamMulai,
    required this.jamSelesai,
    required this.lokasi,
    required this.pendaftaranBuka,
    required this.checkinBuka,
    required this.anak,
  });

  static String _jam(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  static DateTime? _waktu(dynamic v) =>
      DateTime.tryParse(v?.toString() ?? '')?.toLocal();

  /// GET /jadwal/terdekat. Mengembalikan null bila tidak ada jadwal aktif
  /// (jadwal berstatus dibatalkan tidak pernah ditampilkan).
  static Future<JadwalTerdekatData?> ambil() async {
    final r = await ApiClient.dio.get(
      '/jadwal/terdekat',
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );
    dynamic d = r.data;
    if (d is Map && d.containsKey('data')) d = d['data'];
    if (d is! Map) return null;

    final jRaw = d['jadwal'];
    if (jRaw is! Map) return null;
    final j = Map<String, dynamic>.from(jRaw);
    if ((j['status']?.toString() ?? 'terjadwal') != 'terjadwal') return null;

    final t = j['tanggal']?.toString() ?? '';
    final tgl = t.length >= 10 ? DateTime.tryParse(t.substring(0, 10)) : null;
    if (tgl == null) return null;

    final anak = ((d['anak'] as List?) ?? [])
        .map((e) => AnakStatusJadwal.fromApi(Map<String, dynamic>.from(e as Map)))
        .toList();

    return JadwalTerdekatData(
      id: j['id']?.toString() ?? '',
      tanggal: tgl,
      jamMulai: _jam(j['jam_mulai']),
      jamSelesai: _jam(j['jam_selesai']),
      lokasi: j['lokasi']?.toString() ?? '',
      pendaftaranBuka: _waktu(d['pendaftaran_dibuka_pada']),
      checkinBuka: _waktu(d['checkin_dibuka_pada']),
      anak: anak,
    );
  }

  String get jam => jamSelesai.isEmpty ? jamMulai : '$jamMulai - $jamSelesai';
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

(String, Color, Color) labelStatusHadir(String s) {
  switch (s) {
    case 'terdaftar':
      return ('Terdaftar', AppColors.biruMuda, AppColors.biru);
    case 'sudah_checkin':
    case 'menunggu_kader':
      return ('Menunggu pengukuran kader', AppColors.hijauMuda, AppColors.hijau);
    case 'menunggu_bidan':
      return ('Menunggu pemeriksaan bidan', AppColors.biruMuda, AppColors.biru);
    case 'selesai':
      return ('Selesai dilayani', AppColors.hijauMuda, AppColors.hijau);
    case 'tidak_dilayani':
      return ('Tidak dilayani', AppColors.merahMuda, AppColors.merah);
    case 'belum_checkin':
      return ('Terdaftar', AppColors.biruMuda, AppColors.biru);
    case 'tidak_hadir':
      return ('Tidak hadir', AppColors.merahMuda, AppColors.merah);
    default:
      return ('Belum daftar', AppColors.isiField, AppColors.teksRedup);
  }
}

// ---------------------------------------------------------------------------
// KONSTANTA TAMPILAN
// ---------------------------------------------------------------------------
const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);


// ---------------------------------------------------------------------------
// KOMPONEN TAMPILAN JADWAL (putih berbayang, simpel dan rapi)
// ---------------------------------------------------------------------------

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Garis pemisah lembut.
const _garisLembut = Color(0xFFE5E7EB);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

const _hariPekan = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

/// Keterangan hitung mundur: "Hari ini", "Besok", "H-3", atau "Selesai".
String _hitungMundur(DateTime t) {
  final n = DateTime.now();
  final s = DateTime(t.year, t.month, t.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (s == 0) return 'Hari ini';
  if (s == 1) return 'Besok';
  if (s > 1) return 'H-$s';
  return 'Selesai';
}

/// Kepala jadwal: label kecil, hari (kapital), tanggal; keterangan di kanan; garis aksen.
Widget _kepalaJadwal(String label, DateTime t, String tanggal, {String? kanan}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: _aksen)),
                  const SizedBox(height: 4),
                  Text(_hariPekan[t.weekday - 1].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 18,
                          height: 1.2,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w700,
                          color: _teksGelap)),
                  Text(tanggal,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
                ],
              ),
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(kanan,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w700, color: _hijauHeader)),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Baris keterangan: ikon kecil + "Label : nilai" (nilai lanjut ke samping).
Widget _barisKet(IconData ikon, String label, String nilai) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(ikon, size: 18, color: _aksen),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label : ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _teksGelap),
                ),
                TextSpan(
                  text: nilai.isEmpty ? '-' : nilai,
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 15.5, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

/// Kotak pesan status (teks biasa dalam kartu putih berbayang).
Widget _kotakStatus(String teks, Color warna) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: _bayangan,
    ),
    child: Text(teks,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: warna)),
  );
}

const _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember'
];

String _tglPanjang(DateTime d) =>
    '${d.day} ${_namaBulan[d.month - 1]} ${d.year}';

String _jamMenit(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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

// ---------------------------------------------------------------------------
// HALAMAN PENDAFTARAN (ORANG TUA)
// ---------------------------------------------------------------------------
class OrangTuaPendaftaranPage extends StatefulWidget {
  const OrangTuaPendaftaranPage({super.key});

  @override
  State<OrangTuaPendaftaranPage> createState() =>
      _OrangTuaPendaftaranPageState();
}

class _OrangTuaPendaftaranPageState
    extends State<OrangTuaPendaftaranPage> {
  JadwalTerdekatData? _jadwal;
  bool _memuat = true;
  String? _gagal;
  String? _sibuk; // anakId yang sedang diproses
  int _idx = 0; // anak terpilih (tampilan)

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      if (!mounted) return;
      setState(() {
        _jadwal = j;
        _gagal = null;
        _memuat = false;
        if (j == null || _idx >= j.anak.length) _idx = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesanError(e);
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

  Future<void> _bukaKartu(String jadwalId, String anakId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KartuAntreanPage(
          jadwalId: jadwalId,
          anakId: anakId,
        ),
      ),
    );
    if (mounted) _muat();
  }

  Future<void> _daftar(AnakStatusJadwal a) async {
    final j = _jadwal;
    if (j == null || _sibuk != null) return;
    setState(() => _sibuk = a.anakId);
    var berhasil = false;
    try {
      await ApiClient.dio.post(
        '/jadwal/${j.id}/daftar',
        data: {'anak_id': a.anakId},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      berhasil = true;
      _snack('Pendaftaran berhasil. Kartu antrean Anda sudah terbit.');
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
    if (berhasil && mounted) {
      await _bukaKartu(j.id, a.anakId);
    }
  }

  Future<void> _batal(AnakStatusJadwal a) async {
    final j = _jadwal;
    if (j == null || _sibuk != null) return;

    final ya = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan pendaftaran?'),
        content: Text('Pendaftaran ${a.nama} akan dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (ya != true) return;

    setState(() => _sibuk = a.anakId);
    try {
      await ApiClient.dio.post(
        '/jadwal/${j.id}/batal',
        data: {'anak_id': a.anakId},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      _snack('Pendaftaran dibatalkan');
      await _muat();
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _sibuk = null);
    }
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final j = _jadwal;
    final punyaAnak =
        !_memuat && _gagal == null && j != null && j.anak.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.latar,
        body: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muat,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
                  children: [
                    if (_memuat)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_gagal != null)
                      _kartuPesan(
                        warna: AppColors.kuningMuda,
                        ikon: Icons.cloud_off,
                        ikonWarna: AppColors.kuning,
                        teks: _gagal!,
                        aksi: TextButton(
                          onPressed: () {
                            setState(() => _memuat = true);
                            _muat();
                          },
                          child: const Text('Coba lagi'),
                        ),
                      )
                    else if (j == null)
                      _kartuPesan(
                        warna: Colors.white,
                        ikon: Icons.event_busy,
                        ikonWarna: AppColors.teksRedup,
                        teks:
                            'Belum ada jadwal posyandu mendatang. Pendaftaran dapat dilakukan setelah admin menerbitkan jadwal.',
                      )
                    else
                      // Satu kartu: jadwal, balita terpilih, dan informasi penting.
                      _kartuPendaftaran(j),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: punyaAnak
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: _barAksi(
                    j,
                    j.anak[_idx.clamp(0, j.anak.length - 1)],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
  // -------------------------------------------------------------------------
  Widget _header() {
    return Container(
      width: double.infinity,
      color: _hijauHeader,
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
                child: _judulTebal('Pendaftaran Posyandu'),
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

  // -------------------------------------------------------------------------
  // KARTU PENDAFTARAN: satu kartu putih berbayang (jadwal + balita + informasi)
  // -------------------------------------------------------------------------
  Widget _pemisahDalam() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: _garisLembut,
      );

  Widget _labelBagian(String teks) => Text(
        teks,
        style: const TextStyle(
          fontSize: 13.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: _aksen,
        ),
      );

  Widget _kartuPendaftaran(JadwalTerdekatData j) {
    final ada = j.anak.isNotEmpty;
    final a = ada ? j.anak[_idx.clamp(0, j.anak.length - 1)] : null;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jadwal
          _kepalaJadwal(
            'JADWAL POSYANDU',
            j.tanggal,
            _tglPanjang(j.tanggal),
            kanan: _hitungMundur(j.tanggal),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                _barisKet(Icons.schedule, 'Waktu', j.jam.isEmpty ? '' : '${j.jam} WIB'),
                _barisKet(Icons.location_on_outlined, 'Lokasi', j.lokasi),
              ],
            ),
          ),
          _pemisahDalam(),

          // Balita terpilih
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: a == null
                ? const Text(
                    'Belum ada data anak. Lengkapi data keluarga di beranda terlebih dahulu.',
                    style: TextStyle(fontSize: 15.5, height: 1.4, color: AppColors.teksRedup),
                  )
                : _bagianBalita(j, a),
          ),
          _pemisahDalam(),

          // Informasi penting
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelBagian('INFORMASI PENTING'),
                const SizedBox(height: 6),
                Text(
                  [
                    'Pendaftaran dapat dilakukan kapan saja.',
                    if (j.checkinBuka != null)
                      'Check-in dengan scan QR di posyandu dibuka pukul ${_jamMenit(j.checkinBuka!)} WIB.',
                  ].join(' '),
                  style: const TextStyle(fontSize: 15.5, height: 1.45, color: Color(0xFF374151)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bagianBalita(JadwalTerdekatData j, AnakStatusJadwal a) {
    final (label, _, fg) = labelStatusHadir(a.statusTampil);
    final banyak = j.anak.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _labelBagian('BALITA')),
            if (banyak)
              InkWell(
                onTap: _sibuk != null
                    ? null
                    : () => setState(() => _idx = (_idx + 1) % j.anak.length),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Ganti anak',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _aksen,
                      decoration: TextDecoration.underline,
                      decorationColor: _aksen,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          a.nama.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w700,
            color: _teksGelap,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(color: a.status == 'belum_daftar' ? AppColors.merah : fg),
              ),
              if (a.nomorAntrean != null && a.status != 'belum_daftar')
                TextSpan(
                  text: '  ·  Antrean A-${a.nomorAntrean.toString().padLeft(3, '0')}',
                  style: const TextStyle(color: _hijauHeader),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _kartuPesan({
    required Color warna,
    required IconData ikon,
    required Color ikonWarna,
    required String teks,
    Widget? aksi,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Row(
        children: [
          Icon(ikon, color: ikonWarna),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
          if (aksi != null) aksi,
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // TOMBOL AKSI BAWAH
  // -------------------------------------------------------------------------
  /// Tombol utama hijau (sama dengan tombol di halaman lain).
  Widget _tombolUtama({
    required String teks,
    required VoidCallback onTap,
    bool aktif = true,
  }) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: aktif ? _hijauHeader : _hijauHeader.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(
          teks,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
        ),
      ),
    );
  }

  /// Tombol batal: garis merah (sama dengan tombol Hapus di halaman lain).
  Widget _tombolBatal({required String teks, required VoidCallback onTap}) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.merah,
          side: const BorderSide(color: AppColors.merah, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(
          teks,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
        ),
      ),
    );
  }

  Widget _barAksi(JadwalTerdekatData j, AnakStatusJadwal a) {
    final proses = _sibuk == a.anakId;
    final lock = _sibuk != null;

    if (a.selesai) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _kotakStatus('Selesai dilayani. Hasil pemeriksaan sudah dapat dilihat.', _hijauHeader),
          const SizedBox(height: 8),
          _tombolUtama(
            teks: 'Lihat Hasil Pemeriksaan',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrangTuaPemeriksaanPage(
                  anakId: a.anakId,
                  pendaftaranId: a.pendaftaranId.isEmpty ? null : a.pendaftaranId,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (a.tidakDilayani) {
      return _kotakStatus('Sesi berakhir sebelum anak diperiksa bidan', AppColors.merah);
    }

    if (a.status == 'sudah_checkin') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _kotakStatus(
              a.tahap == 'menunggu_bidan'
                  ? 'Pengukuran selesai, menunggu dipanggil bidan'
                  : 'Check-in selesai, menunggu dipanggil kader',
              _hijauHeader),
          const SizedBox(height: 8),
          _tombolUtama(
            teks: 'Lihat Kartu Antrean',
            onTap: () => _bukaKartu(j.id, a.anakId),
          ),
        ],
      );
    }

    if (a.status == 'terdaftar') {
      return Row(
        children: [
          Expanded(
            child: _tombolBatal(
              teks: proses ? 'Memproses...' : 'Batalkan',
              onTap: (!a.bolehBatal || lock)
                  ? () => _snack('Pendaftaran tidak dapat dibatalkan')
                  : () => _batal(a),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _tombolUtama(
              teks: 'Kartu Antrean',
              aktif: !lock,
              onTap: lock ? () {} : () => _bukaKartu(j.id, a.anakId),
            ),
          ),
        ],
      );
    }

    if (a.status == 'tidak_hadir') {
      return _kotakStatus('Anak tidak hadir pada sesi ini', AppColors.merah);
    }

    return _tombolUtama(
      teks: proses ? 'Memproses...' : 'Daftarkan Balita Ini',
      aktif: a.bolehDaftar && !lock,
      onTap: (!a.bolehDaftar || lock)
          ? () => _snack(
                a.bolehDaftar ? 'Sedang memproses...' : 'Pendaftaran sudah ditutup',
              )
          : () => _daftar(a),
    );
  }
}