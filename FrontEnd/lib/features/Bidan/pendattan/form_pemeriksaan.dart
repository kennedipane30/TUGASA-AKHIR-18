part of 'catat_pemeriksaan_page.dart';

// ===========================================================================
// BAGIAN BERSAMA HALAMAN CATAT & EDIT PEMERIKSAAN
// Helper, model baris suplemen/vaksin, state form, simpan, dan riwayat vaksin
// sebelum posyandu (dicatat bidan pada kunjungan pertama anak).
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

/// Pesan di bagian atas form ubah bila jadwal posyandu sudah selesai.
Widget _bannerJadwalSelesai() {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: dekorKartuBidan(warna: AppColors.kuningMuda),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, color: AppColors.kuning),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jadwal posyandu sudah selesai',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
              ),
              SizedBox(height: 4),
              Text(
                'Pemeriksaan bidan untuk kunjungan ini hanya dapat dilihat dan tidak dapat diubah lagi.',
                style: TextStyle(fontSize: 16, height: 1.35),
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

  /// Isian aturan pakai bila bidan memilih "Lainnya".
  final TextEditingController aturanLain;
  int jumlah;
  String satuan;

  /// Pilihan aturan pakai: salah satu [_aturanPakai] atau [_aturanLainnya].
  String aturan;
  final bool tetap;

  _BarisSuplemen({
    String nama = '',
    String dosis = '',
    String catatan = '',
    String aturanPakai = '',
    this.jumlah = 1,
    this.satuan = 'kapsul',
    this.tetap = false,
  })  : nama = TextEditingController(text: nama),
        dosis = TextEditingController(text: dosis),
        catatan = TextEditingController(text: catatan),
        aturan = _aturanPakai.contains(aturanPakai)
            ? aturanPakai
            : (aturanPakai.trim().isEmpty ? (tetap ? 'Dosis tunggal' : '1 x 1 sehari') : _aturanLainnya),
        aturanLain = TextEditingController(
            text: _aturanPakai.contains(aturanPakai) ? '' : aturanPakai.trim());

  /// Aturan pakai yang dikirim ke server.
  String get aturanPakai => aturan == _aturanLainnya ? aturanLain.text.trim() : aturan;

  /// Baris yang belum diisi sama sekali (form suplemen yang dibiarkan kosong).
  bool get kosong =>
      !tetap && nama.text.trim().isEmpty && dosis.text.trim().isEmpty && catatan.text.trim().isEmpty;

  void dispose() {
    nama.dispose();
    dosis.dispose();
    catatan.dispose();
    aturanLain.dispose();
  }
}

/// Pilihan aturan pakai suplemen. Selain ini, bidan memilih "Lainnya" dan mengisi sendiri.
const _aturanPakai = <String>[
  '1 x 1 sehari',
  '2 x 1 sehari',
  '3 x 1 sehari',
  'Dosis tunggal',
];
const _aturanLainnya = 'Lainnya';

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

/// Vaksin yang dipilih hari ini. Nomor batch dan reaksi tidak diisi lagi di sini:
/// reaksi setelah imunisasi dilaporkan orang tua (tampil di kunjungan berikutnya).
class _PilihVaksin {
  _PilihVaksin();

  void dispose() {}
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

  final _catatanOrtu = TextEditingController();
  final _saranGizi = TextEditingController();

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

  /// Mode ubah dan jadwal posyandu sudah selesai: catatan hanya dapat dilihat.
  bool get _jadwalSelesai => modeEdit && _detail?['jadwal_selesai'] == true;

  /// Waktu mulai sesi bila sesi BELUM dimulai; null bila pendataan sudah boleh.
  DateTime? get _mulaiNanti {
    final m = _mulaiSesi;
    if (m == null || !DateTime.now().isBefore(m)) return null;
    return m;
  }

