import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../OrangTua/pendaftaran/orangtua_pendaftaran_page.dart';

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class AntreanKader {
  final String pendaftaranId;
  final String anakId;
  final String nama;
  final String jk;
  final int usiaBulan;
  final int? nomor;
  final String sumber;
  final bool sudahDiukur;
  final bool sudahDicatatBidan;

  AntreanKader({
    required this.pendaftaranId,
    required this.anakId,
    required this.nama,
    required this.jk,
    required this.usiaBulan,
    required this.nomor,
    required this.sumber,
    required this.sudahDiukur,
    required this.sudahDicatatBidan,
  });

  factory AntreanKader.fromApi(Map<String, dynamic> j) => AntreanKader(
        pendaftaranId: j['pendaftaran_id']?.toString() ?? '',
        anakId: j['anak_id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        jk: j['jenis_kelamin']?.toString() ?? '',
        usiaBulan: int.tryParse(j['usia_bulan']?.toString() ?? '') ?? 0,
        nomor: int.tryParse(j['nomor_antrean']?.toString() ?? ''),
        sumber: j['sumber']?.toString() ?? '',
        sudahDiukur: j['sudah_diukur'] == true,
        sudahDicatatBidan: j['sudah_dicatat_bidan'] == true,
      );

  String get kodeNomor => nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';

  /// GET /kader/jadwal/:id/antrean (anak yang sudah check-in lewat scan orang tua),
  /// diurutkan berdasarkan nomor antrean.
  static Future<List<AntreanKader>> ambil(String jadwalId) async {
    final r = await ApiClient.dio.get('/kader/jadwal/$jadwalId/antrean',
        options: Options(receiveTimeout: const Duration(seconds: 15)));
    dynamic d = r.data;
    if (d is Map && d.containsKey('data')) d = d['data'];
    if (d is! List) return [];
    final list = d
        .map((e) => AntreanKader.fromApi(Map<String, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => (a.nomor ?? 1 << 30).compareTo(b.nomor ?? 1 << 30));
    return list;
  }
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

String _usia(int bln) => bln >= 12 ? '${bln ~/ 12} th ${bln % 12} bln' : '$bln bln';

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
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      final list = j == null ? <AntreanKader>[] : await AntreanKader.ambil(j.id);
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

  void _bukaQr() {
    final j = _jadwal;
    if (j == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _QrJadwalPage(jadwalId: j.id)),
    );
  }

  Future<void> _ukur(AntreanKader a) async {
    if (a.sudahDicatatBidan) {
      _snack('Data ${a.nama} sudah dicatat bidan dan tidak dapat diubah');
      return;
    }
    final hasil = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FormUkur(anak: a),
    );
    if (hasil != null) {
      _snack(hasil.isEmpty
          ? 'Data pengukuran tersimpan dan diteruskan ke bidan'
          : 'Data tersimpan dan diteruskan ke bidan. Perhatian: $hasil');
      _muat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _jadwal;
    final diukur = _antrean.where((a) => a.sudahDiukur).length;

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Pendataan', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_memuat)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
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
            else if (j == null)
              SectionCard(
                title: 'Jadwal Posyandu',
                icon: Icons.event_busy,
                child: const Text(
                  'Belum ada jadwal posyandu aktif. Antrean pendataan muncul setelah admin menerbitkan jadwal.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                ),
              )
            else ...[
              SectionCard(
                title: 'Sesi Posyandu',
                icon: Icons.event_note,
                trailing: Pill('${_antrean.length} check-in',
                    bg: AppColors.hijauMuda, fg: AppColors.hijau),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatTanggal(j.tanggal)} · ${j.jam} WIB',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    if (j.lokasi.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(j.lokasi,
                          style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatBox(
                              nilai: '${_antrean.length}',
                              label: 'Sudah\ncheck-in',
                              bg: AppColors.biruMuda),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatBox(
                              nilai: '$diukur',
                              label: 'Sudah\ndiukur',
                              bg: AppColors.hijauMuda,
                              fg: AppColors.hijau),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatBox(
                              nilai: '${_antrean.length - diukur}',
                              label: 'Menunggu\npengukuran',
                              bg: AppColors.kuningMuda,
                              fg: AppColors.kuning),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton('Tampilkan QR Check-in untuk Orang Tua',
                          icon: Icons.qr_code_2, filled: false, onPressed: _bukaQr),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Antrean Pendataan',
                icon: Icons.format_list_numbered,
                trailing: const Text('Ketuk untuk mendata',
                    style: TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
                child: _antrean.isEmpty
                    ? const Text(
                        'Belum ada anak. Data anak masuk ke sini setelah orang tua melakukan check-in dengan scan QR.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                      )
                    : Column(children: [for (final a in _antrean) _baris(a)]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _baris(AntreanKader a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _ukur(a),
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
                  child: Text(a.kodeNomor,
                      style: const TextStyle(
                          color: AppColors.hijau, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.nama,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text('${a.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${_usia(a.usiaBulan)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          a.sudahDiukur
                              ? const Pill('Sudah diukur', icon: Icons.check)
                              : const Pill('Belum diukur',
                                  bg: AppColors.kuningMuda, fg: AppColors.kuning),
                          if (a.sudahDicatatBidan)
                            const Pill('Dicatat bidan',
                                bg: AppColors.biruMuda, fg: AppColors.biru)
                          else if (a.sudahDiukur)
                            const Pill('Menunggu bidan',
                                bg: AppColors.biruMuda, fg: AppColors.biru),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  a.sudahDicatatBidan ? Icons.lock_outline : Icons.chevron_right,
                  color: AppColors.teksRedup,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORM PENGUKURAN
// ---------------------------------------------------------------------------
class _FormUkur extends StatefulWidget {
  final AntreanKader anak;
  const _FormUkur({required this.anak});

  @override
  State<_FormUkur> createState() => _FormUkurState();
}

class _FormUkurState extends State<_FormUkur> {
  final _bb = TextEditingController();
  final _tb = TextEditingController();
  final _lk = TextEditingController();
  final _lila = TextEditingController();
  final _keluhan = TextEditingController();
  final _catatan = TextEditingController();
  bool _sakit = false;
  bool _asi = false;
  bool _kirim = false;
  bool _memuat = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    if (widget.anak.sudahDiukur) {
      _memuat = true;
      _muatData();
    }
  }

  @override
  void dispose() {
    for (final c in [_bb, _tb, _lk, _lila, _keluhan, _catatan]) {
      c.dispose();
    }
    super.dispose();
  }

  String _angkaTeks(dynamic v) {
    if (v == null) return '';
    final d = double.tryParse(v.toString());
    if (d == null) return '';
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  Future<void> _muatData() async {
    try {
      final r = await ApiClient.dio.get(
        '/kader/pendaftaran/${widget.anak.pendaftaranId}/pengukuran',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      if (d is Map) {
        _bb.text = _angkaTeks(d['bb_kg']);
        _tb.text = _angkaTeks(d['tb_cm']);
        _lk.text = _angkaTeks(d['lingkar_kepala_cm']);
        _lila.text = _angkaTeks(d['lila_cm']);
        _keluhan.text = d['keluhan']?.toString() ?? '';
        _catatan.text = d['catatan']?.toString() ?? '';
        _sakit = d['sedang_sakit'] == true;
        _asi = d['asi_eksklusif'] == true;
      }
    } catch (e) {
      _galat = _pesanError(e);
    }
    if (mounted) setState(() => _memuat = false);
  }

  double? _angka(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _simpan() async {
    final bb = _angka(_bb);
    final tb = _angka(_tb);
    if (bb == null || tb == null) {
      setState(() => _galat = 'Berat badan dan tinggi/panjang badan wajib diisi dengan angka.');
      return;
    }
    final lk = _angka(_lk);
    final lila = _angka(_lila);

    setState(() {
      _kirim = true;
      _galat = null;
    });
    try {
      final r = await ApiClient.dio.put(
        '/kader/pendaftaran/${widget.anak.pendaftaranId}/pengukuran',
        data: {
          'bb_kg': bb,
          'tb_cm': tb,
          if (lk != null) 'lingkar_kepala_cm': lk,
          if (lila != null) 'lila_cm': lila,
          'keluhan': _keluhan.text.trim(),
          'sedang_sakit': _sakit,
          'asi_eksklusif': _asi,
          'catatan': _catatan.text.trim(),
        },
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      final peringatan = d is Map ? (d['peringatan_validasi']?.toString() ?? '') : '';
      if (mounted) Navigator.pop(context, peringatan);
    } catch (e) {
      if (mounted) {
        setState(() {
          _galat = _pesanError(e);
          _kirim = false;
        });
      }
    }
  }

  Widget _kolom(TextEditingController c, String label, {bool angka = true, int baris = 1}) {
    return TextField(
      controller: c,
      maxLines: baris,
      keyboardType: angka ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.latar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: _memuat
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Pendataan ${widget.anak.nama}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      Pill('Antrean ${widget.anak.kodeNomor}'),
                    ],
                  ),
                  Text(
                      '${widget.anak.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${_usia(widget.anak.usiaBulan)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _kolom(_bb, 'Berat badan (kg)')),
                      const SizedBox(width: 10),
                      Expanded(child: _kolom(_tb, 'Tinggi/panjang (cm)')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _kolom(_lk, 'Lingkar kepala (cm)')),
                      const SizedBox(width: 10),
                      Expanded(child: _kolom(_lila, 'LiLA (cm)')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _kolom(_keluhan, 'Keluhan', angka: false),
                  const SizedBox(height: 10),
                  _kolom(_catatan, 'Catatan', angka: false, baris: 2),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sedang sakit', style: TextStyle(fontSize: 13)),
                    value: _sakit,
                    onChanged: (v) => setState(() => _sakit = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ASI eksklusif', style: TextStyle(fontSize: 13)),
                    value: _asi,
                    onChanged: (v) => setState(() => _asi = v),
                  ),
                  if (_galat != null) ...[
                    const SizedBox(height: 6),
                    Text(_galat!, style: const TextStyle(color: AppColors.merah, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(_kirim ? 'Menyimpan...' : 'Simpan & Teruskan ke Bidan',
                        icon: Icons.send_outlined, onPressed: _kirim ? () {} : _simpan),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR CHECK-IN JADWAL (DIPINDAI ORANG TUA)
// ---------------------------------------------------------------------------
class _QrJadwalPage extends StatefulWidget {
  final String jadwalId;
  const _QrJadwalPage({required this.jadwalId});

  @override
  State<_QrJadwalPage> createState() => _QrJadwalPageState();
}

class _QrJadwalPageState extends State<_QrJadwalPage> {
  String? _kode;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final r = await ApiClient.dio.get('/kader/jadwal/${widget.jadwalId}/qr');
      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      if (!mounted) return;
      setState(() => _kode = (d as Map)['kode_qr']?.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _gagal = _pesanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('QR Check-in Posyandu', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _gagal != null
              ? Text(_gagal!, textAlign: TextAlign.center)
              : _kode == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: QrImageView(data: _kode!, size: 260, backgroundColor: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Orang tua memindai QR ini dari aplikasi untuk check-in.\nCheck-in hanya dibuka 1 jam sebelum jadwal dimulai.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup, height: 1.4),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}