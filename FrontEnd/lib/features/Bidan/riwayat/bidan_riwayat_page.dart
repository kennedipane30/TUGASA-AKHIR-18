import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

const _prefix = '/bidan/riwayat';

// ---------------------------------------------------------------------------
// FUNGSI BANTU
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

const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];

String _fmtTgl(DateTime? t) =>
    t == null ? '-' : '${t.day} ${_bulan[t.month - 1]} ${t.year}';

String _usia(int bln) => bln >= 12 ? '${bln ~/ 12} th ${bln % 12} bln' : '$bln bln';

String _jam(dynamic v) {
  final s = _teks(v);
  return s.length >= 5 ? s.substring(0, 5) : s;
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

Future<dynamic> _get(String path) async {
  final r = await ApiClient.dio.get(path,
      options: Options(receiveTimeout: const Duration(seconds: 15)));
  dynamic d = r.data;
  if (d is Map && d.containsKey('data')) d = d['data'];
  return d;
}

List<Map<String, dynamic>> _daftarPeta(dynamic d) {
  final list = <Map<String, dynamic>>[];
  if (d is List) {
    for (final e in d) {
      if (e is Map) list.add(Map<String, dynamic>.from(e));
    }
  }
  return list;
}

Widget _gagalKartu(String pesan, VoidCallback ulang) => SectionCard(
      color: AppColors.kuningMuda,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.kuning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(pesan,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          TextButton(onPressed: ulang, child: const Text('Coba lagi')),
        ],
      ),
    );

AppBar _bar(String judul) => AppBar(
      title: Text(judul, style: const TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white,
      elevation: 0,
    );

Widget _memuatBox() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );

// ---------------------------------------------------------------------------
// HALAMAN 1: DAFTAR TANGGAL POSYANDU
// ---------------------------------------------------------------------------
class BidanRiwayatPage extends StatefulWidget {
  const BidanRiwayatPage({super.key});

  @override
  State<BidanRiwayatPage> createState() => _BidanRiwayatPageState();
}

