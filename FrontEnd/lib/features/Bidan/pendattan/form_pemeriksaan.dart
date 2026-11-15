part of 'catat_pemeriksaan_page.dart';

// ===========================================================================
// BAGIAN BERSAMA HALAMAN CATAT & EDIT PEMERIKSAAN
// Helper, model baris suplemen/vaksin, state form, simpan, riwayat vaksin,
// dan form vaksin dari luar posyandu.
// ===========================================================================

const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

// ---------------------------------------------------------------------------
// KOMPONEN TAMPILAN (seragam dengan halaman lain, dipakai juga Hasil Pendataan)
// ---------------------------------------------------------------------------

/// Garis tepi kotak di dalam kartu: hitam lembut.
const garisKartuBidan = Color(0xFFB8BEC6);

/// Aksen kartu: hijau lembut senada header.
const aksenKartuBidan = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const bayanganKartuBidan = [
  BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 3)),
];

BoxDecoration dekorKartuBidan({Color warna = Colors.white}) => BoxDecoration(
      color: warna,
      borderRadius: BorderRadius.circular(16),
      boxShadow: bayanganKartuBidan,
    );

/// Kepala kartu: judul kapital tebal di kiri, keterangan di kanan, garis aksen di bawah.
Widget kepalaKartuBidan(String judul, {String? kanan, Color warnaKanan = _teksGelap}) {
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
              Text(kanan,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: warnaKanan)),
            ],
          ],
        ),
      ),
      Container(height: 3, color: aksenKartuBidan),
    ],
  );
}

/// Kartu putih berbayang; [judul] opsional (kepala + garis aksen).
Widget kartuBidan({
  String? judul,
  String? kanan,
  Color warnaKanan = _teksGelap,
  Color warna = Colors.white,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    decoration: dekorKartuBidan(warna: warna),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (judul != null) kepalaKartuBidan(judul, kanan: kanan, warnaKanan: warnaKanan),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ],
    ),
  );
}

/// Baris "Label : nilai" (hitam tebal).
Widget barisInfoBidan(String label, String nilai, {double lebar = 130}) {
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

/// Kotak angka pengukuran (BB, TB, LK, LiLA) bergaris tepi hitam lembut.
Widget kotakUkurBidan(String nilai, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: garisKartuBidan, width: 1.2),
    ),
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(nilai,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: _teksGelap)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.teksRedup)),
        ),
      ],
    ),
  );
}

/// Dekorasi field form: putih, garis tepi hitam lembut, ikon di depan.
InputDecoration dekorFormBidan(String label, {String? hint, IconData? ikon}) {
  OutlineInputBorder garis(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(fontSize: 16),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: ikon == null ? null : Icon(ikon, color: aksenKartuBidan),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: garis(garisKartuBidan, 1.2),
    enabledBorder: garis(garisKartuBidan, 1.2),
    disabledBorder: garis(garisKartuBidan, 1.2),
    focusedBorder: garis(_hijauHeader, 1.6),
  );
}

/// Kotak pilih (mis. tanggal) dengan gaya sama seperti field form.
Widget kotakPilihBidan(IconData ikon, String teks, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: garisKartuBidan, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(ikon, size: 22, color: aksenKartuBidan),
          const SizedBox(width: 12),
          Expanded(
            child: Text(teks,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500, color: _teksGelap)),
          ),
        ],
      ),
    ),
  );
}

Widget _isiTombol(String label, IconData? ikon) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ikon != null) ...[Icon(ikon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

/// Tombol hijau penuh (tinggi 50, sudut 14).
Widget tombolHijauBidan(String label, {IconData? ikon, VoidCallback? onPressed}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _hijauHeader,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _hijauHeader.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
      ),
      child: _isiTombol(label, ikon),
    ),
  );
}

/// Tombol bergaris (tinggi 50, sudut 14).
Widget tombolGarisBidan(String label,
    {IconData? ikon, VoidCallback? onPressed, Color warna = _hijauHeader}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: warna,
        backgroundColor: Colors.white,
        side: BorderSide(color: warna, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
      ),
      child: _isiTombol(label, ikon),
    ),
  );
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
    decoration: dekorKartuBidan(warna: AppColors.kuningMuda),
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
        Expanded(child: Text(teks, style: const TextStyle(fontSize: 16, height: 1.35))),
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
// STATE FORM PEMERIKSAAN (dipakai _CatatPemeriksaanState & _EditPemeriksaanState)
// ---------------------------------------------------------------------------
mixin _FormPemeriksaan<T extends StatefulWidget> on State<T> {
  /// Diisi oleh halaman Catat / Edit.
  String get pendaftaranId;
  String get nomor;
  bool get modeEdit;
  Future<void> _muat();

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
        '/bidan/pendaftaran/$pendaftaranId/catatan',
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
      _snack(modeEdit ? 'Perubahan catatan tersimpan' : 'Catatan bidan tersimpan');
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
  InputDecoration _dekor(String label, {String? hint, IconData? ikon}) =>
      dekorFormBidan(label, hint: hint, ikon: ikon);

  Widget _teks(TextEditingController c, String label, {int baris = 2, String? hint, IconData? ikon}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: baris,
          style: const TextStyle(fontSize: 17.5),
          textCapitalization: TextCapitalization.sentences,
          decoration: _dekor(label, hint: hint, ikon: ikon),
        ),
      );

  String _num(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    if (d == null) return '-';
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
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

  InputDecoration _dekor(String label, IconData ikon) =>
      dekorFormBidan(label, ikon: ikon).copyWith(counterText: '');

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
            const Text('VAKSIN DARI LUAR POSYANDU',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _teksGelap)),
            const SizedBox(height: 6),
            Container(height: 3, color: aksenKartuBidan),
            const SizedBox(height: 8),
            const SizedBox(height: 4),
            const Text('Isi sesuai keterangan orang tua. Vaksin yang sudah tercatat tidak akan diberikan lagi.',
                style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
            const SizedBox(height: 14),
            DropdownButtonFormField<JadwalVaksinAnak>(
              value: _vaksin,
              isExpanded: true,
              decoration: _dekor('Vaksin', Icons.vaccines_outlined),
              items: [
                for (final e in widget.pilihan)
                  DropdownMenuItem(value: e, child: Text(e.jadwal.namaDosis, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _vaksin = v),
            ),
            const SizedBox(height: 10),
            kotakPilihBidan(
              Icons.calendar_month_outlined,
              _tanggal == null ? 'Pilih tanggal pemberian' : formatTanggal(_tanggal!),
              _pilihTanggal,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tempat,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: _dekor('Tempat (mis. RSUD Porsea, Puskesmas Balige)', Icons.location_on_outlined),
            ),
            const SizedBox(height: 10),
            TextField(controller: _batch, maxLength: 50, decoration: _dekor('Nomor batch (opsional)', Icons.qr_code_2)),
            const SizedBox(height: 10),
            TextField(
              controller: _pemberi,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: _dekor('Nama petugas pemberi (opsional)', Icons.person_outline),
            ),
            if (_galat != null) ...[
              const SizedBox(height: 8),
              Text(_galat!, style: const TextStyle(color: AppColors.merah, fontSize: 16)),
            ],
            const SizedBox(height: 14),
            tombolHijauBidan(
              _kirim ? 'Menyimpan...' : 'Simpan',
              ikon: Icons.save_outlined,
              onPressed: _kirim ? null : _simpan,
            ),
          ],
        ),
      ),
    );
  }
}