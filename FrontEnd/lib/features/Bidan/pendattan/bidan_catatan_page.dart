import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../service/kbm_model.dart';
import '../../../service/vaksin_service.dart';
import '../vaksin/bidan_vaksin_anak_page.dart';

const _hijauHeader = Color(0xFF065F46);

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
    decoration: BoxDecoration(
      color: AppColors.kuningMuda,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.kuning.withValues(alpha: 0.35)),
    ),
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
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Pendataan dapat dilakukan mulai ${formatTanggal(mulai)} '
                'pukul ${_jamMenit(mulai)} WIB.',
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Satu baris suplemen yang diinput manual oleh bidan.
class _BarisSuplemen {
  final TextEditingController nama;
  final TextEditingController dosis;
  final TextEditingController catatan;
  int jumlah;
  String satuan;

  _BarisSuplemen({
    String nama = '',
    String dosis = '',
    String catatan = '',
    this.jumlah = 1,
    this.satuan = 'kapsul',
  })  : nama = TextEditingController(text: nama),
        dosis = TextEditingController(text: dosis),
        catatan = TextEditingController(text: catatan);

  void dispose() {
    nama.dispose();
    dosis.dispose();
    catatan.dispose();
  }
}

const _satuanSuplemen = <String>[
  'kapsul',
  'tablet',
  'sachet',
  'bungkus',
  'porsi',
  'botol',
  'ml',
  'tetes',
];

/// Pilihan cepat suplemen yang umum di posyandu (dosis mengikuti usia anak,
/// tetap dapat diubah oleh bidan).
class _PresetSuplemen {
  final String label;
  final IconData ikon;
  final _BarisSuplemen Function(int usiaBulan) buat;
  const _PresetSuplemen(this.label, this.ikon, this.buat);
}

final _presetSuplemen = <_PresetSuplemen>[
  _PresetSuplemen(
    'Vitamin A',
    Icons.circle,
    (u) => u >= 12
        ? _BarisSuplemen(nama: 'Vitamin A (kapsul merah)', dosis: '200.000 IU', satuan: 'kapsul')
        : _BarisSuplemen(nama: 'Vitamin A (kapsul biru)', dosis: '100.000 IU', satuan: 'kapsul'),
  ),
  _PresetSuplemen(
    'Obat Cacing',
    Icons.medication_outlined,
    (u) => _BarisSuplemen(
      nama: 'Obat Cacing (Albendazol)',
      dosis: u < 24 ? '200 mg' : '400 mg',
      satuan: 'tablet',
    ),
  ),
  _PresetSuplemen(
    'PMT',
    Icons.restaurant_outlined,
    (u) => _BarisSuplemen(nama: 'PMT (Pemberian Makanan Tambahan)', satuan: 'porsi'),
  ),
  _PresetSuplemen(
    'Zinc',
    Icons.science_outlined,
    (u) => _BarisSuplemen(nama: 'Zinc', dosis: u < 6 ? '10 mg' : '20 mg', satuan: 'tablet'),
  ),
  _PresetSuplemen(
    'Lainnya',
    Icons.add,
    (u) => _BarisSuplemen(),
  ),
];

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

class BidanCatatanPage extends StatefulWidget {
  final String pendaftaranId;
  final String nomor;

  const BidanCatatanPage({
    super.key,
    required this.pendaftaranId,
    required this.nomor,
  });

  @override
  State<BidanCatatanPage> createState() => _BidanCatatanPageState();
}

class _BidanCatatanPageState extends State<BidanCatatanPage> {
  final _svcVaksin = VaksinService();

  Map<String, dynamic>? _detail;
  KartuVaksin? _kartu;
  String? _gagalKartu;
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

  /// Vaksin yang dipilih hari ini, kunci "jenisVaksinId|dosisKe".
  final Set<String> _vaksinDipilih = {};

  /// Vaksin yang sudah tersimpan pada kunjungan ini (saat catatan diubah).
  final Set<String> _vaksinSesiIni = {};

  final List<_BarisSuplemen> _suplemen = [];

  /// Waktu mulai sesi posyandu kunjungan ini.
  DateTime? _mulaiSesi;
  Timer? _jam;