class _BidanRiwayatPageState extends State<BidanRiwayatPage> {
  List<Map<String, dynamic>> _data = [];
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final d = await _get('$_prefix/jadwal');
      final list = _daftarPeta(d);
      list.sort((a, b) {
        final ta = _tgl(a['tanggal']) ?? DateTime(1970);
        final tb = _tgl(b['tanggal']) ?? DateTime(1970);
        return tb.compareTo(ta);
      });
      if (!mounted) return;
      setState(() {
        _data = list;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: _bar('Riwayat Pemeriksaan'),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_memuat)
              _memuatBox()
            else if (_gagal != null)
              _gagalKartu(_gagal!, () {
                setState(() => _memuat = true);
                _muat();
              })
            else
              SectionCard(
                title: 'Tanggal Posyandu',
                icon: Icons.history,
                trailing: const Text('Ketuk untuk melihat',
                    style: TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
                child: _data.isEmpty
                    ? const Text('Belum ada jadwal posyandu.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup))
                    : Column(children: [for (final j in _data) _baris(j)]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _baris(Map<String, dynamic> j) {
    final t = _tgl(j['tanggal']);
    final jam = _jam(j['jam_mulai']);
    final lokasi = _teks(j['lokasi']);
    final checkin = int.tryParse(_teks(j['jumlah_checkin'])) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _DaftarAnakPage(
                jadwalId: _teks(j['id']),
                judul: _fmtTgl(t),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
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
                      Text(t == null ? '' : _bulan[t.month - 1].substring(0, 3),
                          style: const TextStyle(
                              color: AppColors.hijau,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fmtTgl(t),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text(
                          [if (jam.isNotEmpty) '$jam WIB', if (lokasi.isNotEmpty) lokasi]
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.teksRedup)),
                      const SizedBox(height: 4),
                      Pill('$checkin anak check-in',
                          bg: AppColors.biruMuda, fg: AppColors.biru),
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
// HALAMAN 2: DAFTAR ANAK PADA SATU JADWAL
// ---------------------------------------------------------------------------
class _DaftarAnakPage extends StatefulWidget {
  final String jadwalId;
  final String judul;
  const _DaftarAnakPage({required this.jadwalId, required this.judul});

  @override
  State<_DaftarAnakPage> createState() => _DaftarAnakPageState();
}

class _DaftarAnakPageState extends State<_DaftarAnakPage> {
  List<Map<String, dynamic>> _data = [];
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final d = await _get('$_prefix/jadwal/${widget.jadwalId}/anak');
      final list = _daftarPeta(d);
      list.sort((a, b) => (int.tryParse(_teks(a['nomor_antrean'])) ?? 1 << 30)
          .compareTo(int.tryParse(_teks(b['nomor_antrean'])) ?? 1 << 30));
      if (!mounted) return;
      setState(() {
        _data = list;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: _bar(widget.judul),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_memuat)
              _memuatBox()
            else if (_gagal != null)
              _gagalKartu(_gagal!, () {
                setState(() => _memuat = true);
                _muat();
              })
            else
              SectionCard(
                title: 'Daftar Balita',
                icon: Icons.child_care,
                trailing: Pill('${_data.length} anak',
                    bg: AppColors.hijauMuda, fg: AppColors.hijau),
                child: _data.isEmpty
                    ? const Text('Belum ada anak yang check-in pada jadwal ini.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup))
                    : Column(children: [for (final a in _data) _baris(a)]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _baris(Map<String, dynamic> a) {
    final nomor = int.tryParse(_teks(a['nomor_antrean']));
    final kode = nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';
    final diukur = a['sudah_diukur'] == true;
    final selesai = _teks(a['status_catatan']) == 'selesai';
    final usia = int.tryParse(_teks(a['usia_bulan'])) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _HasilAnakPage(pendaftaranId: _teks(a['pendaftaran_id'])),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.hijauMuda,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(kode,
                      style: const TextStyle(
                          color: AppColors.hijau,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_teks(a['nama']),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text(
                          '${_teks(a['jenis_kelamin']) == 'P' ? 'Perempuan' : 'Laki-laki'} · ${_usia(usia)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.teksRedup)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          diukur
                              ? const Pill('Sudah diukur', icon: Icons.check)
                              : const Pill('Belum diukur',
                                  bg: AppColors.kuningMuda, fg: AppColors.kuning),
                          selesai
                              ? const Pill('Dicatat bidan',
                                  bg: AppColors.biruMuda, fg: AppColors.biru)
                              : const Pill('Belum dicatat bidan',
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
// HALAMAN 3: HASIL PENDATAAN ANAK
// ---------------------------------------------------------------------------
class _HasilAnakPage extends StatefulWidget {
  final String pendaftaranId;
  const _HasilAnakPage({required this.pendaftaranId});

  @override
  State<_HasilAnakPage> createState() => _HasilAnakPageState();
}

class _HasilAnakPageState extends State<_HasilAnakPage> {
  Map<String, dynamic>? _d;
  Map<String, String> _namaVaksin = {};
  bool _memuat = true;
  String? _gagal;

  static const _namaSuplemen = {
    'vitamin_a': 'Vitamin A',
    'obat_cacing': 'Obat cacing',
    'pmt': 'PMT',
  };

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final peta = <String, String>{};
      try {
        final v = await _get('/vaksin');
        if (v is List) {
          for (final e in v) {
            if (e is Map) peta[_teks(e['id'])] = _teks(e['nama']);
          }
        }
      } catch (_) {}
      final d = await _get('$_prefix/pendaftaran/${widget.pendaftaranId}');
      if (!mounted) return;
      setState(() {
        _d = d is Map ? Map<String, dynamic>.from(d) : null;
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

  Widget _baris(String label, String nilai) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
            ),
            Expanded(
              child: Text(nilai.isEmpty ? '-' : nilai,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _kotak(String nilai, String label, Color bg, Color fg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Text(nilai,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: AppColors.teksRedup)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: _bar('Hasil Pendataan'),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_memuat)
              _memuatBox()
            else if (_gagal != null)
              _gagalKartu(_gagal!, () {
                setState(() => _memuat = true);
                _muat();
              })
            else if (_d == null)
              const SectionCard(child: Text('Data tidak tersedia.'))
            else
              ..._isi(_d!),
          ],
        ),
      ),
    );
  }

  List<Widget> _isi(Map<String, dynamic> d) {
    final anak = _peta(d['anak']) ?? {};
    final jadwal = _peta(d['jadwal']) ?? {};
    final u = _peta(d['pengukuran']);
    final prev = _peta(d['pengukuran_sebelumnya']);
    final c = _peta(d['catatan']);
    final usia = int.tryParse(_teks(d['usia_bulan'])) ?? 0;
    final imun = (d['imunisasi'] as List? ?? []).whereType<Map>().toList();
    final sup = (d['suplemen'] as List? ?? []).whereType<Map>().toList();

    final gejala = [
      if (c?['demam'] == true) 'Demam',
      if (c?['diare'] == true) 'Diare',
      if (c?['batuk'] == true) 'Batuk',
    ];
    final ulang = _tgl(c?['tanggal_kunjungan_ulang']);
    final peringatan = _teks(u?['peringatan_validasi']);

    return [
      SectionCard(
        title: _teks(anak['nama']).isEmpty ? 'Anak' : _teks(anak['nama']),
        icon: Icons.child_care,
        trailing: Pill(_fmtTgl(_tgl(jadwal['tanggal'])),
            bg: AppColors.hijauMuda, fg: AppColors.hijau),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baris('Jenis kelamin',
                _teks(anak['jenis_kelamin']) == 'P' ? 'Perempuan' : 'Laki-laki'),
            _baris('Usia', _usia(usia)),
            if (_jam(jadwal['jam_mulai']).isNotEmpty)
              _baris('Sesi posyandu', '${_jam(jadwal['jam_mulai'])} WIB'),
          ],
        ),
      ),
      SectionCard(
        title: 'Hasil Pengukuran (Kader)',
        icon: Icons.straighten,
        child: u == null
            ? const Text('Kader belum menginput pengukuran.',
                style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _kotak(_num(u['bb_kg']), 'Berat\n(kg)', AppColors.biruMuda,
                          AppColors.biru),
                      const SizedBox(width: 8),
                      _kotak(_num(u['tb_cm']), 'Tinggi/\nPanjang (cm)',
                          AppColors.hijauMuda, AppColors.hijau),
                      const SizedBox(width: 8),
                      _kotak(_num(u['lingkar_kepala_cm']), 'Lingkar\nKepala (cm)',
                          AppColors.kuningMuda, AppColors.kuning),
                      const SizedBox(width: 8),
                      _kotak(_num(u['lila_cm']), 'LiLA\n(cm)', AppColors.merahMuda,
                          AppColors.merah),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _baris('Cara ukur', _teks(u['cara_ukur'])),
                  _baris('Sedang sakit', u['sedang_sakit'] == true ? 'Ya' : 'Tidak'),
                  _baris('ASI eksklusif', u['asi_eksklusif'] == true ? 'Ya' : 'Tidak'),
                  if (_teks(u['keluhan']).isNotEmpty)
                    _baris('Keluhan', _teks(u['keluhan'])),
                  if (_teks(u['catatan']).isNotEmpty)
                    _baris('Catatan kader', _teks(u['catatan'])),
                  if (prev != null)
                    _baris('Sebelumnya',
                        'BB ${_num(prev['bb_kg'])} kg · TB ${_num(prev['tb_cm'])} cm'),
                  if (peringatan.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Perhatian: $peringatan',
                        style: const TextStyle(
                            color: AppColors.merah,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
      ),
      SectionCard(
        title: 'Catatan Bidan',
        icon: Icons.assignment_outlined,
        child: c == null
            ? const Text('Bidan belum menuliskan catatan.',
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
                  _baris('Penyakit penyerta', _teks(c['penyakit_penyerta'])),
                  _baris('Keluhan', _teks(c['keluhan'])),
                  _baris('Evaluasi', _teks(c['catatan_evaluasi'])),
                  _baris('Saran gizi', _teks(c['saran_gizi'])),
                  _baris('Saran pola asuh', _teks(c['saran_pola_asuh'])),
                  _baris('Kunjungan ulang', ulang == null ? '' : _fmtTgl(ulang)),
                ],
              ),
      ),
      if (imun.isNotEmpty)
        SectionCard(
          title: 'Imunisasi',
          icon: Icons.vaccines_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final v in imun)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${_namaVaksin[_teks(v['jenis_vaksin_id'])] ?? 'Vaksin'} · Dosis ${_teks(v['dosis_ke'])}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      if (_teks(v['kondisi_anak']).isNotEmpty)
                        Text('Kondisi: ${_teks(v['kondisi_anak'])}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.teksRedup)),
                      if (_teks(v['catatan']).isNotEmpty)
                        Text('Catatan: ${_teks(v['catatan'])}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (sup.isNotEmpty)
        SectionCard(
          title: 'Suplemen',
          icon: Icons.medication_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in sup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_namaSuplemen[_teks(s['jenis'])] ?? _teks(s['jenis']),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      if (_teks(s['keterangan_dosis']).isNotEmpty)
                        Text('Dosis: ${_teks(s['keterangan_dosis'])}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.teksRedup)),
                      if (_teks(s['catatan']).isNotEmpty)
                        Text('Catatan: ${_teks(s['catatan'])}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}