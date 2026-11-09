import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import 'orangtua_kartu_antrean_page.dart';

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

  AnakStatusJadwal({
    required this.anakId,
    required this.nama,
    required this.status,
    required this.nomorAntrean,
    required this.bolehDaftar,
    required this.bolehBatal,
    required this.bolehCheckin,
    this.rencana,
  });

  factory AnakStatusJadwal.fromApi(Map<String, dynamic> j) =>
      AnakStatusJadwal(
        anakId: j['anak_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        status: j['status_kehadiran']?.toString() ?? 'belum_daftar',
        nomorAntrean: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
        bolehDaftar: j['boleh_daftar'] == true,
        bolehBatal: j['boleh_batal'] == true,
        bolehCheckin: j['boleh_checkin'] == true,
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
      return ('Sudah check-in', AppColors.hijauMuda, AppColors.hijau);
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
const _kartuAwal = Color(0xFF0A6B51); // sedikit lebih terang dari heading
const _mintLabel = Color(0xFF8CF0CB);
const _oranye1 = Color(0xFFEA580C);
const _oranye2 = Color(0xFFF97316);

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

/// Judul header ekstra tebal (sama seperti halaman Akun).
/// Lapis bawah: garis tepi putih agar huruf lebih gemuk; lapis atas: isi putih.
Widget _judulTebal(String teks) {
  const ukuran = 20.0;
  const jarak = 1.2; // jarak antar huruf

  return Stack(
    children: [
      // Lapis bawah: garis tepi untuk menebalkan huruf
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
      // Lapis atas: isi huruf
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
                    else ...[
                      _kartuJadwal(j),
                      const SizedBox(height: 22),
                      if (j.anak.isEmpty)
                        _kartuPesan(
                          warna: Colors.white,
                          ikon: Icons.child_care,
                          ikonWarna: AppColors.teksRedup,
                          teks:
                              'Belum ada data anak. Lengkapi data keluarga di beranda terlebih dahulu.',
                        )
                      else ...[
                        _judulProfil(),
                        const SizedBox(height: 10),
                        _kartuAnak(
                          j,
                          j.anak[_idx.clamp(0, j.anak.length - 1)],
                        ),
                        const SizedBox(height: 14),
                        _kartuRencana(j.anak[_idx.clamp(0, j.anak.length - 1)]),
                        const SizedBox(height: 14),
                        _kartuPetunjuk(),
                        const SizedBox(height: 12),
                        _kartuOffline(),
                      ],
                    ],
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
  // KARTU JADWAL (HERO) - warna hijau senada dengan heading
  // -------------------------------------------------------------------------
  Widget _kartuJadwal(JadwalTerdekatData j) {
    final infoTeks = [
      'Pendaftaran dapat dilakukan kapan saja.',
      if (j.checkinBuka != null)
        'Check-in dengan scan QR di posyandu dibuka 1 jam sebelum mulai (${_jamMenit(j.checkinBuka!)} WIB).',
    ].join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kartuAwal, _hijauHeader],
        ),
        boxShadow: [
          BoxShadow(
            color: _hijauHeader.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TANGGAL & SESI PELAKSANAAN',
            style: TextStyle(
              color: _mintLabel,
              fontSize: 13.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _tglPanjang(j.tanggal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _tileInfo(
                    Icons.schedule,
                    'Waktu',
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: j.jam),
                          const TextSpan(
                            text: ' WIB',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xCCFFFFFF),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tileInfo(
                    Icons.location_on_outlined,
                    'Lokasi',
                    Text(
                      j.lokasi.isEmpty ? '-' : j.lokasi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.volume_up_outlined,
                    color: _mintLabel,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INFORMASI PENTING',
                        style: TextStyle(
                          color: _mintLabel,
                          fontSize: 13.5,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        infoTeks,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
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

  Widget _tileInfo(IconData ikon, String label, Widget nilai) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ikon, color: _mintLabel, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _mintLabel,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                nilai,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // PROFIL BALITA
  // -------------------------------------------------------------------------
  Widget _judulProfil() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _hijauHeader,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Profil Balita Terpilih',
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              _snack('Tambah anak baru dilakukan melalui data keluarga di beranda'),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              '+ Anak Baru',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _oranye2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration get _dekorPutih => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _kartuAnak(JadwalTerdekatData j, AnakStatusJadwal a) {
    final (label, bg, fg) = labelStatusHadir(a.status);
    final banyak = j.anak.length > 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: _dekorPutih,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: a.status == 'belum_daftar' ? const Color(0xFFEFF2F5) : bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: a.status == 'belum_daftar' ? const Color(0xFF374151) : fg,
                    ),
                  ),
                ),
                if (a.nomorAntrean != null && a.status != 'belum_daftar') ...[
                  const SizedBox(height: 6),
                  Text(
                    'Nomor antrean #${a.nomorAntrean}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: _hijauHeader,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _sibuk != null
                ? null
                : () {
                    if (banyak) {
                      setState(() => _idx = (_idx + 1) % j.anak.length);
                    } else {
                      _snack('Hanya ada satu data anak');
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Ganti',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // RENCANA PELAYANAN (imunisasi, Vitamin A, obat cacing)
  // -------------------------------------------------------------------------
  Widget _kartuRencana(AnakStatusJadwal a) {
    final r = a.rencana;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _dekorPutih,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F6F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_note_rounded, size: 20, color: _hijauHeader),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Rencana Pelayanan',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (r == null || r.kosong)
            Text(
              'Tidak ada imunisasi, Vitamin A, atau obat cacing untuk ${a.nama} pada jadwal ini. Tetap datang untuk penimbangan, ya.',
              style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF4B5563)),
            )
          else ...[
            if (r.imunisasi.isNotEmpty)
              _grupRencana(
                'Imunisasi',
                Icons.vaccines_outlined,
                const Color(0xFF0B7FBF),
                const Color(0xFFE6F3FB),
                r.imunisasi,
              ),
            if (r.suplemen.isNotEmpty)
              _grupRencana(
                'Vitamin A & Obat Cacing',
                Icons.medication_outlined,
                const Color(0xFFB45309),
                const Color(0xFFFFF4E5),
                r.suplemen,
              ),
            if (r.keFaskes.isNotEmpty)
              _grupRencana(
                'Segera ke Puskesmas',
                Icons.local_hospital_outlined,
                const Color(0xFFDC2626),
                const Color(0xFFFDECEC),
                r.keFaskes,
              ),
            const SizedBox(height: 2),
            const Text(
              'Pastikan anak dalam keadaan sehat dan bawa buku KIA.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _grupRencana(
    String judul,
    IconData ikon,
    Color warna,
    Color latar,
    List<RencanaItemJadwal> items,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 18, color: warna),
              const SizedBox(width: 6),
              Text(
                judul,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: warna),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                it.nama,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            if (it.terlambat) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDECEC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Terlambat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (it.keterangan.isNotEmpty)
                          Text(
                            it.keterangan,
                            style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF4B5563)),
                          ),
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

  // -------------------------------------------------------------------------
  // KARTU INFORMASI
  // -------------------------------------------------------------------------
  Widget _kartuPetunjuk() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _dekorPutih,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Petunjuk Check-in Mandiri',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Kartu antrean muncul setelah pendaftaran. Scan QR di posyandu untuk check-in, lalu data anak masuk ke antrean pendataan kader.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuOffline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _dekorPutih,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bisa Dibuka Tanpa Sinyal',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Kartu antrean dapat dibuka kembali kapan saja. Data otomatis tersinkronisasi ke server pada saat sinyal tersedia.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: Row(
        children: [
          Icon(ikon, color: ikonWarna),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
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
  Widget _tombolUtama({
    required String teks,
    required IconData ikon,
    required VoidCallback onTap,
    bool aktif = true,
  }) {
    return Opacity(
      opacity: aktif ? 1 : 0.6,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [_oranye1, _oranye2]),
            boxShadow: [
              BoxShadow(
                color: _oranye1.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  teks,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barAksi(JadwalTerdekatData j, AnakStatusJadwal a) {
    final proses = _sibuk == a.anakId;
    final lock = _sibuk != null;

    if (a.status == 'sudah_checkin') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Pill(
            'Check-in selesai, menunggu dipanggil kader',
            bg: AppColors.hijauMuda,
            fg: AppColors.hijau,
            icon: Icons.check_circle,
          ),
          const SizedBox(height: 8),
          _tombolUtama(
            teks: 'Lihat Kartu Antrean',
            ikon: Icons.confirmation_number_outlined,
            onTap: () => _bukaKartu(j.id, a.anakId),
          ),
        ],
      );
    }

    if (a.status == 'terdaftar') {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: _tombolUtama(
              teks: 'Kartu Antrean',
              ikon: Icons.confirmation_number_outlined,
              aktif: !lock,
              onTap: lock ? () {} : () => _bukaKartu(j.id, a.anakId),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: AppButton(
                proses ? 'Memproses...' : 'Batalkan',
                filled: false,
                color: AppColors.merah,
                icon: Icons.close,
                onPressed: (!a.bolehBatal || lock)
                    ? () => _snack('Pendaftaran tidak dapat dibatalkan')
                    : () => _batal(a),
              ),
            ),
          ),
        ],
      );
    }

    if (a.status == 'tidak_hadir') {
      return const Pill(
        'Anak tidak hadir pada sesi ini',
        bg: AppColors.merahMuda,
        fg: AppColors.merah,
      );
    }

    return _tombolUtama(
      teks: proses ? 'Memproses...' : 'Daftarkan Balita Ini Sekarang',
      ikon: Icons.how_to_reg,
      aktif: a.bolehDaftar && !lock,
      onTap: (!a.bolehDaftar || lock)
          ? () => _snack(
                a.bolehDaftar ? 'Sedang memproses...' : 'Pendaftaran sudah ditutup',
              )
          : () => _daftar(a),
    );
  }
}