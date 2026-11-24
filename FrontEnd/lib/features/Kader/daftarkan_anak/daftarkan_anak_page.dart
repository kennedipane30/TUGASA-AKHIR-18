import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/config/api_client.dart';
import '../keluarga/keluarga.dart';
import '../keluarga/tambah_keluarga_page.dart';
import '../../../core/theme/app_colors.dart';

// ============================================================================
// DAFTARKAN ANAK KE SESI POSYANDU HARI INI (kader)
//   - hanya saat ada sesi posyandu hari ini
//   - cari nama anak atau nama orang tua
//   - "Daftarkan" hanya untuk anak yang belum terdaftar
//   - anak yang sudah terdaftar / sudah check-in tidak dapat didaftarkan lagi
//   - pendaftaran kader langsung check-in dan mendapat nomor antrean
// ============================================================================

const _namaBulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', //
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

final Options _opsi = Options(receiveTimeout: const Duration(seconds: 15));

class AnakSesi {
  final String anakId, nama, jk, tglLahir, usia, namaIbu, status;
  final int? nomorAntrean;
  final bool bolehDaftar;

  AnakSesi({
    required this.anakId,
    required this.nama,
    required this.jk,
    required this.tglLahir,
    required this.usia,
    required this.namaIbu,
    required this.status,
    required this.nomorAntrean,
    required this.bolehDaftar,
  });

  factory AnakSesi.fromJson(Map<String, dynamic> j) => AnakSesi(
        anakId: j['anak_id'].toString(),
        nama: (j['nama'] ?? '').toString(),
        jk: (j['jenis_kelamin'] ?? '').toString(),
        tglLahir: kkDariApi(j['tanggal_lahir']),
        usia: (j['usia_teks'] ?? '').toString(),
        namaIbu: (j['nama_ibu'] ?? '').toString(),
        status: (j['status'] ?? 'belum_terdaftar').toString(),
        nomorAntrean: (j['nomor_antrean'] as num?)?.toInt(),
        bolehDaftar: j['boleh_daftar'] == true,
      );
}

class _Sesi {
  final bool aktif;
  final String pesan;
  final Map<String, dynamic>? jadwal;
  final List<AnakSesi> anak;
  _Sesi(this.aktif, this.pesan, this.jadwal, this.anak);
}

