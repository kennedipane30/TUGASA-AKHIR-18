import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../service/kbm_model.dart';
import '../../../service/vaksin_service.dart';
import '../../OrangTua/pendaftaran/orangtua_pendaftaran_page.dart' show RencanaAnakJadwal;
import '../vaksin/bidan_vaksin_anak_page.dart';
import '../vaksin/vaksin_lihat_body.dart' show tampilkanBuktiVaksin;

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

  return e.toString().replaceFirst('Exception: ', '');
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

/// Kotak informasi berwarna (peringatan / petunjuk).
Widget _info(String teks, {IconData ikon = Icons.info_outline, Color bg = AppColors.biruMuda, Color fg = AppColors.biru}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 18, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(teks, style: const TextStyle(fontSize: 14, height: 1.35))),
      ],
    ),
  );
}

bool _namaVitaminA(String n) {
  final s = n.toLowerCase();
  return s == 'vitamin_a' || s.contains('vitamin a') || s.contains('vit a') || s.contains('vit. a');
}

bool _namaObatCacing(String n) {
  final s = n.toLowerCase();
  return s == 'obat_cacing' || s.contains('cacing') || s.contains('albendazol') || s.contains('pirantel');
}

/// Satu baris suplemen. [tetap] = Vitamin A / obat cacing: nama, dosis, dan jumlah (1) tidak diubah.
class _BarisSuplemen {
  final TextEditingController nama;
  final TextEditingController dosis;
  final TextEditingController catatan;
  int jumlah;
  String satuan;
  final bool tetap;