  @override
  void initState() {
    super.initState();
    _muat();
    // Cek ulang setiap 30 detik agar tombol simpan terbuka otomatis saat sesi dimulai.
    _jam = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _mulaiSesi != null) setState(() {});
    });
  }

  /// Waktu mulai sesi bila sesi BELUM dimulai; null bila pendataan sudah boleh.
  DateTime? get _mulaiNanti {
    final m = _mulaiSesi;
    if (m == null || !DateTime.now().isBefore(m)) return null;
    return m;
  }

  @override
  void dispose() {
    _jam?.cancel();
    for (final c in [
      _penyakit,
      _keluhan,
      _evaluasi,
      _saranGizi,
      _saranAsuh,
    ]) {
      c.dispose();
    }
    for (final s in _suplemen) {
      s.dispose();
    }
    super.dispose();
  }

  DateTime _hariIni() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _tglApi(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _muat() async {
    try {
      final opsi = Options(
        receiveTimeout: const Duration(seconds: 15),
      );

      final r = await ApiClient.dio.get(
        '/bidan/pendaftaran/${widget.pendaftaranId}',
        options: opsi,
      );

      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];

      final detail = Map<String, dynamic>.from(d as Map);

      // Waktu mulai sesi posyandu (tanggal + jam mulai jadwal).
      final jd = detail['jadwal'];
      DateTime? mulaiSesi;
      if (jd is Map) {
        final t = jd['tanggal']?.toString() ?? '';
        mulaiSesi = _waktuMulaiSesi(
          t.length >= 10 ? DateTime.tryParse(t.substring(0, 10)) : null,
          jd['jam_mulai']?.toString() ?? '',
        );
      }

      // Isi awal dari catatan yang sudah ada.
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
          if (tgl != null && !tgl.isBefore(_hariIni())) {
            _ulang = tgl;
          }
        }
      }

      _vaksinDipilih.clear();
      _vaksinSesiIni.clear();
      final imun = detail['imunisasi'];
      if (imun is List) {
        for (final e in imun) {
          if (e is Map && e['jenis_vaksin_id'] != null) {
            final k = '${e['jenis_vaksin_id']}|${e['dosis_ke']}';
            _vaksinDipilih.add(k);
            _vaksinSesiIni.add(k);
          }
        }
      }

      for (final s in _suplemen) {
        s.dispose();
      }
      _suplemen.clear();
      final sup = detail['suplemen'];
      if (sup is List) {
        for (final e in sup) {
          if (e is! Map) continue;
          final jenis = e['jenis']?.toString() ?? '';
          if (jenis.isEmpty) continue;
          final dosis = e['dosis']?.toString() ?? '';
          final satuan = e['satuan']?.toString() ?? '';
          final jumlah = int.tryParse(e['jumlah']?.toString() ?? '') ?? 0;
          // data lama: belum ada kolom jumlah, dosis tersimpan di keterangan_dosis
          final dataLama = jumlah < 1;
          _suplemen.add(_BarisSuplemen(
            nama: namaSuplemen(jenis),
            dosis: dataLama ? (e['keterangan_dosis']?.toString() ?? '') : dosis,
            catatan: e['catatan']?.toString() ?? '',
            jumlah: dataLama ? 1 : jumlah,
            satuan: satuan.isEmpty ? 'kapsul' : satuan,
          ));
        }
      }

      // Kartu vaksin anak: jadwal imunisasi + status (untuk rekomendasi hari ini).
      KartuVaksin? kartu;
      String? gagalKartu;
      final anakId = (detail['anak'] is Map) ? (detail['anak']['id']?.toString() ?? '') : '';
      if (anakId.isNotEmpty) {
        try {
          kartu = await _svcVaksin.kartuAnak(anakId);
        } catch (e) {
          gagalKartu = e.toString().replaceFirst('Exception: ', '');
        }
      }

      if (!mounted) return;

      setState(() {
        _detail = detail;
        _mulaiSesi = mulaiSesi;
        _kartu = kartu;
        _gagalKartu = gagalKartu;
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

    if (hasil != null) {
      setState(() => _ulang = hasil);
    }
  }

  Future<void> _simpan() async {
    if (_kirim) return;

    final mulai = _mulaiNanti;
    if (mulai != null) {
      _snack('Sesi belum dimulai. Pendataan dapat dilakukan mulai pukul ${_jamMenit(mulai)} WIB');
      return;
    }

    for (final s in _suplemen) {
      if (s.nama.text.trim().isEmpty) {
        _snack('Isi nama suplemen pada setiap baris atau hapus baris yang kosong');
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
          'tanggal_kunjungan_ulang':
              _ulang == null ? '' : _tglApi(_ulang!),
          'vaksin': [
            for (final k in _vaksinDipilih)
              {
                'jenis_vaksin_id': k.split('|').first,
                'dosis_ke': int.tryParse(k.split('|').last) ?? 1,
              }
          ],
          'suplemen': [
            for (final s in _suplemen)
              {
                'nama': s.nama.text.trim(),
                'dosis': s.dosis.text.trim(),
                'jumlah': s.jumlah,
                'satuan': s.satuan,
                'catatan': s.catatan.text.trim(),
              }
          ],
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
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
        labelStyle: const TextStyle(fontSize: 15),
        filled: true,
        fillColor: AppColors.latar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Widget _teks(
    TextEditingController c,
    String label, {
    int baris = 2,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: baris,
          style: const TextStyle(fontSize: 16.5),
          decoration: _dekor(label),
        ),
      );

  String _num(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    if (d == null) return '-';
    return d == d.roundToDouble()
        ? d.toStringAsFixed(0)
        : d.toString();
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
                child: _judulTebal('Catatan Bidan · ${widget.nomor}'),
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
              child: _memuat
                  ? const Center(child: CircularProgressIndicator())
                  : _gagal != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _gagal!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                AppButton(
                                  'Coba Lagi',
                                  icon: Icons.refresh,
                                  onPressed: () {
                                    setState(() => _memuat = true);
                                    _muat();
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isi(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: (_memuat || _gagal != null)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    _mulaiNanti != null
                        ? 'Sesi Belum Dimulai'
                        : (_kirim ? 'Menyimpan...' : 'Simpan Catatan'),
                    icon: _mulaiNanti != null ? Icons.lock_clock : Icons.save_outlined,
                    onPressed: _kirim ? () {} : _simpan,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _isi() {
    final d = _detail!;

    final anak = d['anak'] is Map
        ? Map<String, dynamic>.from(d['anak'] as Map)
        : <String, dynamic>{};

    final ukur = d['pengukuran'] is Map
        ? Map<String, dynamic>.from(d['pengukuran'] as Map)
        : <String, dynamic>{};

    final prev = d['pengukuran_sebelumnya'] is Map
        ? Map<String, dynamic>.from(d['pengukuran_sebelumnya'] as Map)
        : null;

    final usia = int.tryParse(d['usia_bulan']?.toString() ?? '') ?? 0;
    final lahirAnak = DateTime.tryParse(
        (anak['tanggal_lahir']?.toString() ?? '').length >= 10
            ? anak['tanggal_lahir'].toString().substring(0, 10)
            : '');
    final usiaTeks = lahirAnak != null
        ? usiaDariLahir(lahirAnak, DateTime.now())
        : (usia >= 12 ? '${usia ~/ 12} th ${usia % 12} bln' : '$usia bln');

    final jk = anak['jenis_kelamin']?.toString() == 'P'
        ? 'Perempuan'
        : 'Laki-laki';

    final peringatan =
        ukur['peringatan_validasi']?.toString() ?? '';
    final penilaian = PenilaianTimbang.dari(d['penilaian']);
    final anakId = anak['id']?.toString() ?? '';
    final nama = anak['nama']?.toString() ?? '-';

    final mulaiNanti = _mulaiNanti;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (mulaiNanti != null) _bannerBelumMulai(mulaiNanti),
        SectionCard(
          title: nama,
          icon: Icons.child_care,
          trailing: Pill('Antrean ${widget.nomor}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$jk · $usiaTeks',
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.teksRedup,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatBox(
                      nilai: _num(ukur['bb_kg']),
                      label: 'BB (kg)',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: StatBox(
                      nilai: _num(ukur['tb_cm']),
                      label: 'TB (cm)',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: StatBox(
                      nilai: _num(ukur['lingkar_kepala_cm']),
                      label: 'LK (cm)',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: StatBox(
                      nilai: _num(ukur['lila_cm']),
                      label: 'LiLA (cm)',
                    ),
                  ),
                ],
              ),
              if (penilaian != null) ...[
                const SizedBox(height: 10),
                KotakPenilaian(p: penilaian),
              ],
              if (prev != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Kunjungan sebelumnya: BB ${_num(prev['bb_kg'])} kg · TB ${_num(prev['tb_cm'])} cm',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.teksRedup,
                  ),
                ),
              ],
              if ((ukur['keluhan']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Keluhan (kader): ${ukur['keluhan']}',
                  style: const TextStyle(fontSize: 14.5),
                ),
              ],
              if ((ukur['catatan']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Catatan kader: ${ukur['catatan']}',
                  style: const TextStyle(fontSize: 14.5),
                ),
              ],
              if (ukur['sedang_sakit'] == true) ...[
                const SizedBox(height: 6),
                const Pill(
                  'Anak sedang sakit',
                  bg: AppColors.merahMuda,
                  fg: AppColors.merah,
                ),
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
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.merah,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          peringatan,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (anakId.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    'Jadwal & Riwayat Vaksin',
                    icon: Icons.vaccines_outlined,
                    filled: false,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BidanVaksinAnakPage(
                            anakId: anakId,
                            namaAnak: nama,
                            usia: usiaTeks,
                          ),
                        ),
                      );
                      _muatKartu(anakId);
                    },
                  ),
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
                    labelStyle: const TextStyle(fontSize: 15),
                    selected: _demam,
                    onSelected: (v) => setState(() => _demam = v),
                  ),
                  FilterChip(
                    label: const Text('Diare'),
                    labelStyle: const TextStyle(fontSize: 15),
                    selected: _diare,
                    onSelected: (v) => setState(() => _diare = v),
                  ),
                  FilterChip(
                    label: const Text('Batuk'),
                    labelStyle: const TextStyle(fontSize: 15),
                    selected: _batuk,
                    onSelected: (v) => setState(() => _batuk = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _teks(_penyakit, 'Penyakit penyerta'),
              _teks(_keluhan, 'Keluhan'),
              _teks(_evaluasi, 'Catatan evaluasi', baris: 3),
              _teks(_saranGizi, 'Saran gizi', baris: 3),
              _teks(_saranAsuh, 'Saran pola asuh', baris: 3),
              const Text(
                'Tanggal kunjungan ulang',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
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
                            const Icon(
                              Icons.event,
                              size: 20,
                              color: AppColors.hijau,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _ulang == null
                                  ? 'Tidak dijadwalkan'
                                  : formatTanggal(_ulang!),
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_ulang != null)
                    IconButton(
                      onPressed: () => setState(() => _ulang = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ],
          ),
        ),
        _kartuImunisasi(),
        _kartuSuplemen(usia),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _muatKartu(String anakId) async {
    try {
      final k = await _svcVaksin.kartuAnak(anakId);
      if (!mounted) return;
      setState(() {
        _kartu = k;
        _gagalKartu = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _gagalKartu = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // -------------------------------------------------------------------------
  // IMUNISASI HARI INI: dosis yang jatuh tempo / terlambat sesuai jadwal Kemenkes
  // -------------------------------------------------------------------------
  Widget _kartuImunisasi() {
    final k = _kartu;
    if (k == null) {
      return SectionCard(
        title: 'Imunisasi Hari Ini',
        icon: Icons.vaccines_outlined,
        child: Column(
          children: [
            Text(
              _gagalKartu ?? 'Jadwal imunisasi anak tidak dapat dimuat',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: AppColors.teksRedup),
            ),
            const SizedBox(height: 10),
            AppButton('Muat Ulang', icon: Icons.refresh, filled: false, onPressed: () {
              final id = (_detail?['anak'] is Map) ? (_detail!['anak']['id']?.toString() ?? '') : '';
              if (id.isNotEmpty) _muatKartu(id);
            }),
          ],
        ),
      );
    }

    final calon = k.jadwal
        .where((e) => e.bisaDiberikan || _vaksinSesiIni.contains(e.jadwal.kunci))
        .toList();
    final berikutnya = k.jadwal
        .where((e) =>
            !e.sudah &&
            !e.opsional &&
            (e.status == StatusVaksin.belumWaktunya || e.status == StatusVaksin.menunggu))
        .take(3)
        .toList();

    return SectionCard(
      title: 'Imunisasi Hari Ini',
      icon: Icons.vaccines_outlined,
      trailing: Pill('${_vaksinDipilih.length} dipilih', bg: AppColors.hijauMuda, fg: AppColors.hijau),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            calon.isEmpty
                ? 'Tidak ada vaksin yang dijadwalkan untuk usia anak saat ini.'
                : 'Vaksin sesuai jadwal imunisasi untuk usia ${k.anak.usiaTeks}. Centang yang diberikan hari ini.',
            style: const TextStyle(fontSize: 14.5, color: AppColors.teksRedup),
          ),
          const SizedBox(height: 10),
          for (final e in calon) _barisCalon(e),
          if (berikutnya.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Jadwal berikutnya',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            for (final e in berikutnya)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: AppColors.teksRedup),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${e.jadwal.namaDosis} · '
                        '${e.tanggalJadwal == null ? e.jadwal.labelUsia : formatTanggal(e.tanggalJadwal!)}',
                        style: const TextStyle(fontSize: 14.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _barisCalon(JadwalVaksinAnak e) {
    final kunci = e.jadwal.kunci;
    final dipilih = _vaksinDipilih.contains(kunci);
    final terlambat = e.status == StatusVaksin.terlambat;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: dipilih ? AppColors.hijauMuda : AppColors.latar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dipilih ? AppColors.hijau : Colors.transparent, width: 1.2),
      ),
      child: CheckboxListTile(
        value: dipilih,
        activeColor: AppColors.hijau,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.only(left: 4, right: 10),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onChanged: (v) => setState(() {
          if (v == true) {
            _vaksinDipilih.add(kunci);
          } else {
            _vaksinDipilih.remove(kunci);
          }
        }),
        title: Text(e.jadwal.namaDosis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        subtitle: Text(
          [
            if (e.jadwal.jenis.penyakit.isNotEmpty) 'Mencegah ${e.jadwal.jenis.penyakit}',
            if (e.jadwal.jenis.caraPemberian.isNotEmpty) e.jadwal.jenis.caraPemberian,
          ].join(' · '),
          style: const TextStyle(fontSize: 13.5),
        ),
        secondary: _vaksinSesiIni.contains(kunci)
            ? const Pill('Tersimpan', bg: AppColors.hijauMuda, fg: AppColors.hijau)
            : terlambat
                ? const Pill('Terlambat', bg: AppColors.merahMuda, fg: AppColors.merah)
                : Pill('Usia ${e.jadwal.labelUsia}', bg: AppColors.biruMuda, fg: AppColors.biru),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SUPLEMEN HARI INI: input manual (nama, dosis, jumlah, satuan)
  // -------------------------------------------------------------------------
  Widget _kartuSuplemen(int usia) {
    return SectionCard(
      title: 'Suplemen Hari Ini',
      icon: Icons.medication_outlined,
      trailing: _suplemen.isEmpty
          ? null
          : Pill('${_suplemen.length} item', bg: AppColors.kuningMuda, fg: AppColors.kuning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tambah cepat',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _presetSuplemen)
                ActionChip(
                  avatar: Icon(p.ikon, size: 16, color: AppColors.hijau),
                  label: Text(p.label),
                  labelStyle: const TextStyle(fontSize: 15),
                  backgroundColor: AppColors.latar,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => setState(() => _suplemen.add(p.buat(usia))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_suplemen.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Belum ada suplemen yang diberikan hari ini.',
                  style: TextStyle(fontSize: 14.5, color: AppColors.teksRedup)),
            ),
          for (var i = 0; i < _suplemen.length; i++) _barisSuplemen(i),
        ],
      ),
    );
  }

  Widget _barisSuplemen(int i) {
    final s = _suplemen[i];
    final satuan = {..._satuanSuplemen, s.satuan}.toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.latar, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Suplemen ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Hapus',
                onPressed: () => setState(() => _suplemen.removeAt(i).dispose()),
                icon: const Icon(Icons.delete_outline, color: AppColors.merah),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              children: [
                TextField(
                  controller: s.nama,
                  style: const TextStyle(fontSize: 16.5),
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 100,
                  decoration: _dekor('Nama suplemen').copyWith(counterText: ''),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: s.dosis,
                  style: const TextStyle(fontSize: 16.5),
                  maxLength: 60,
                  decoration: _dekor('Dosis (mis. 200.000 IU, 400 mg)').copyWith(counterText: ''),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.latar,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: s.jumlah > 1 ? () => setState(() => s.jumlah--) : null,
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 38,
                            child: Text('${s.jumlah}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: s.jumlah < 999 ? () => setState(() => s.jumlah++) : null,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: s.satuan,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 16.5, color: Colors.black87),
                        decoration: _dekor('Satuan'),
                        items: [
                          for (final x in satuan) DropdownMenuItem(value: x, child: Text(x)),
                        ],
                        onChanged: (v) => setState(() => s.satuan = v ?? s.satuan),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: s.catatan,
                  style: const TextStyle(fontSize: 16.5),
                  decoration: _dekor('Catatan (opsional)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}