class _Api {
  static Future<_Sesi> cari(String kata) async {
    final r = await ApiClient.dio
        .get('/kader/daftar-anak', queryParameters: {'cari': kata}, options: _opsi);
    final d = Map<String, dynamic>.from(r.data['data'] as Map);
    return _Sesi(
      d['sesi_aktif'] == true,
      (d['pesan'] ?? '').toString(),
      d['jadwal'] is Map ? Map<String, dynamic>.from(d['jadwal']) : null,
      ((d['anak'] as List?) ?? [])
          .map((e) => AnakSesi.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static Future<int?> daftarkan(String anakId) async {
    final r = await ApiClient.dio.post('/kader/daftar-anak/$anakId', options: _opsi);
    final d = Map<String, dynamic>.from(r.data['data'] as Map);
    return (d['nomor_antrean'] as num?)?.toInt();
  }
}

String _nomor(int? n) => n == null ? '-' : 'A-${n.toString().padLeft(3, '0')}';

// ---------------------------------------------------------------------------
// KOMPONEN KARTU (SERAGAM DENGAN HALAMAN LAIN)
// ---------------------------------------------------------------------------

const _hijauTua = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi kolom cari & kotak di dalam kartu: hitam lembut.
const _garis = Color(0xFFB8BEC6);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

BoxDecoration _dekorKartu() => BoxDecoration(
      color: Colors.white,
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

/// Baris "Label : nilai" (hitam tebal, nilai lanjut ke samping).
Widget _baris(String label, String nilai, {double lebar = 120}) {
  const gaya = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: _teksGelap);
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

class DaftarkanAnakPage extends StatefulWidget {
  const DaftarkanAnakPage({super.key});

  @override
  State<DaftarkanAnakPage> createState() => _DaftarkanAnakPageState();
}

class _DaftarkanAnakPageState extends State<DaftarkanAnakPage> {
  final _cari = TextEditingController();
  Timer? _tunda;
  _Sesi? _sesi;
  bool _memuat = true;
  String? _galat;
  String? _sedangDaftar; // anak_id yang sedang diproses
  int _permintaan = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  @override
  void dispose() {
    _tunda?.cancel();
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final no = ++_permintaan;
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final s = await _Api.cari(_cari.text.trim());
      if (!mounted || no != _permintaan) return;
      setState(() => _sesi = s);
    } catch (e) {
      if (!mounted || no != _permintaan) return;
      setState(() => _galat = kkPesanError(e));
    } finally {
      if (mounted && no == _permintaan) setState(() => _memuat = false);
    }
  }

  void _ketik(String v) {
    _tunda?.cancel();
    setState(() {});
    if (v.trim().length >= 2 || v.trim().isEmpty) {
      _tunda = Timer(const Duration(milliseconds: 450), _muat);
    }
  }

  Future<void> _daftarkan(AnakSesi a) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Daftarkan anak?',
            style: TextStyle(fontWeight: FontWeight.w700, color: kkTeksGelap)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baris('Nama', a.nama, lebar: 70),
            _baris('Ibu', a.namaIbu, lebar: 70),
            _baris('Usia', a.usia, lebar: 70),
            const SizedBox(height: 6),
            const Text(
              'Anak akan didaftarkan pada sesi posyandu hari ini, langsung check-in, '
              'dan mendapat nomor antrean.',
              style: TextStyle(fontSize: 15, color: kkTeksAbu, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(c, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade700, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(c, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hijauTua,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Daftarkan'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (ya != true || !mounted) return;

    setState(() => _sedangDaftar = a.anakId);
    try {
      final n = await _Api.daftarkan(a.anakId);
      if (!mounted) return;
      kkSnack(context, '${a.nama} terdaftar · nomor antrean ${_nomor(n)}');
    } catch (e) {
      if (mounted) kkSnack(context, kkPesanError(e));
    } finally {
      if (mounted) setState(() => _sedangDaftar = null);
    }
    await _muat();
  }

  Future<void> _tambahAkun() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TambahKeluargaPage()),
    );
    if (ok == true) _muat();
  }

  // ---------------------------------------------------------------- tampilan
  static const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  DateTime? _tgl(dynamic v) {
    final s = (v ?? '').toString();
    if (s.length < 10) return null;
    return DateTime.tryParse(s.substring(0, 10));
  }

  String _tanggal(dynamic v) {
    final d = _tgl(v);
    if (d == null) return '-';
    return '${d.day} ${_namaBulan[d.month - 1]} ${d.year}';
  }

  /// Kartu sesi: hari di atas, tanggal di bawahnya, waktu di kanan, lalu lokasi.
  Widget _kartuSesi() {
    final j = _sesi?.jadwal;
    final t = _tgl(j?['tanggal']);
    final mulai = (j?['jam_mulai'] ?? '').toString();
    final selesai = (j?['jam_selesai'] ?? '').toString();
    final lokasi = (j?['lokasi'] ?? '').toString();
    final waktu = mulai.isEmpty ? '' : (selesai.isEmpty ? '$mulai WIB' : '$mulai - $selesai WIB');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: _dekorKartu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala(
            t == null ? 'Sesi Posyandu' : _hari[t.weekday - 1],
            sub: _tanggal(j?['tanggal']),
            kanan: waktu,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.location_on_outlined, size: 18, color: _aksen),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Lokasi : ',
                          style: TextStyle(fontWeight: FontWeight.w700, color: _teksGelap),
                        ),
                        TextSpan(
                          text: lokasi.isEmpty ? '-' : lokasi,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 15.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Kolom cari: putih, garis tepi hitam lembut (sama seperti Semua Balita).
  Widget _kotakCari() {
    OutlineInputBorder garis(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _cari,
        onChanged: _ketik,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _muat(),
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Cari nama anak atau nama orang tua',
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search, color: Colors.black54),
          suffixIcon: _cari.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _cari.clear();
                    _muat();
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: garis(_garis, 1.2),
          enabledBorder: garis(_garis, 1.2),
          focusedBorder: garis(Colors.black54, 1.4),
        ),
      ),
    );
  }

  /// Keterangan anak yang sudah terdaftar (teks biasa, tanpa pill).
  Widget _teksTerdaftar(AnakSesi a) {
    final checkin = a.status == 'sudah_checkin';
    return Text(
      '${checkin ? 'Sudah check-in' : 'Sudah terdaftar'} · ${_nomor(a.nomorAntrean)}',
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _hijauTua),
    );
  }

