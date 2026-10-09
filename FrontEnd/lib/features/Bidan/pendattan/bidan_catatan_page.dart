import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../vaksin/bidan_vaksin_anak_page.dart';

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

class _JenisVaksin {
  final String id;
  final String nama;
  final int jumlahDosis;
  _JenisVaksin(this.id, this.nama, this.jumlahDosis);

  factory _JenisVaksin.fromApi(Map<String, dynamic> j) => _JenisVaksin(
        j['id']?.toString() ?? '',
        (j['nama'] ?? j['nama_vaksin'] ?? '-').toString(),
        int.tryParse(j['jumlah_dosis']?.toString() ?? '') ?? 1,
      );
}

class _BarisVaksin {
  String? jenisId;
  int dosis;
  _BarisVaksin({this.jenisId, this.dosis = 1});
}

const _jenisSuplemen = <(String, String)>[
  ('vitamin_a', 'Vitamin A'),
  ('obat_cacing', 'Obat cacing'),
  ('pmt', 'PMT'),
];

class BidanCatatanPage extends StatefulWidget {
  final String pendaftaranId;
  final String nomor;

  const BidanCatatanPage({super.key, required this.pendaftaranId, required this.nomor});

  @override
  State<BidanCatatanPage> createState() => _BidanCatatanPageState();
}

class _BidanCatatanPageState extends State<BidanCatatanPage> {
  Map<String, dynamic>? _detail;
  List<_JenisVaksin> _jenis = [];
  bool _memuat = true;
  bool _kirim = false;
  String? _gagal;