  _BarisSuplemen({
    String nama = '',
    String dosis = '',
    String catatan = '',
    this.jumlah = 1,
    this.satuan = 'kapsul',
    this.tetap = false,
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

_BarisSuplemen _vitaminA(int usia) => usia >= 12
    ? _BarisSuplemen(nama: 'Vitamin A (kapsul merah)', dosis: '200.000 IU', satuan: 'kapsul', tetap: true)
    : _BarisSuplemen(nama: 'Vitamin A (kapsul biru)', dosis: '100.000 IU', satuan: 'kapsul', tetap: true);

_BarisSuplemen _obatCacing(int usia) => _BarisSuplemen(
      nama: 'Obat Cacing (Albendazol)',
      dosis: usia < 24 ? '200 mg' : '400 mg',
      satuan: 'tablet',
      tetap: true,
    );

/// Vaksin yang dipilih hari ini beserta nomor batch dan reaksi (opsional).
class _PilihVaksin {
  final TextEditingController batch;
  final TextEditingController reaksi;

  _PilihVaksin({String batch = '', String reaksi = ''})
      : batch = TextEditingController(text: batch),
        reaksi = TextEditingController(text: reaksi);

  void dispose() {
    batch.dispose();
    reaksi.dispose();
  }
}

/// Judul header ekstra tebal (sama seperti halaman Akun).
Widget _judulTebal(String teks) {
  const ukuran = 20.0;
  const jarak = 1.2;

  return Stack(
    children: [
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
            Shadow(color: Color(0x40000000), offset: Offset(0, 1), blurRadius: 2),
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
  bool _prosesRiwayat = false;
  String? _gagal;

  final _keluhan = TextEditingController();
  final _catatanOrtu = TextEditingController();
  final _saranGizi = TextEditingController();

  DateTime? _ulang;

  /// Riwayat vaksin sebelum posyandu.
  String _statusRiwayat = StatusRiwayatVaksin.belumDitanya;
  List<RiwayatVaksin> _riwayatLuar = [];

  /// Vaksin yang dipilih hari ini, kunci "jenisVaksinId|dosisKe".
  final Map<String, _PilihVaksin> _vaksinDipilih = {};

  /// Vaksin yang sudah tersimpan pada kunjungan ini (saat catatan diubah).
  final Set<String> _vaksinSesiIni = {};

  /// Kondisi anak sebelum imunisasi: sehat | demam_ringan | sakit.
  String? _kondisi;

  final List<_BarisSuplemen> _suplemen = [];

  /// Vaksin & suplemen dipilih otomatis sesuai jadwal (catatan belum pernah disimpan).
  bool _otomatis = false;

  DateTime? _mulaiSesi;
  Timer? _jam;

  bool get _riwayatOk => _statusRiwayat == StatusRiwayatVaksin.dikonfirmasi;

  @override
  void initState() {
    super.initState();
    _muat();
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
    for (final c in [_keluhan, _catatanOrtu, _saranGizi]) {
      c.dispose();
    }
    for (final v in _vaksinDipilih.values) {
      v.dispose();
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

  int get _usiaBulan => int.tryParse(_detail?['usia_bulan']?.toString() ?? '') ?? 0;

  String get _anakId =>
      (_detail?['anak'] is Map) ? (_detail!['anak']['id']?.toString() ?? '') : '';

  DateTime? get _lahir {
    final a = _detail?['anak'];
    if (a is! Map) return null;
    final t = a['tanggal_lahir']?.toString() ?? '';
    return t.length >= 10 ? DateTime.tryParse(t.substring(0, 10)) : null;
  }

  Future<void> _muat() async {
    try {
      final r = await ApiClient.dio.get(
        '/bidan/pendaftaran/${widget.pendaftaranId}',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];
      final detail = Map<String, dynamic>.from(d as Map);

      // Waktu mulai sesi posyandu.
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
        _keluhan.text = c['keluhan']?.toString() ?? '';
        _catatanOrtu.text = c['catatan_evaluasi']?.toString() ?? '';
        _saranGizi.text = c['saran_gizi']?.toString() ?? '';
        final t = c['tanggal_kunjungan_ulang']?.toString() ?? '';
        _ulang = null;
        if (t.length >= 10) {
          final tgl = DateTime.tryParse(t.substring(0, 10));
          if (tgl != null && !tgl.isBefore(_hariIni())) _ulang = tgl;
        }
      }

      // Riwayat vaksin sebelum posyandu.
      final status = detail['status_riwayat_vaksin']?.toString() ?? '';
      final luar = <RiwayatVaksin>[];
      final rl = detail['riwayat_luar'];
      if (rl is List) {
        for (final e in rl) {
          if (e is Map) luar.add(RiwayatVaksin.fromJson(Map<String, dynamic>.from(e)));
        }
      }

      // Vaksin yang sudah tersimpan pada kunjungan ini.
      for (final v in _vaksinDipilih.values) {
        v.dispose();
      }
      _vaksinDipilih.clear();
      _vaksinSesiIni.clear();
      _kondisi = null;
      final imun = detail['imunisasi'];
      if (imun is List) {
        for (final e in imun) {
          if (e is Map && e['jenis_vaksin_id'] != null) {
            final k = '${e['jenis_vaksin_id']}|${e['dosis_ke']}';
            _vaksinDipilih[k] = _PilihVaksin(
              batch: e['nomor_batch']?.toString() ?? '',
              reaksi: e['reaksi_kipi']?.toString() ?? '',
            );
            _vaksinSesiIni.add(k);
            final kond = e['kondisi_anak']?.toString() ?? '';
            if (kond == KondisiImunisasi.sehat || kond == KondisiImunisasi.demamRingan) _kondisi = kond;
          }
        }
      }

      // Suplemen yang sudah tersimpan.
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
          final dataLama = jumlah < 1;
          _suplemen.add(_BarisSuplemen(
            nama: namaSuplemen(jenis),
            dosis: dataLama ? (e['keterangan_dosis']?.toString() ?? '') : dosis,
            catatan: e['catatan']?.toString() ?? '',
            jumlah: dataLama ? 1 : jumlah,
            satuan: satuan.isEmpty ? 'kapsul' : satuan,
            tetap: _namaVitaminA(jenis) || _namaObatCacing(jenis),
          ));
        }
      }

      // Catatan belum pernah disimpan: vaksin & suplemen sesuai jadwal dipilih otomatis.
      final rRaw = detail['rencana'];
      final rencana = rRaw is Map ? RencanaAnakJadwal.fromApi(Map<String, dynamic>.from(rRaw)) : null;
      final usiaBln = int.tryParse(detail['usia_bulan']?.toString() ?? '') ?? 0;
      var otomatis = false;
      if (rencana != null && c is! Map) {
        if (status == StatusRiwayatVaksin.dikonfirmasi) {
          for (final it in rencana.imunisasi) {
            if (it.jenisVaksinId.isEmpty) continue;
            final k = '${it.jenisVaksinId}|${it.dosisKe}';
            if (!_vaksinDipilih.containsKey(k)) {
              _vaksinDipilih[k] = _PilihVaksin();
              otomatis = true;
            }
          }
        }
        for (final it in rencana.suplemen) {
          if (_suplemenAda(it.jenis)) continue;
          _suplemen.add(it.jenis == 'vitamin_a' ? _vitaminA(usiaBln) : _obatCacing(usiaBln));
          otomatis = true;
        }
      }

      // Kartu vaksin anak (jadwal + status).
      KartuVaksin? kartu;
      String? gagalKartu;
      final anakId = (detail['anak'] is Map) ? (detail['anak']['id']?.toString() ?? '') : '';
      if (anakId.isNotEmpty) {
        try {
          kartu = await _svcVaksin.kartuAnak(anakId);
        } catch (e) {
          gagalKartu = _pesanError(e);
        }
      }

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _mulaiSesi = mulaiSesi;
        _statusRiwayat = status.isEmpty ? StatusRiwayatVaksin.belumDitanya : status;
        _riwayatLuar = luar;
        _kartu = kartu;
        _gagalKartu = gagalKartu;
        _otomatis = otomatis;
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

  bool _suplemenAda(String jenis) {
    for (final s in _suplemen) {
      final n = s.nama.text;
      if (jenis == 'vitamin_a' && _namaVitaminA(n)) return true;
      if (jenis == 'obat_cacing' && _namaObatCacing(n)) return true;
    }
    return false;
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

  // -------------------------------------------------------------------------
  // SIMPAN
  // -------------------------------------------------------------------------
  Future<void> _simpan() async {
    if (_kirim) return;

    final mulai = _mulaiNanti;
    if (mulai != null) {
      _snack('Sesi belum dimulai. Pendataan dapat dilakukan mulai pukul ${_jamMenit(mulai)} WIB');
      return;
    }
    if (_vaksinDipilih.isNotEmpty) {
      if (!_riwayatOk) {
        _snack('Konfirmasi riwayat vaksin anak terlebih dahulu');
        return;
      }
      if (_kondisi == null) {
        _snack('Pilih kondisi anak sebelum imunisasi');
        return;
      }
      if (_kondisi == KondisiImunisasi.sakit) {
        _snack('Anak sedang sakit. Hapus centang vaksin dan tunda imunisasi.');
        return;
      }
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
          'keluhan': _keluhan.text.trim(),
          'catatan_evaluasi': _catatanOrtu.text.trim(),
          'saran_gizi': _saranGizi.text.trim(),
          'tanggal_kunjungan_ulang': _ulang == null ? '' : _tglApi(_ulang!),
          'vaksin': [
            for (final e in _vaksinDipilih.entries)
              {
                'jenis_vaksin_id': e.key.split('|').first,
                'dosis_ke': int.tryParse(e.key.split('|').last) ?? 1,
                'kondisi_anak': _kondisi ?? '',
                'nomor_batch': e.value.batch.text.trim(),
                'reaksi_kipi': e.value.reaksi.text.trim(),
              }
          ],
          'suplemen': [
            for (final s in _suplemen)
              {
                'nama': s.nama.text.trim(),
                'dosis': s.dosis.text.trim(),
                'jumlah': s.tetap ? 1 : s.jumlah,
                'satuan': s.satuan,
                'catatan': s.catatan.text.trim(),
              }
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

  // -------------------------------------------------------------------------
  // RIWAYAT VAKSIN SEBELUM POSYANDU
  // -------------------------------------------------------------------------
  Future<void> _jalankan(Future<void> Function() aksi, String sukses) async {
    if (_prosesRiwayat) return;
    setState(() => _prosesRiwayat = true);
    try {
      await aksi();
      _snack(sukses);
      await _muat();
    } catch (e) {
      _snack(_pesanError(e));
    } finally {
      if (mounted) setState(() => _prosesRiwayat = false);
    }
  }

  Future<void> _benarkan(RiwayatVaksin r) =>
      _jalankan(() => _svcVaksin.konfirmasiRiwayat(r.id), '${r.namaDosis} dikonfirmasi');

  Future<void> _ubahTanggal(RiwayatVaksin r) async {
    final lahir = _lahir ?? DateTime(2000);
    final t = await showDatePicker(
      context: context,
      initialDate: r.tanggal ?? _hariIni(),
      firstDate: lahir,
      lastDate: _hariIni(),
      helpText: 'Tanggal ${r.jenis.nama} dosis ${r.dosisKe}',
    );
    if (t == null) return;
    await _jalankan(
      () => _svcVaksin.konfirmasiRiwayat(r.id, tanggal: t),
      'Tanggal diperbaiki dan dikonfirmasi',
    );
  }

  Future<void> _batalkan(RiwayatVaksin r) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan catatan vaksin?'),
        content: Text(
          '${r.namaDosis} akan dihapus dari riwayat. Gunakan bila orang tua menyatakan '
          'anak ternyata belum menerima vaksin ini.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan')),
        ],
      ),
    );
    if (ya != true) return;
    await _jalankan(() => _svcVaksin.hapusRiwayat(r.id), 'Catatan vaksin dibatalkan');
  }

  Future<void> _selesaiKonfirmasi() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Riwayat vaksin sudah benar?'),
        content: const Text(
          'Pastikan Anda sudah menanyakan kepada orang tua semua vaksin yang pernah '
          'diterima anak di luar posyandu. Setelah dikonfirmasi, imunisasi hari ini dapat diberikan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Periksa lagi')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, sudah benar')),
        ],
      ),
    );
    if (ya != true) return;
    await _jalankan(() => _svcVaksin.selesaiKonfirmasi(_anakId), 'Riwayat vaksin dikonfirmasi');
  }

  Future<void> _tambahDariLuar() async {
    final k = _kartu;
    if (k == null) {
      _snack('Jadwal vaksin anak belum dimuat');
      return;
    }
    final pilihan = k.jadwal
        .where((e) => !e.sudah && !e.opsional && e.status != StatusVaksin.menunggu)
        .toList();
    if (pilihan.isEmpty) {
      _snack('Tidak ada vaksin yang dapat dicatat');
      return;
    }
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FormVaksinLuar(
        anakId: _anakId,
        lahir: _lahir,
        pilihan: pilihan,
      ),
    );
    if (hasil == true) {
      _snack('Vaksin dari luar posyandu tercatat');
      _muat();
    }
  }