  Widget _kartuAnak(AnakSesi a) {
    final proses = _sedangDaftar == a.anakId;
    final jk = a.jk == 'L' ? 'Laki-laki' : (a.jk == 'P' ? 'Perempuan' : '-');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: _dekorKartu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala(a.nama),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _baris('Nama Ibu', a.namaIbu),
                _baris('Tanggal Lahir', a.tglLahir),
                _baris('Jenis Kelamin', jk),
                _baris('Usia', a.usia),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: a.bolehDaftar
                      ? SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _sedangDaftar != null ? null : () => _daftarkan(a),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hijauTua,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _hijauTua.withValues(alpha: 0.45),
                              disabledForegroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(140, 46),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: proses
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.2, color: Colors.white),
                                  )
                                : const Text('Daftarkan',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        )
                      : _teksTerdaftar(a),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _teksTengah(String teks, {Widget? aksi}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: _dekorKartu(),
          child: Text(teks,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: kkTeksAbu, height: 1.45)),
        ),
        if (aksi != null) ...[const SizedBox(height: 12), Center(child: aksi)],
      ],
    );
  }

  Widget _hasil() {
    if (_memuat && _sesi == null) {
      return const Center(child: CircularProgressIndicator(color: kkHijau));
    }
    if (_galat != null) {
      return _teksTengah(_galat!,
          aksi: TextButton(
            onPressed: _muat,
            child: const Text('Coba lagi',
                style: TextStyle(
                    color: _aksen,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: _aksen)),
          ));
    }
    final s = _sesi;
    if (s == null) return const SizedBox();
    final kata = _cari.text.trim();
    if (kata.length < 2) {
      return _teksTengah('Ketik minimal 2 huruf nama anak atau nama orang tua.');
    }
    if (s.anak.isEmpty) {
      return _teksTengah(
        'Anak tidak ditemukan.\nBila orang tua belum memiliki akun, tambahkan akun terlebih dahulu.',
        aksi: TextButton(
          onPressed: _tambahAkun,
          child: const Text('Tambahkan Akun',
              style: TextStyle(
                  color: _aksen,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                  decorationColor: _aksen)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: s.anak.length,
      itemBuilder: (_, i) => _kartuAnak(s.anak[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _sesi;
    final tanpaSesi = s != null && !s.aktif && _galat == null;
    final pesanSesi = s?.pesan ?? '';
    return Scaffold(
      backgroundColor: kkLatar,
      // Header hijau 0xFF065F46 dari kkAppBar.
      appBar: kkAppBar('Daftarkan Anak'),
      // Kolom cari selalu paling atas, tepat di bawah header.
      body: Column(
        children: [
          _kotakCari(),
          if (_memuat && s != null)
            const LinearProgressIndicator(minHeight: 2, color: kkHijau),
          if (!tanpaSesi && s != null && s.aktif) _kartuSesi(),
          Expanded(
            child: RefreshIndicator(
              color: kkHijau,
              onRefresh: _muat,
              child: tanpaSesi
                  ? _teksTengah(pesanSesi.isEmpty ? 'Tidak ada sesi posyandu hari ini.' : pesanSesi)
                  : _hasil(),
            ),
          ),
        ],
      ),
    );
  }
}