  bool _demam = false;
  bool _diare = false;
  bool _batuk = false;
  final _penyakit = TextEditingController();
  final _keluhan = TextEditingController();
  final _evaluasi = TextEditingController();
  final _saranGizi = TextEditingController();
  final _saranAsuh = TextEditingController();
  DateTime? _ulang;
  final List<_BarisVaksin> _vaksin = [];
  final Set<String> _suplemen = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final c in [_penyakit, _keluhan, _evaluasi, _saranGizi, _saranAsuh]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime _hariIni() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _tglApi(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _muat() async {
    try {
      final opsi = Options(receiveTimeout: const Duration(seconds: 15));
      final r = await ApiClient.dio.get('/bidan/pendaftaran/${widget.pendaftaranId}', options: opsi);
      final rv = await ApiClient.dio.get('/vaksin', options: opsi);

      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      dynamic v = rv.data;
      if (v is Map && v.containsKey('data')) v = v['data'];

      final detail = Map<String, dynamic>.from(d as Map);
      final jenis = (v is List)
          ? v.map((e) => _JenisVaksin.fromApi(Map<String, dynamic>.from(e as Map))).toList()
          : <_JenisVaksin>[];

      // isi awal dari catatan yang sudah ada
      final c = detail['catatan'];
      if (c is Map) {
        _demam = c['demam'] == true;
        _diare = c['diare'] == true;
        _batuk = c['batuk'] == true;
        _penyakit.text = c['penyakit_penyerta']?.toString() ?? '';
        _keluhan.text = c['keluhan']?.toString() ?? '';
        _evaluasi.text = c['catatan_evaluasi']?.toString() ?? '';
        _saranGizi.text = c['saran_gizi']?.toString() ?? '';
        _saranAsuh.text = c['saran_pola_asuh']?.toString() ?? '';
        final t = c['tanggal_kunjungan_ulang']?.toString() ?? '';
        if (t.length >= 10) {
          final tgl = DateTime.tryParse(t.substring(0, 10));
          if (tgl != null && !tgl.isBefore(_hariIni())) _ulang = tgl;
        }
      }
      final imun = detail['imunisasi'];
      if (imun is List) {
        for (final e in imun) {
          if (e is Map) {
            _vaksin.add(_BarisVaksin(
              jenisId: e['jenis_vaksin_id']?.toString(),
              dosis: int.tryParse(e['dosis_ke']?.toString() ?? '') ?? 1,
            ));
          }
        }
      }
      final sup = detail['suplemen'];
      if (sup is List) {
        for (final e in sup) {
          if (e is Map && e['jenis'] != null) _suplemen.add(e['jenis'].toString());
        }
      }

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _jenis = jenis;
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

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _ulang ?? _hariIni(),
      firstDate: _hariIni(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (hasil != null) setState(() => _ulang = hasil);
  }

  _JenisVaksin? _cariJenis(String? id) {
    for (final j in _jenis) {
      if (j.id == id) return j;
    }
    return null;
  }

  Future<void> _simpan() async {
    if (_kirim) return;
    for (final b in _vaksin) {
      if (b.jenisId == null) {
        _snack('Pilih jenis vaksin pada setiap baris vaksin atau hapus baris yang kosong');
        return;
      }
    }
    setState(() => _kirim = true);
    try {
      await ApiClient.dio.put(
        '/bidan/pendaftaran/${widget.pendaftaranId}/catatan',
        data: {
          'demam': _demam,
          'diare': _diare,
          'batuk': _batuk,
          'penyakit_penyerta': _penyakit.text.trim(),
          'keluhan': _keluhan.text.trim(),
          'catatan_evaluasi': _evaluasi.text.trim(),
          'saran_gizi': _saranGizi.text.trim(),
          'saran_pola_asuh': _saranAsuh.text.trim(),
          'tanggal_kunjungan_ulang': _ulang == null ? '' : _tglApi(_ulang!),
          'vaksin': [
            for (final b in _vaksin) {'jenis_vaksin_id': b.jenisId, 'dosis_ke': b.dosis}
          ],
          'suplemen': [
            for (final s in _suplemen) {'jenis': s}
          ],
        },
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      if (!mounted) return;
      _snack('Catatan bidan tersimpan');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _kirim = false);
      _snack(_pesanError(e));
    }
  }

  InputDecoration _dekor(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.latar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Widget _teks(TextEditingController c, String label, {int baris = 2}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, maxLines: baris, decoration: _dekor(label)),
      );

  String _num(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    if (d == null) return '-';
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: Text('Catatan Bidan · ${widget.nomor}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : _gagal != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_gagal!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        AppButton('Coba Lagi', icon: Icons.refresh, onPressed: () {
                          setState(() => _memuat = true);
                          _muat();
                        }),
                      ],
                    ),
                  ),
                )
              : _isi(),
      bottomNavigationBar: (_memuat || _gagal != null)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: AppButton(_kirim ? 'Menyimpan...' : 'Simpan Catatan',
                      icon: Icons.save_outlined, onPressed: _kirim ? () {} : _simpan),
                ),
              ),
            ),
    );
  }

  Widget _isi() {
    final d = _detail!;
    final anak = d['anak'] is Map ? Map<String, dynamic>.from(d['anak'] as Map) : <String, dynamic>{};
    final ukur = d['pengukuran'] is Map ? Map<String, dynamic>.from(d['pengukuran'] as Map) : <String, dynamic>{};
    final prev = d['pengukuran_sebelumnya'] is Map
        ? Map<String, dynamic>.from(d['pengukuran_sebelumnya'] as Map)
        : null;
    final usia = int.tryParse(d['usia_bulan']?.toString() ?? '') ?? 0;
    final usiaTeks = usia >= 12 ? '${usia ~/ 12} th ${usia % 12} bln' : '$usia bln';
    final jk = anak['jenis_kelamin']?.toString() == 'P' ? 'Perempuan' : 'Laki-laki';
    final peringatan = ukur['peringatan_validasi']?.toString() ?? '';
    final anakId = anak['id']?.toString() ?? '';
    final nama = anak['nama']?.toString() ?? '-';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: nama,
          icon: Icons.child_care,
          trailing: Pill('Antrean ${widget.nomor}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$jk · $usiaTeks',
                  style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: StatBox(nilai: _num(ukur['bb_kg']), label: 'BB (kg)')),
                  const SizedBox(width: 6),
                  Expanded(child: StatBox(nilai: _num(ukur['tb_cm']), label: 'TB (cm)')),
                  const SizedBox(width: 6),
                  Expanded(child: StatBox(nilai: _num(ukur['lingkar_kepala_cm']), label: 'LK (cm)')),
                  const SizedBox(width: 6),
                  Expanded(child: StatBox(nilai: _num(ukur['lila_cm']), label: 'LiLA (cm)')),
                ],
              ),
              if (prev != null) ...[
                const SizedBox(height: 8),
                Text('Kunjungan sebelumnya: BB ${_num(prev['bb_kg'])} kg · TB ${_num(prev['tb_cm'])} cm',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
              ],
              if ((ukur['keluhan']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Keluhan (kader): ${ukur['keluhan']}', style: const TextStyle(fontSize: 12)),
              ],
              if ((ukur['catatan']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Catatan kader: ${ukur['catatan']}', style: const TextStyle(fontSize: 12)),
              ],
              if (ukur['sedang_sakit'] == true) ...[
                const SizedBox(height: 6),
                const Pill('Anak sedang sakit', bg: AppColors.merahMuda, fg: AppColors.merah),
              ],
              if (peringatan.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.merahMuda,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.merah, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(peringatan, style: const TextStyle(fontSize: 11.5))),
                    ],
                  ),
                ),
              ],
              if (anakId.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: AppButton('Jadwal & Riwayat Vaksin',
                      icon: Icons.vaccines_outlined,
                      filled: false,
                      onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BidanVaksinAnakPage(
                                anakId: anakId,
                                namaAnak: nama,
                                usia: usiaTeks,
                              ),
                            ),
                          )),
                ),
              ],
            ],
          ),
        ),
        SectionCard(
          title: 'Pemeriksaan Singkat',
          icon: Icons.medical_services_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                      label: const Text('Demam'),
                      selected: _demam,
                      onSelected: (v) => setState(() => _demam = v)),
                  FilterChip(
                      label: const Text('Diare'),
                      selected: _diare,
                      onSelected: (v) => setState(() => _diare = v)),
                  FilterChip(
                      label: const Text('Batuk'),
                      selected: _batuk,
                      onSelected: (v) => setState(() => _batuk = v)),
                ],
              ),
              const SizedBox(height: 10),
              _teks(_penyakit, 'Penyakit penyerta'),
              _teks(_keluhan, 'Keluhan'),
              _teks(_evaluasi, 'Catatan evaluasi', baris: 3),
              _teks(_saranGizi, 'Saran gizi', baris: 3),
              _teks(_saranAsuh, 'Saran pola asuh', baris: 3),
              const Text('Tanggal kunjungan ulang',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pilihTanggal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.latar,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 20, color: AppColors.hijau),
                            const SizedBox(width: 10),
                            Text(_ulang == null ? 'Tidak dijadwalkan' : formatTanggal(_ulang!),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_ulang != null)
                    IconButton(
                        onPressed: () => setState(() => _ulang = null),
                        icon: const Icon(Icons.close)),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Imunisasi Hari Ini',
          icon: Icons.vaccines_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _vaksin.length; i++) _barisVaksin(i),
              SizedBox(
                width: double.infinity,
                child: AppButton('Tambah Vaksin',
                    icon: Icons.add,
                    filled: false,
                    onPressed: () => setState(() => _vaksin.add(_BarisVaksin()))),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Suplemen Hari Ini',
          icon: Icons.medication_outlined,
          child: Wrap(
            spacing: 8,
            children: [
              for (final s in _jenisSuplemen)
                FilterChip(
                  label: Text(s.$2),
                  selected: _suplemen.contains(s.$1),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _suplemen.add(s.$1);
                    } else {
                      _suplemen.remove(s.$1);
                    }
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _barisVaksin(int i) {
    final b = _vaksin[i];
    final jenis = _cariJenis(b.jenisId);
    final maks = jenis?.jumlahDosis ?? 1;
    if (b.dosis > maks) b.dosis = maks;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: jenis?.id,
              isExpanded: true,
              decoration: _dekor('Vaksin'),
              items: [
                for (final j in _jenis)
                  DropdownMenuItem(
                      value: j.id, child: Text(j.nama, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                b.jenisId = v;
                b.dosis = 1;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              value: b.dosis,
              decoration: _dekor('Dosis'),
              items: [
                for (var d = 1; d <= maks; d++)
                  DropdownMenuItem(value: d, child: Text('Ke-$d')),
              ],
              onChanged: (v) => setState(() => b.dosis = v ?? 1),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _vaksin.removeAt(i)),
            icon: const Icon(Icons.delete_outline, color: AppColors.merah),
          ),
        ],
      ),
    );
  }
}