  // -------------------------------------------------------------------------
  // TAMPILAN
  // -------------------------------------------------------------------------
  InputDecoration _dekor(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 15),
        filled: true,
        fillColor: AppColors.latar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Widget _teks(TextEditingController c, String label, {int baris = 2, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: baris,
          style: const TextStyle(fontSize: 16.5),
          textCapitalization: TextCapitalization.sentences,
          decoration: _dekor(label, hint: hint),
        ),
      );

  String _num(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    if (d == null) return '-';
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal('Catatan Bidan · ${widget.nomor}'),
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
                                Text(_gagal!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
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
                    _mulaiNanti != null ? 'Sesi Belum Dimulai' : (_kirim ? 'Menyimpan...' : 'Simpan Catatan'),
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
    final anak = d['anak'] is Map ? Map<String, dynamic>.from(d['anak'] as Map) : <String, dynamic>{};
    final ukur = d['pengukuran'] is Map ? Map<String, dynamic>.from(d['pengukuran'] as Map) : <String, dynamic>{};
    final prev = d['pengukuran_sebelumnya'] is Map ? Map<String, dynamic>.from(d['pengukuran_sebelumnya'] as Map) : null;

    final usia = _usiaBulan;
    final lahirAnak = _lahir;
    final usiaTeks = lahirAnak != null
        ? usiaDariLahir(lahirAnak, DateTime.now())
        : (usia >= 12 ? '${usia ~/ 12} tahun ${usia % 12} bulan' : '$usia bulan');
    final jk = anak['jenis_kelamin']?.toString() == 'P' ? 'Perempuan' : 'Laki-laki';
    final peringatan = ukur['peringatan_validasi']?.toString() ?? '';
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
              Text('$jk · $usiaTeks', style: const TextStyle(fontSize: 14.5, color: AppColors.teksRedup)),
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
              if (penilaian != null) ...[
                const SizedBox(height: 10),
                KotakPenilaian(p: penilaian),
              ],
              if (prev != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Kunjungan sebelumnya: BB ${_num(prev['bb_kg'])} kg · TB ${_num(prev['tb_cm'])} cm',
                  style: const TextStyle(fontSize: 14, color: AppColors.teksRedup),
                ),
              ],
              if ((ukur['keluhan']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Keluhan (kader): ${ukur['keluhan']}', style: const TextStyle(fontSize: 14.5)),
              ],
              if ((ukur['catatan']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Catatan kader: ${ukur['catatan']}', style: const TextStyle(fontSize: 14.5)),
              ],
              if (ukur['sedang_sakit'] == true) ...[
                const SizedBox(height: 6),
                const Pill('Anak sedang sakit', bg: AppColors.merahMuda, fg: AppColors.merah),
              ],
              if (peringatan.isNotEmpty) ...[
                const SizedBox(height: 8),
                _info(peringatan, ikon: Icons.warning_amber_rounded, bg: AppColors.merahMuda, fg: AppColors.merah),
              ],
              if (anakId.isNotEmpty) ...[
                const SizedBox(height: 4),
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
                          builder: (_) => BidanVaksinAnakPage(anakId: anakId, namaAnak: nama, usia: usiaTeks),
                        ),
                      );
                      _muat();
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!_riwayatOk) _kartuRiwayat(),
        SectionCard(
          title: 'Catatan Pemeriksaan',
          icon: Icons.medical_services_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _teks(_keluhan, 'Keluhan', hint: 'Mis. demam 2 hari, batuk pilek'),
              _teks(_catatanOrtu, 'Catatan untuk orang tua', baris: 3),
              _teks(_saranGizi, 'Saran gizi', baris: 3),
              const Text('Tanggal kunjungan ulang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pilihTanggal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 20, color: AppColors.hijau),
                            const SizedBox(width: 10),
                            Text(
                              _ulang == null ? 'Tidak dijadwalkan' : formatTanggal(_ulang!),
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_ulang != null)
                    IconButton(onPressed: () => setState(() => _ulang = null), icon: const Icon(Icons.close)),
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

  // -------------------------------------------------------------------------
  // KARTU RIWAYAT VAKSIN SEBELUM POSYANDU (konfirmasi sekali)
  // -------------------------------------------------------------------------
  Widget _kartuRiwayat() {
    final pesan = switch (_statusRiwayat) {
      StatusRiwayatVaksin.dilaporkan =>
        'Orang tua sudah mengisi vaksin yang pernah diterima anak. Cocokkan satu per satu dengan orang tua.',
      StatusRiwayatVaksin.belumPernah =>
        'Orang tua menyatakan anak belum pernah divaksin. Pastikan kembali kepada orang tua.',
      _ =>
        'Tanyakan kepada orang tua vaksin apa saja yang pernah diterima anak di luar posyandu '
            '(rumah sakit, puskesmas, klinik, bidan praktik).',
    };
    final menunggu = _riwayatLuar.where((r) => r.menungguKonfirmasi).length;

    return SectionCard(
      title: 'Riwayat Vaksin Sebelum Posyandu',
      icon: Icons.fact_check_outlined,
      color: const Color(0xFFFFFBEB),
      trailing: const Pill('Wajib', bg: AppColors.kuningMuda, fg: AppColors.kuning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info(pesan, ikon: Icons.record_voice_over_outlined, bg: AppColors.kuningMuda, fg: AppColors.kuning),
          if (_riwayatLuar.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Belum ada vaksin dari luar posyandu yang tercatat.',
                  style: TextStyle(fontSize: 14, color: AppColors.teksRedup)),
            ),
          for (final r in _riwayatLuar) _barisRiwayatLuar(r),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              'Tambah Vaksin dari Luar Posyandu',
              icon: Icons.add,
              filled: false,
              onPressed: _prosesRiwayat ? () {} : _tambahDariLuar,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              menunggu > 0 ? 'Konfirmasi $menunggu vaksin di atas dahulu' : 'Riwayat Sudah Benar',
              icon: Icons.verified_outlined,
              onPressed: (_prosesRiwayat || menunggu > 0) ? () {} : _selesaiKonfirmasi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisRiwayatLuar(RiwayatVaksin r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.menungguKonfirmasi ? AppColors.kuning : AppColors.latar, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.namaDosis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              r.menungguKonfirmasi
                  ? const Pill('Perlu dicek', bg: AppColors.kuningMuda, fg: AppColors.kuning)
                  : const Pill('Dikonfirmasi', bg: AppColors.hijauMuda, fg: AppColors.hijau),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (r.tanggal != null) formatTanggal(r.tanggal!),
              if (r.tempat.isNotEmpty) r.tempat,
              r.labelSumber,
            ].join(' · '),
            style: const TextStyle(fontSize: 13.5, color: AppColors.teksRedup),
          ),
          Wrap(
            spacing: 4,
            children: [
              if (r.fotoBukti.isNotEmpty)
                TextButton.icon(
                  onPressed: () => tampilkanBuktiVaksin(context, r.fotoBukti),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Lihat bukti'),
                ),
              if (r.menungguKonfirmasi) ...[
                TextButton.icon(
                  onPressed: _prosesRiwayat ? null : () => _benarkan(r),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Benar'),
                ),
                TextButton.icon(
                  onPressed: _prosesRiwayat ? null : () => _ubahTanggal(r),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text('Ubah tanggal'),
                ),
              ],
              TextButton.icon(
                onPressed: _prosesRiwayat ? null : () => _batalkan(r),
                icon: const Icon(Icons.close, size: 18, color: AppColors.merah),
                label: const Text('Batalkan', style: TextStyle(color: AppColors.merah)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // IMUNISASI HARI INI
  // -------------------------------------------------------------------------
  Widget _kartuImunisasi() {
    if (!_riwayatOk) {
      return SectionCard(
        title: 'Imunisasi Hari Ini',
        icon: Icons.vaccines_outlined,
        trailing: const Pill('Terkunci', bg: AppColors.latar, fg: AppColors.teksRedup, icon: Icons.lock_outline),
        child: const Text(
          'Konfirmasi riwayat vaksin anak di atas terlebih dahulu agar tidak ada vaksin yang diberikan dua kali.',
          style: TextStyle(fontSize: 14.5, color: AppColors.teksRedup),
        ),
      );
    }

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
              setState(() => _memuat = true);
              _muat();
            }),
          ],
        ),
      );
    }

    final calon = k.jadwal
        .where((e) => (e.bisaDiberikan && !e.keFaskes) || _vaksinSesiIni.contains(e.jadwal.kunci))
        .toList();
    final faskes = k.jadwal.where((e) => !e.sudah && e.keFaskes && e.status != StatusVaksin.terlewat).toList();
    final berikutnya = k.jadwal
        .where((e) =>
            !e.sudah &&
            !e.opsional &&
            !e.keFaskes &&
            (e.status == StatusVaksin.belumWaktunya || e.status == StatusVaksin.menunggu))
        .take(4)
        .toList();
    final sakit = _kondisi == KondisiImunisasi.sakit;

    return SectionCard(
      title: 'Imunisasi Hari Ini',
      icon: Icons.vaccines_outlined,
      trailing: Pill('${_vaksinDipilih.length} dipilih', bg: AppColors.hijauMuda, fg: AppColors.hijau),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_otomatis && _vaksinDipilih.isNotEmpty)
            _info('Vaksin sesuai jadwal sudah dicentang otomatis. Hapus centang bila tidak diberikan.',
                ikon: Icons.auto_awesome, bg: AppColors.hijauMuda, fg: AppColors.hijau),
          if (calon.isEmpty)
            const Text('Tidak ada vaksin yang perlu diberikan hari ini.',
                style: TextStyle(fontSize: 14.5, color: AppColors.teksRedup))
          else ...[
            const Text('Kondisi anak sebelum imunisasi',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final kd in [KondisiImunisasi.sehat, KondisiImunisasi.demamRingan, KondisiImunisasi.sakit])
                  ChoiceChip(
                    label: Text(KondisiImunisasi.label(kd)),
                    selected: _kondisi == kd,
                    selectedColor: kd == KondisiImunisasi.sakit ? AppColors.merah : AppColors.hijau,
                    labelStyle: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _kondisi == kd ? Colors.white : Colors.black87,
                    ),
                    onSelected: (_) => setState(() {
                      _kondisi = kd;
                      if (kd == KondisiImunisasi.sakit) {
                        for (final key in _vaksinDipilih.keys.where((x) => !_vaksinSesiIni.contains(x)).toList()) {
                          _vaksinDipilih.remove(key)?.dispose();
                        }
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (sakit)
              _info('Anak sedang sakit: tunda imunisasi sampai anak sehat. Vaksin akan dijadwalkan di posyandu berikutnya.',
                  ikon: Icons.do_not_disturb_on_outlined, bg: AppColors.merahMuda, fg: AppColors.merah)
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Centang vaksin yang diberikan hari ini.',
                    style: TextStyle(fontSize: 14, color: AppColors.teksRedup)),
              ),
            for (final e in calon) _barisCalon(e, terkunci: sakit),
          ],
          if (faskes.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final e in faskes)
              _info('${e.jadwal.namaDosis}: ${e.teksJadwal}',
                  ikon: Icons.local_hospital_outlined, bg: AppColors.merahMuda, fg: AppColors.merah),
          ],
          if (berikutnya.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Jadwal berikutnya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            for (final e in berikutnya)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.schedule, size: 16, color: AppColors.teksRedup),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${e.jadwal.namaDosis}\n${e.teksJadwal}',
                          style: const TextStyle(fontSize: 14, height: 1.35)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _barisCalon(JadwalVaksinAnak e, {required bool terkunci}) {
    final kunci = e.jadwal.kunci;
    final pilih = _vaksinDipilih[kunci];
    final dipilih = pilih != null;
    final tersimpan = _vaksinSesiIni.contains(kunci);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: dipilih ? AppColors.hijauMuda : AppColors.latar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dipilih ? AppColors.hijau : Colors.transparent, width: 1.2),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: dipilih,
            activeColor: AppColors.hijau,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.only(left: 4, right: 10),
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onChanged: (terkunci && !dipilih)
                ? null
                : (v) => setState(() {
                      if (v == true) {
                        _vaksinDipilih[kunci] = _PilihVaksin();
                      } else {
                        _vaksinDipilih.remove(kunci)?.dispose();
                      }
                    }),
            title: Text(e.jadwal.namaDosis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            subtitle: Text(
              [
                if (e.susulan) e.labelStatus,
                if (e.jadwal.jenis.penyakit.isNotEmpty) 'Mencegah ${e.jadwal.jenis.penyakit}',
                if (e.jadwal.jenis.caraPemberian.isNotEmpty) e.jadwal.jenis.caraPemberian,
              ].join(' · '),
              style: const TextStyle(fontSize: 13.5),
            ),
            secondary: tersimpan
                ? const Pill('Tersimpan', bg: AppColors.hijauMuda, fg: AppColors.hijau)
                : e.susulan
                    ? const Pill('Susulan', bg: AppColors.kuningMuda, fg: AppColors.kuning)
                    : Pill('Usia ${e.jadwal.labelUsia}', bg: AppColors.biruMuda, fg: AppColors.biru),
          ),
          if (pilih != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  TextField(
                    controller: pilih.batch,
                    style: const TextStyle(fontSize: 15.5),
                    maxLength: 50,
                    decoration: _dekor('Nomor batch vaksin (opsional)').copyWith(
                      counterText: '',
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pilih.reaksi,
                    style: const TextStyle(fontSize: 15.5),
                    maxLength: 500,
                    decoration: _dekor('Reaksi setelah imunisasi (opsional)', hint: 'Mis. demam ringan, bengkak di bekas suntikan')
                        .copyWith(counterText: '', fillColor: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SUPLEMEN HARI INI
  // -------------------------------------------------------------------------
  Widget _kartuSuplemen(int usia) {
    final bisaVitA = usia >= 6 && usia <= 59;
    final bisaCacing = usia >= 12 && usia <= 59;

    Widget chip(String label, IconData ikon, VoidCallback onTap) => ActionChip(
          avatar: Icon(ikon, size: 16, color: AppColors.hijau),
          label: Text(label),
          labelStyle: const TextStyle(fontSize: 15),
          backgroundColor: AppColors.latar,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: onTap,
        );

    return SectionCard(
      title: 'Suplemen Hari Ini',
      icon: Icons.medication_outlined,
      trailing: _suplemen.isEmpty ? null : Pill('${_suplemen.length} item', bg: AppColors.kuningMuda, fg: AppColors.kuning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tambah cepat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (bisaVitA)
                chip('Vitamin A', Icons.circle, () {
                  if (_suplemenAda('vitamin_a')) return _snack('Vitamin A sudah ditambahkan');
                  setState(() => _suplemen.add(_vitaminA(usia)));
                }),
              if (bisaCacing)
                chip('Obat Cacing', Icons.medication_outlined, () {
                  if (_suplemenAda('obat_cacing')) return _snack('Obat cacing sudah ditambahkan');
                  setState(() => _suplemen.add(_obatCacing(usia)));
                }),
              chip('PMT', Icons.restaurant_outlined,
                  () => setState(() => _suplemen.add(_BarisSuplemen(nama: 'PMT (Pemberian Makanan Tambahan)', satuan: 'porsi')))),
              chip('Zinc', Icons.science_outlined,
                  () => setState(() => _suplemen.add(_BarisSuplemen(nama: 'Zinc', dosis: usia < 6 ? '10 mg' : '20 mg', satuan: 'tablet')))),
              chip('Lainnya', Icons.add, () => setState(() => _suplemen.add(_BarisSuplemen()))),
            ],
          ),
          if (!bisaVitA)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Vitamin A diberikan mulai usia 6 bulan, obat cacing mulai usia 12 bulan.',
                  style: TextStyle(fontSize: 13, color: AppColors.teksRedup)),
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
              Expanded(
                child: Text(
                  s.tetap ? s.nama.text : 'Suplemen ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
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
            child: s.tetap
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Pill('${s.dosis.text} · 1 ${s.satuan}', bg: AppColors.kuningMuda, fg: AppColors.kuning),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: s.catatan,
                        style: const TextStyle(fontSize: 16),
                        decoration: _dekor('Catatan (opsional)'),
                      ),
                    ],
                  )
                : Column(
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
                        decoration: _dekor('Dosis (mis. 400 mg)').copyWith(counterText: ''),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
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
                              items: [for (final x in satuan) DropdownMenuItem(value: x, child: Text(x))],
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

// ---------------------------------------------------------------------------
// FORM VAKSIN DARI LUAR POSYANDU (berdasarkan keterangan orang tua)
// ---------------------------------------------------------------------------
class _FormVaksinLuar extends StatefulWidget {
  final String anakId;
  final DateTime? lahir;
  final List<JadwalVaksinAnak> pilihan;

  const _FormVaksinLuar({required this.anakId, required this.lahir, required this.pilihan});

  @override
  State<_FormVaksinLuar> createState() => _FormVaksinLuarState();
}

class _FormVaksinLuarState extends State<_FormVaksinLuar> {
  final _svc = VaksinService();
  final _tempat = TextEditingController();
  final _batch = TextEditingController();
  final _pemberi = TextEditingController();
  JadwalVaksinAnak? _vaksin;
  DateTime? _tanggal;
  bool _kirim = false;
  String? _galat;

  @override
  void dispose() {
    _tempat.dispose();
    _batch.dispose();
    _pemberi.dispose();
    super.dispose();
  }

  InputDecoration _dekor(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.latar,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Future<void> _pilihTanggal() async {
    final n = DateTime.now();
    final t = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? DateTime(n.year, n.month, n.day),
      firstDate: widget.lahir ?? DateTime(n.year - 6),
      lastDate: DateTime(n.year, n.month, n.day),
    );
    if (t != null) setState(() => _tanggal = t);
  }

  Future<void> _simpan() async {
    final v = _vaksin;
    if (v == null || _tanggal == null || _tempat.text.trim().isEmpty) {
      setState(() => _galat = 'Pilih vaksin, tanggal, dan isi tempat pemberian.');
      return;
    }
    setState(() {
      _kirim = true;
      _galat = null;
    });
    try {
      await _svc.catatRiwayat(
        anakId: widget.anakId,
        jenisVaksinId: v.jadwal.jenis.id,
        dosisKe: v.jadwal.dosisKe,
        tanggal: _tanggal!,
        tempat: _tempat.text.trim(),
        nomorBatch: _batch.text.trim(),
        pemberiLuar: _pemberi.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kirim = false;
        _galat = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vaksin dari Luar Posyandu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Isi sesuai keterangan orang tua. Vaksin yang sudah tercatat tidak akan diberikan lagi.',
                style: TextStyle(fontSize: 14, color: AppColors.teksRedup)),
            const SizedBox(height: 14),
            DropdownButtonFormField<JadwalVaksinAnak>(
              value: _vaksin,
              isExpanded: true,
              decoration: _dekor('Vaksin'),
              items: [
                for (final e in widget.pilihan)
                  DropdownMenuItem(value: e, child: Text(e.jadwal.namaDosis, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _vaksin = v),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pilihTanggal,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 20, color: AppColors.hijau),
                    const SizedBox(width: 10),
                    Text(
                      _tanggal == null ? 'Pilih tanggal pemberian' : formatTanggal(_tanggal!),
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tempat,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: _dekor('Tempat (mis. RSUD Porsea, Puskesmas Balige)'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _batch, maxLength: 50, decoration: _dekor('Nomor batch (opsional)')),
            const SizedBox(height: 10),
            TextField(
              controller: _pemberi,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: _dekor('Nama petugas pemberi (opsional)'),
            ),
            if (_galat != null) ...[
              const SizedBox(height: 8),
              Text(_galat!, style: const TextStyle(color: AppColors.merah, fontSize: 14)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: AppButton(_kirim ? 'Menyimpan...' : 'Simpan', icon: Icons.save_outlined,
                  onPressed: _kirim ? () {} : _simpan),
            ),
          ],
        ),
      ),
    );
  }
}