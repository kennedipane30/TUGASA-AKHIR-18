import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/config/api_client.dart';
import '../keluarga/keluarga.dart';
import '../keluarga/tambah_keluarga_page.dart';

// ============================================================================
// DAFTARKAN ANAK KE SESI POSYANDU HARI INI (kader)
//   - hanya saat ada sesi posyandu hari ini
//   - cari nama anak atau nama orang tua
//   - "Daftarkan" hanya untuk anak yang belum terdaftar
//   - anak yang sudah terdaftar / sudah check-in tidak dapat didaftarkan lagi
//   - pendaftaran kader langsung check-in dan mendapat nomor antrean
// ============================================================================

const _namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
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
            kkInfo('Nama', a.nama),
            kkInfo('Ibu', a.namaIbu),
            kkInfo('Usia', a.usia),
            const SizedBox(height: 6),
            const Text(
              'Anak akan didaftarkan pada sesi posyandu hari ini, langsung check-in, '
              'dan mendapat nomor antrean.',
              style: TextStyle(fontSize: 13.5, color: kkTeksAbu, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal', style: TextStyle(color: kkTeksAbu)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kkHijau,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Daftarkan'),
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
  String _tanggal(dynamic v) {
    final s = (v ?? '').toString();
    if (s.length < 10) return '-';
    final d = DateTime.tryParse(s.substring(0, 10));
    if (d == null) return '-';
    return '${_namaHari[d.weekday - 1]}, ${d.day} ${_namaBulan[d.month - 1]} ${d.year}';
  }

  Widget _kartuSesi() {
    final j = _sesi?.jadwal;
    final mulai = (j?['jam_mulai'] ?? '').toString();
    final selesai = (j?['jam_selesai'] ?? '').toString();
    final lokasi = (j?['lokasi'] ?? '').toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kkGaris),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sesi Posyandu Hari Ini',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: kkTeksGelap)),
          const SizedBox(height: 10),
          kkInfo('Tanggal', _tanggal(j?['tanggal'])),
          kkInfo('Pukul',
              selesai.isEmpty ? '$mulai WIB' : '$mulai - $selesai WIB'),
          if (lokasi.isNotEmpty) kkInfo('Lokasi', lokasi),
        ],
      ),
    );
  }

  Widget _kotakCari() {
    return Container(
      color: kkHijau,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: TextField(
        controller: _cari,
        onChanged: _ketik,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _muat(),
        decoration: InputDecoration(
          hintText: 'Cari nama anak atau nama orang tua',
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search, color: kkTeksAbu),
          suffixIcon: _cari.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: kkTeksAbu),
                  onPressed: () {
                    _cari.clear();
                    _muat();
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _pillTerdaftar(AnakSesi a) {
    final checkin = a.status == 'sudah_checkin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kkHijauMuda,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${checkin ? 'Sudah check-in' : 'Sudah terdaftar'} · ${_nomor(a.nomorAntrean)}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kkHijau),
      ),
    );
  }

  Widget _kartuAnak(AnakSesi a) {
    final proses = _sedangDaftar == a.anakId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kkGaris),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.nama,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: kkTeksGelap)),
          const SizedBox(height: 8),
          kkInfo('Ibu', a.namaIbu),
          kkInfo('Lahir', a.tglLahir),
          kkInfo('JK · Usia',
              '${a.jk == 'L' ? 'Laki-laki' : (a.jk == 'P' ? 'Perempuan' : '-')} · ${a.usia}'),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: a.bolehDaftar
                ? ElevatedButton(
                    onPressed: _sedangDaftar != null ? null : () => _daftarkan(a),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kkHijau,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(130, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: proses
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text('Daftarkan',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  )
                : _pillTerdaftar(a),
          ),
        ],
      ),
    );
  }

  Widget _teksTengah(String teks, {Widget? aksi}) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Text(teks,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: kkTeksAbu, height: 1.45)),
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
                style: TextStyle(color: kkHijau, fontWeight: FontWeight.w600)),
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
              style: TextStyle(color: kkHijau, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
      appBar: kkAppBar('Daftarkan Anak'),
      body: tanpaSesi
          ? _teksTengah(pesanSesi.isEmpty ? 'Tidak ada sesi posyandu hari ini.' : pesanSesi)
          : Column(
              children: [
                _kotakCari(),
                if (s != null && s.aktif) _kartuSesi(),
                if (_memuat && s != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2, color: kkHijau),
                  ),
                Expanded(
                  child: RefreshIndicator(color: kkHijau, onRefresh: _muat, child: _hasil()),
                ),
              ],
            ),
    );
  }
}