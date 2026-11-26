part of 'catat_pemeriksaan_page.dart';

// ===========================================================================
// FORM PEMERIKSAAN — INTI
// State bersama halaman Catat & Edit Pemeriksaan: memuat data balita, menyimpan
// catatan (hasil pemeriksaan + imunisasi + suplemen sekaligus), dan pembantu
// yang dipakai seluruh bagian form.
//
// Bagian form lainnya ada di berkas tersendiri, masih satu halaman:
//   form_suplemen.dart   mixin _FormSuplemen
//   form_imunisasi.dart  mixin _FormImunisasi
//   kartu_pemeriksaan.dart  mixin _KartuPemeriksaan (rangka halaman)
// ===========================================================================

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

  final _svcImunisasi = ImunisasiService();

  Map<String, dynamic>? _detail;
  KartuImunisasi? _kartu;
  String? _gagalKartu;
  bool _memuat = true;
  bool _kirim = false;
  bool _prosesRiwayat = false;
  String? _gagal;

  final _catatanOrtu = TextEditingController();
  final _saranGizi = TextEditingController();

  /// Riwayat imunisasi sebelum posyandu.
  String _statusRiwayat = StatusRiwayatImunisasi.belumDitanya;
  List<RiwayatImunisasi> _riwayatLuar = [];

  /// Imunisasi yang dipilih hari ini, kunci "jenisImunisasiId|dosisKe".
  final Map<String, _PilihImunisasi> _imunisasiDipilih = {};

  /// Imunisasi yang sudah tersimpan pada kunjungan ini (saat catatan diubah).
  final Set<String> _imunisasiSesiIni = {};

  /// Kondisi balita sebelum imunisasi: sehat | demam_ringan | sakit.
  String? _kondisi;

  final List<_BarisSuplemen> _suplemen = [];

  // ---- KPSP (skrining perkembangan) ----
  final _svcKpsp = KpspService();

  /// Lembar KPSP sesuai umur balita; null selama belum berhasil diambil.
  LembarKpsp? _kpspLembar;

  /// Jawaban bidan per nomor pertanyaan: true bila "Ya".
  final Map<int, bool> _kpspJawaban = {};

  final _kpspCatatan = TextEditingController();

  bool _kpspMemuat = false;

  /// Imunisasi & suplemen dipilih otomatis sesuai jadwal (catatan belum pernah disimpan).
  bool _otomatis = false;

  DateTime? _mulaiSesi;
  Timer? _jam;

  bool get _riwayatOk => _statusRiwayat == StatusRiwayatImunisasi.dikonfirmasi;

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
    for (final c in [_catatanOrtu, _saranGizi, _kpspCatatan]) {
      c.dispose();
    }
    for (final v in _imunisasiDipilih.values) {
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

  String get _balitaId =>
      (_detail?['balita'] is Map) ? (_detail!['balita']['id']?.toString() ?? '') : '';

  DateTime? get _lahir {
    final a = _detail?['balita'];
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
  List<RiwayatImunisasi> get _laporanOrtu {
    final k = _kartu;
    if (k == null) return const [];
    return k.riwayat
        .where((r) =>
            r.reaksiKipi.trim().isNotEmpty &&
            r.kipiTindakLanjut.trim().isEmpty &&
            !_imunisasiSesiIni.contains('${r.jenis.id}|${r.dosisKe}'))
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
    if (_imunisasiDipilih.isNotEmpty) {
      if (!_riwayatOk) {
        _snack('Catat riwayat imunisasi balita terlebih dahulu');
        return;
      }
      // Kondisi mengikuti pendataan kader; balita sakit tidak boleh mendapat imunisasi baru.
      if (_kondisi == KondisiImunisasi.sakit &&
          _imunisasiDipilih.keys.any((k) => !_imunisasiSesiIni.contains(k))) {
        _snack('Balita sedang sakit (pendataan kader). Hapus centangnya dan tunda imunisasi.');
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
          'imunisasi': [
            for (final e in _imunisasiDipilih.entries)
              {
                'jenis_imunisasi_id': e.key.split('|').first,
                'dosis_ke': int.tryParse(e.key.split('|').last) ?? 1,
                'kondisi_balita': _kondisi ?? '',
              }
          ],
          // KPSP hanya dikirim bila seluruh 10 pertanyaan terjawab; bila tidak,
          // kuncinya tidak disertakan sehingga lembar lama (bila ada) terhapus.
          if (_kpspJawaban.length == 10 && (_kpspLembar?.siap ?? false))
            'kpsp': {
              'usia_bulan': _kpspLembar!.usiaBulan,
              'catatan': _kpspCatatan.text.trim(),
              'jawaban': [
                for (var n = 1; n <= 10; n++) {'nomor': n, 'ya': _kpspJawaban[n] == true}
              ],
            },
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
  // KPSP
  // -------------------------------------------------------------------------
  /// Mengambil lembar KPSP sesuai umur balita. Dipanggil dari _muat setelah
  /// detail pendaftaran diterima, dan dapat diulang bidan lewat tombol
  /// "Coba Ambil Lagi" bila jaringan sempat putus.
  Future<void> _muatKpsp() async {
    if (_kpspUsiaBalita <= 0 || _kpspMemuat) return;
    setState(() => _kpspMemuat = true);
    final lembar = await _svcKpsp.lembar(_kpspUsiaBalita);
    if (!mounted) return;
    setState(() {
      _kpspLembar = lembar;
      _kpspMemuat = false;
    });
  }

  /// Umur balita dalam bulan, diisi _muat dari detail pendaftaran.
  int _kpspUsiaBalita = 0;

  /// Mengisi jawaban dari hasil KPSP yang sudah tersimpan pada kunjungan ini,
  /// supaya bidan melihat isian terakhirnya saat membuka atau mengubah catatan.
  void _isiKpspTersimpan(dynamic raw) {
    if (raw is! Map) return;
    final h = HasilKpsp.fromJson(Map<String, dynamic>.from(raw));
    _kpspJawaban
      ..clear()
      ..addAll(h.jawaban);
    _kpspCatatan.text = h.catatan;
  }

  // -------------------------------------------------------------------------
  // RIWAYAT IMUNISASI SEBELUM POSYANDU
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

  Future<void> _benarkan(RiwayatImunisasi r) =>
      _jalankan(() => _svcImunisasi.konfirmasiRiwayat(r.id), '${r.namaDosis} dikonfirmasi');

  Future<void> _ubahTanggal(RiwayatImunisasi r) async {
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
      () => _svcImunisasi.konfirmasiRiwayat(r.id, tanggal: t),
      'Tanggal diperbaiki dan dikonfirmasi',
    );
  }

  Future<void> _batalkan(RiwayatImunisasi r) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan catatan imunisasi?'),
        content: Text(
          '${r.namaDosis} akan dihapus dari riwayat. Gunakan bila orang tua menyatakan '
          'balita ternyata belum menerima imunisasi ini.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan')),
        ],
      ),
    );
    if (ya != true) return;
    await _jalankan(() => _svcImunisasi.hapusRiwayat(r.id), 'Catatan imunisasi dibatalkan');
  }

  /// Bidan mencatat tindak lanjut atas reaksi yang dilaporkan orang tua.
  /// Setelah tersimpan, laporan tidak tampil lagi di atas form pemeriksaan.
  Future<void> _isiTindakLanjut(RiwayatImunisasi r) async {
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
      () => _svcImunisasi.tindakLanjutKipi(r.id, reaksi: r.reaksiKipi, tindakLanjut: tindak),
      'Tindak lanjut tersimpan',
    );
  }

  /// Kunjungan pertama: bidan mencatat riwayat imunisasi balita sebelum posyandu
  /// (belum pernah / sudah pernah + daftar centang + imunisasi mandiri).
  Future<void> _catatRiwayatAwal() async {
    final lahir = _lahir;
    if (lahir == null) {
      _snack('Tanggal lahir balita belum tersedia');
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
      builder: (_) => _FormRiwayatImunisasiAwal(
        balitaId: _balitaId,
        nama: _kartu?.balita.nama ?? '',
        lahir: lahir,
        sudahTercatat: sudah,
        adaRiwayatLuar: _riwayatLuar.isNotEmpty,
      ),
    );
    if (hasil == true) {
      _snack('Riwayat imunisasi balita tersimpan');
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