  @override
  void dispose() {
    _jam?.cancel();
    for (final c in [_catatanOrtu, _saranGizi]) {
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

  int get _usiaBulan => int.tryParse(_detail?['usia_bulan']?.toString() ?? '') ?? 0;

  String get _anakId =>
      (_detail?['anak'] is Map) ? (_detail!['anak']['id']?.toString() ?? '') : '';

  DateTime? get _lahir {
    final a = _detail?['anak'];
    if (a is! Map) return null;
    final t = a['tanggal_lahir']?.toString() ?? '';
    return t.length >= 10 ? DateTime.tryParse(t.substring(0, 10)) : null;
  }

  /// Form suplemen langsung tampil: bila belum ada baris, siapkan satu baris kosong.
  /// Baris yang dibiarkan kosong tidak ikut disimpan.
  void _siapkanFormSuplemen() {
    if (_suplemen.isEmpty) _suplemen.add(_BarisSuplemen());
  }

  /// Hapus satu baris suplemen; form tidak pernah dibiarkan tanpa baris.
  void _hapusSuplemen(int i) {
    setState(() {
      _suplemen.removeAt(i).dispose();
      _siapkanFormSuplemen();
    });
  }

  /// Suplemen yang benar-benar diisi bidan.
  List<_BarisSuplemen> get _suplemenTerisi => _suplemen.where((s) => !s.kosong).toList();

  /// Laporan reaksi dari orang tua (setelah imunisasi pada kunjungan sebelumnya)
  /// yang belum ditindaklanjuti bidan. Bila orang tua tidak melapor, dianggap normal.
  List<RiwayatVaksin> get _laporanOrtu {
    final k = _kartu;
    if (k == null) return const [];
    return k.riwayat
        .where((r) =>
            r.reaksiKipi.trim().isNotEmpty &&
            r.kipiTindakLanjut.trim().isEmpty &&
            !_vaksinSesiIni.contains('${r.jenis.id}|${r.dosisKe}'))
        .toList();
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

  // -------------------------------------------------------------------------
  // SIMPAN
  // -------------------------------------------------------------------------
  Future<void> _simpan() async {
    if (_kirim) return;
    if (_jadwalSelesai) {
      _snack('Jadwal posyandu sudah selesai, pemeriksaan tidak dapat diubah lagi');
      return;
    }

    final mulai = _mulaiNanti;
    if (mulai != null) {
      _snack('Sesi belum dimulai. Pendataan dapat dilakukan mulai pukul ${_jamMenit(mulai)} WIB');
      return;
    }
    if (_vaksinDipilih.isNotEmpty) {
      if (!_riwayatOk) {
        _snack('Catat riwayat vaksin anak terlebih dahulu');
        return;
      }
      // Kondisi mengikuti pendataan kader; anak sakit tidak boleh mendapat vaksin baru.
      if (_kondisi == KondisiImunisasi.sakit &&
          _vaksinDipilih.keys.any((k) => !_vaksinSesiIni.contains(k))) {
        _snack('Anak sedang sakit (pendataan kader). Hapus centang vaksin dan tunda imunisasi.');
        return;
      }
    }
    final terisi = _suplemenTerisi;
    for (final s in terisi) {
      if (s.nama.text.trim().isEmpty) {
        _snack('Isi nama suplemen, atau kosongkan seluruh isian suplemen bila tidak ada');
        return;
      }
      if (s.aturan == _aturanLainnya && s.aturanLain.text.trim().isEmpty) {
        _snack('Isi aturan pakai ${s.nama.text.trim()}');
        return;
      }
    }

    setState(() => _kirim = true);
    try {
      await ApiClient.dio.put(
        '/bidan/pendaftaran/$pendaftaranId/catatan',
        data: {
          // Keluhan diambil dari pendataan kader; tanggal kunjungan ulang tidak dipakai.
          'catatan_evaluasi': _catatanOrtu.text.trim(),
          'saran_gizi': _saranGizi.text.trim(),
          'vaksin': [
            for (final e in _vaksinDipilih.entries)
              {
                'jenis_vaksin_id': e.key.split('|').first,
                'dosis_ke': int.tryParse(e.key.split('|').last) ?? 1,
                'kondisi_anak': _kondisi ?? '',
              }
          ],
          'suplemen': [
            for (final s in terisi)
              {
                'nama': s.nama.text.trim(),
                'dosis': s.dosis.text.trim(),
                'jumlah': s.tetap ? 1 : s.jumlah,
                'satuan': s.satuan,
                'aturan_pakai': s.aturanPakai,
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

  /// Bidan mencatat tindak lanjut atas reaksi yang dilaporkan orang tua.
  /// Setelah tersimpan, laporan tidak tampil lagi di atas form pemeriksaan.
  Future<void> _isiTindakLanjut(RiwayatVaksin r) async {
    final isian = TextEditingController();
    final tindak = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tindak lanjut reaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.namaDosis}\n${r.reaksiKipi}', style: const TextStyle(fontSize: 16, height: 1.35)),
            const SizedBox(height: 12),
            TextField(
              controller: isian,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Mis. dianjurkan kompres hangat, bila demam berlanjut ke puskesmas',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              final t = isian.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (tindak == null || tindak.isEmpty) return;
    await _jalankan(
      () => _svcVaksin.tindakLanjutKipi(r.id, reaksi: r.reaksiKipi, tindakLanjut: tindak),
      'Tindak lanjut tersimpan',
    );
  }

  /// Kunjungan pertama: bidan mencatat riwayat vaksin anak sebelum posyandu
  /// (belum pernah / sudah pernah + daftar centang + vaksin mandiri).
  Future<void> _catatRiwayatAwal() async {
    final lahir = _lahir;
    if (lahir == null) {
      _snack('Tanggal lahir anak belum tersedia');
      return;
    }
    final sudah = <String>{
      for (final r in _riwayatLuar) '${r.jenis.id}|${r.dosisKe}',
      ...?_kartu?.riwayat.map((r) => '${r.jenis.id}|${r.dosisKe}'),
    };
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FormRiwayatVaksinAwal(
        anakId: _anakId,
        nama: _kartu?.anak.nama ?? '',
        lahir: lahir,
        sudahTercatat: sudah,
        adaRiwayatLuar: _riwayatLuar.isNotEmpty,
      ),
    );
    if (hasil == true) {
      _snack('Riwayat vaksin anak tersimpan');
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
// FORM RIWAYAT VAKSIN SEBELUM POSYANDU (bidan, kunjungan pertama anak)
//   - Belum pernah divaksin, atau
//   - Sudah pernah: centang dosis vaksin program + "vaksin mandiri" di luar daftar.
// Data langsung sah. Dosis yang sudah tercatat tampil terkunci (tidak dobel).
// ---------------------------------------------------------------------------

/// Isian satu dosis vaksin program yang dicentang.
class _DosisAwal {
  DateTime? tanggal;
  final tempat = TextEditingController();
  String foto = '';
  bool mengunggah = false;

  void dispose() => tempat.dispose();
}

/// Isian satu vaksin di luar daftar program.
class _VaksinMandiriAwal {
  final nama = TextEditingController();
  int dosis = 1;
  DateTime? tanggal;
  final tempat = TextEditingController();
  String foto = '';
  bool mengunggah = false;

  void dispose() {
    nama.dispose();
    tempat.dispose();
  }
}

class _FormRiwayatVaksinAwal extends StatefulWidget {
  final String anakId;
  final String nama;
  final DateTime lahir;

  /// Kunci "jenisVaksinId|dosisKe" yang sudah tercatat.
  final Set<String> sudahTercatat;

  /// Sudah ada catatan vaksin dari luar posyandu (mis. laporan lama yang sudah dibenarkan).
  final bool adaRiwayatLuar;

  const _FormRiwayatVaksinAwal({
    required this.anakId,
    required this.nama,
    required this.lahir,
    required this.sudahTercatat,
    required this.adaRiwayatLuar,
  });

  @override
  State<_FormRiwayatVaksinAwal> createState() => _FormRiwayatVaksinAwalState();
}

class _FormRiwayatVaksinAwalState extends State<_FormRiwayatVaksinAwal> {
  final _svc = VaksinService();
  String _status = ''; // sudah | belum_pernah
  List<JadwalImunisasi> _master = [];
  bool _memuatMaster = false;
  final Map<String, _DosisAwal> _dipilih = {};
  final List<_VaksinMandiriAwal> _mandiri = [];
  bool _menyimpan = false;
  String? _galat;

  @override
  void dispose() {
    for (final d in _dipilih.values) {
      d.dispose();
    }
    for (final v in _mandiri) {
      v.dispose();
    }
    super.dispose();
  }

  DateTime get _hariIni {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int get _usiaBulan {
    final n = _hariIni;
    var b = (n.year - widget.lahir.year) * 12 + n.month - widget.lahir.month;
    if (n.day < widget.lahir.day) b--;
    return b < 0 ? 0 : b;
  }

  Future<void> _pilihStatus(String s) async {
    setState(() {
      _status = s;
      _galat = null;
    });
    if (s == 'sudah' && _master.isEmpty) {
      setState(() => _memuatMaster = true);
      try {
        final m = await _svc.jadwalMaster();
        if (!mounted) return;
        setState(() {
          // hanya dosis yang sudah mungkin diterima sesuai usia anak
          _master = m.where((j) => !j.jenis.khususDaerah && j.usiaMinBulan <= _usiaBulan).toList();
          _memuatMaster = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _memuatMaster = false;
          _galat = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<DateTime?> _tanggal(DateTime? awal) => showDatePicker(
        context: context,
        initialDate: awal ?? _hariIni,
        firstDate: widget.lahir,
        lastDate: _hariIni,
      );

  /// Ambil foto bukti (kamera / galeri) lalu unggah. Mengembalikan nama file di server.
  Future<String?> _unggahFoto() async {
    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (sumber == null) return null;
    final x = await ImagePicker().pickImage(source: sumber, maxWidth: 1600, imageQuality: 80);
    if (x == null) return null;
    try {
      return await _svc.unggahBukti(x.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
      return null;
    }
  }

  Future<void> _fotoDosis(_DosisAwal d) async {
    setState(() => d.mengunggah = true);
    final nama = await _unggahFoto();
    if (!mounted) return;
    setState(() {
      if (nama != null) d.foto = nama;
      d.mengunggah = false;
    });
  }

  Future<void> _fotoMandiri(_VaksinMandiriAwal v) async {
    setState(() => v.mengunggah = true);
    final nama = await _unggahFoto();
    if (!mounted) return;
    setState(() {
      if (nama != null) v.foto = nama;
      v.mengunggah = false;
    });
  }

  Future<void> _simpan() async {
    if (_status.isEmpty) {
      setState(() => _galat = 'Pilih: belum pernah atau sudah pernah divaksin');
      return;
    }
    final items = <Map<String, dynamic>>[];
    final mandiri = <Map<String, dynamic>>[];
    if (_status == 'sudah') {
      for (final e in _dipilih.entries) {
        final d = e.value;
        if (d.tanggal == null || d.tempat.text.trim().isEmpty) {
          setState(() => _galat = 'Isi tanggal dan tempat untuk setiap vaksin yang dicentang');
          return;
        }
        if (d.mengunggah) {
          setState(() => _galat = 'Tunggu foto selesai diunggah');
          return;
        }
        items.add({
          'jenis_vaksin_id': e.key.split('|').first,
          'dosis_ke': int.tryParse(e.key.split('|').last) ?? 1,
          'tanggal_pemberian': tanggalApiVaksin(d.tanggal!),
          'tempat': d.tempat.text.trim(),
          'foto_bukti': d.foto,
        });
      }
      final kunciMandiri = <String>{};
      for (final v in _mandiri) {
        final nama = v.nama.text.trim();
        if (nama.isEmpty || v.tanggal == null || v.tempat.text.trim().isEmpty) {
          setState(() => _galat = 'Isi nama vaksin, tanggal, dan tempat untuk setiap vaksin mandiri');
          return;
        }
        if (v.mengunggah) {
          setState(() => _galat = 'Tunggu foto selesai diunggah');
          return;
        }
        if (!kunciMandiri.add('${nama.toLowerCase()}|${v.dosis}')) {
          setState(() => _galat = '$nama dosis ${v.dosis} diisi lebih dari sekali');
          return;
        }
        mandiri.add({
          'nama_vaksin': nama,
          'dosis_ke': v.dosis,
          'tanggal_pemberian': tanggalApiVaksin(v.tanggal!),
          'tempat': v.tempat.text.trim(),
          'foto_bukti': v.foto,
        });
      }
      if (items.isEmpty && mandiri.isEmpty && !widget.adaRiwayatLuar) {
        setState(() => _galat = 'Centang minimal satu vaksin atau tambahkan vaksin mandiri');
        return;
      }
    }
    setState(() {
      _menyimpan = true;
      _galat = null;
    });
    try {
      await _svc.catatRiwayatAwal(anakId: widget.anakId, status: _status, items: items, mandiri: mandiri);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _galat = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // -------------------------------------------------------------------------

  Widget _opsi(String kode, String judul, String ket, IconData ikon) {
    final aktif = _status == kode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pilihStatus(kode),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: aktif ? _hijauHeader : garisKartuBidan, width: aktif ? 1.6 : 1.2),
          ),
          child: Row(
            children: [
              Icon(ikon, color: aksenKartuBidan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _teksGelap)),
                    Text(ket, style: const TextStyle(fontSize: 15, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              Icon(aktif ? Icons.radio_button_checked : Icons.radio_button_off, color: _hijauHeader),
            ],
          ),
        ),
      ),
    );
  }

  /// Baris tanggal + tempat + foto (dipakai dosis program & vaksin mandiri).
  Widget _isianDosis({
    required DateTime? tanggal,
    required VoidCallback onTanggal,
    required TextEditingController tempat,
    required String foto,
    required bool mengunggah,
    required VoidCallback onFoto,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kotakPilihBidan(
          Icons.calendar_month_outlined,
          tanggal == null ? 'Tanggal diberikan *' : formatTanggal(tanggal),
          onTanggal,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: tempat,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: dekorFormBidan('Tempat * (mis. RSUD Porsea, Bidan Praktik)', ikon: Icons.local_hospital_outlined)
              .copyWith(counterText: ''),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: mengunggah ? null : onFoto,
            icon: Icon(foto.isEmpty ? Icons.add_a_photo_outlined : Icons.check_circle, size: 18),
            label: Text(mengunggah
                ? 'Mengunggah...'
                : (foto.isEmpty ? 'Foto bukti (opsional)' : 'Foto terunggah, ganti')),
          ),
        ),
      ],
    );
  }

  Widget _barisVaksin(JadwalImunisasi j) {
    final tercatat = widget.sudahTercatat.contains(j.kunci);
    final d = _dipilih[j.kunci];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tercatat ? const Color(0xFFF3F4F6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: d != null ? _hijauHeader : garisKartuBidan, width: 1.2),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: tercatat || d != null,
            dense: true,
            activeColor: _hijauHeader,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(j.namaDosis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            subtitle: Text(
              tercatat ? 'Sudah tercatat' : 'Biasanya usia ${j.labelUsia}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: tercatat ? FontWeight.w600 : FontWeight.w400,
                color: tercatat ? _hijauHeader : AppColors.teksRedup,
              ),
            ),
            onChanged: tercatat
                ? null
                : (v) => setState(() {
                      if (v == true) {
                        _dipilih[j.kunci] = _DosisAwal();
                      } else {
                        _dipilih.remove(j.kunci)?.dispose();
                      }
                    }),
          ),
          if (d != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _isianDosis(
                tanggal: d.tanggal,
                onTanggal: () async {
                  final t = await _tanggal(d.tanggal);
                  if (t != null) setState(() => d.tanggal = t);
                },
                tempat: d.tempat,
                foto: d.foto,
                mengunggah: d.mengunggah,
                onFoto: () => _fotoDosis(d),
              ),
            ),
        ],
      ),
    );
  }

  Widget _barisMandiri(int i) {
    final v = _mandiri[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hijauHeader, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Vaksin mandiri ${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _teksGelap)),
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: () => setState(() => _mandiri.removeAt(i).dispose()),
                icon: const Icon(Icons.delete_outline, color: AppColors.merah),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              children: [
                TextField(
                  controller: v.nama,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: dekorFormBidan('Nama vaksin * (mis. Rotavirus, PCV)', ikon: Icons.vaccines_outlined)
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: v.dosis,
                  decoration: dekorFormBidan('Dosis ke-', ikon: Icons.format_list_numbered),
                  items: [
                    for (var n = 1; n <= 10; n++) DropdownMenuItem(value: n, child: Text('Dosis $n')),
                  ],
                  onChanged: (n) => setState(() => v.dosis = n ?? 1),
                ),
                const SizedBox(height: 8),
                _isianDosis(
                  tanggal: v.tanggal,
                  onTanggal: () async {
                    final t = await _tanggal(v.tanggal);
                    if (t != null) setState(() => v.tanggal = t);
                  },
                  tempat: v.tempat,
                  foto: v.foto,
                  mengunggah: v.mengunggah,
                  onFoto: () => _fotoMandiri(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            const Text('RIWAYAT VAKSIN SEBELUM POSYANDU',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _teksGelap)),
            const SizedBox(height: 6),
            Container(height: 3, color: aksenKartuBidan),
            const SizedBox(height: 10),
            Text(
              'Apakah ${widget.nama.isEmpty ? 'anak' : widget.nama} sudah pernah menerima vaksin sebelum ke posyandu '
              '(rumah sakit, puskesmas, klinik, atau bidan praktik)? Cocokkan dengan Buku KIA.',
              style: const TextStyle(fontSize: 16, color: AppColors.teksRedup, height: 1.4),
            ),
            const SizedBox(height: 14),
            _opsi('belum_pernah', 'Belum pernah', 'Anak belum pernah divaksin', Icons.block_outlined),
            _opsi('sudah', 'Sudah pernah', 'Centang vaksin yang sudah diterima', Icons.vaccines_outlined),
            if (_status == 'sudah') ...[
              const SizedBox(height: 6),
              if (_memuatMaster)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final j in _master) _barisVaksin(j),
              const SizedBox(height: 10),
              const Text('VAKSIN MANDIRI (DI LUAR PROGRAM)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _teksGelap)),
              const SizedBox(height: 4),
              const Text('Mis. Rotavirus, PCV, Influenza, Varisela, Hepatitis A.',
                  style: TextStyle(fontSize: 15, color: AppColors.teksRedup)),
              const SizedBox(height: 8),
              for (var i = 0; i < _mandiri.length; i++) _barisMandiri(i),
              tombolGarisBidan(
                'Tambah Vaksin Mandiri',
                ikon: Icons.add,
                onPressed: () => setState(() => _mandiri.add(_VaksinMandiriAwal())),
              ),
            ],
            if (_galat != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_galat!, style: const TextStyle(color: AppColors.merah, fontSize: 16)),
              ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: garisKartuBidan, width: 1.2),
              ),
              child: const Text(
                'Vaksin yang dicatat langsung sah dan tidak akan diberikan lagi di posyandu. '
                'Bagian ini hanya diisi sekali, pada kunjungan pertama anak.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: tombolGarisBidan(
                    'Batal',
                    warna: AppColors.merah,
                    onPressed: _menyimpan ? null : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: tombolHijauBidan(
                    _menyimpan ? 'Menyimpan...' : 'Simpan',
                    ikon: Icons.save_outlined,
                    onPressed: _menyimpan ? null : _simpan,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}