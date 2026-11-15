part of 'rekap_posyandu_page.dart';

const _teksRekap = Color(0xFF1F2937);

// ============================================================================
// TAB 2: VITAMIN A & OBAT CACING (REKAP TAHUNAN / TUTUP BUKU)
// Data dua semester dalam satu tahun digabung menjadi satu rekap tahunan.
// ============================================================================

/// Gabungan satu kelompok sasaran selama satu tahun (dihitung per dosis).
class _KelompokTahun {
  final String label;
  final String keterangan;
  int sasaran = 0;
  int sudah = 0;

  _KelompokTahun(this.label, this.keterangan);

  int get belum => (sasaran - sudah) < 0 ? 0 : sasaran - sudah;
  double get persen => sasaran == 0 ? 0 : sudah * 100 / sasaran;

  void tambah(KelompokSuplemen k) {
    sasaran += k.sasaran;
    sudah += k.sudah;
  }
}

/// Satu anak yang belum menerima (gabungan dua semester).
class _BelumTahun {
  final String nama, jk, umur, kelompok;
  final List<String> belum = [];

  _BelumTahun(this.nama, this.jk, this.umur, this.kelompok);
}

class _TabSuplemen extends StatefulWidget {
  final String prefix;

  const _TabSuplemen({required this.prefix});

  @override
  State<_TabSuplemen> createState() => _TabSuplemenState();
}

class _TabSuplemenState extends State<_TabSuplemen> {
  final _svc = RekapService();
  int _tahun = DateTime.now().year;
  List<RekapSuplemen> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  /// Semester 2 (Juli-Desember) tahun berjalan belum ada bila sekarang masih Januari-Juni.
  bool get _adaSemester2 {
    final n = DateTime.now();
    return !(_tahun == n.year && n.month < 7);
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasil = await Future.wait([
        _svc.suplemen(_tahun, 1, prefix: widget.prefix),
        if (_adaSemester2) _svc.suplemen(_tahun, 2, prefix: widget.prefix),
      ]);
      if (!mounted) return;
      setState(() {
        _data = hasil;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _ubahTahun(int tahun) {
    setState(() => _tahun = tahun);
    _muat();
  }

  Widget _pemilih() {
    final n = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: bayanganKartuRekap,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Tahun sebelumnya',
            onPressed: () => _ubahTahun(_tahun - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text('Tahun $_tahun',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: _teksRekap)),
          ),
          IconButton(
            tooltip: 'Tahun berikutnya',
            onPressed: _tahun < n.year ? () => _ubahTahun(_tahun + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _pemilih(),
          const SizedBox(height: 12),
          if (_loading)
            _memuat
          else if (_error != null)
            _gagal(_error!, _muat)
          else
            ..._isi(),
        ],
      ),
    );
  }

  /// Kartu kecil satu kelompok sasaran (putih, garis tepi hitam lembut).
  Widget _kelompok(_KelompokTahun k, Color warna) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: garisKartuRekap, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.label,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5, color: _teksRekap)),
                    if (k.keterangan.isNotEmpty)
                      Text(k.keterangan, style: const TextStyle(fontSize: 15, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              Text('${_angka(k.persen)}%',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: warna)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: k.sasaran == 0 ? 0 : (k.sudah / k.sasaran).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.latar,
              color: warna,
            ),
          ),
          const SizedBox(height: 8),
          _barisSup('Sasaran', '${k.sasaran} pemberian'),
          _barisSup('Sudah diberikan', '${k.sudah} pemberian'),
          _barisSup('Belum diberikan', '${k.belum} pemberian'),
        ],
      ),
    );
  }

  /// Baris "Label : nilai" (satu warna hitam).
  Widget _barisSup(String label, String nilai, {double lebar = 140}) {
    const gaya = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.35, color: _teksRekap);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: lebar, child: Text(label, style: gaya)),
          const Text(': ', style: gaya),
          Expanded(child: Text(nilai, style: gaya)),
        ],
      ),
    );
  }

  List<Widget> _isi() {
    // Gabungkan kelompok Vitamin A dari semua semester berdasarkan kodenya.
    final vitA = <String, _KelompokTahun>{};
    final urutan = <String>[];
    _KelompokTahun? cacing;
    final belum = <String, _BelumTahun>{};

    for (var i = 0; i < _data.length; i++) {
      final d = _data[i];
      final semester = i == 0 ? 'Januari-Juni' : 'Juli-Desember';
      for (final k in d.vitaminA) {
        vitA.putIfAbsent(k.kode, () {
          urutan.add(k.kode);
          return _KelompokTahun(k.label, k.keterangan);
        }).tambah(k);
      }
      (cacing ??= _KelompokTahun(d.obatCacing.label, d.obatCacing.keterangan)).tambah(d.obatCacing);
      for (final a in d.belumMenerima) {
        final kunci = '${a.anak.nama}|${a.anak.jkTeks}';
        final b = belum.putIfAbsent(
            kunci, () => _BelumTahun(a.anak.nama, a.anak.jkTeks, a.anak.usiaTeks, a.kelompok));
        for (final x in a.belum) {
          b.belum.add('$x ($semester)');
        }
      }
    }

    Color warna(String kode) => switch (kode) {
          'biru' => AppColors.biru,
          'merah' => AppColors.merah,
          _ => AppColors.hijau,
        };

    final daftarBelum = belum.values.toList();

    return [
      KartuRekap(
        title: 'Vitamin A · Tahun $_tahun',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (urutan.isEmpty)
              const Text('Belum ada data pada tahun ini',
                  style: TextStyle(fontSize: 16, color: AppColors.teksRedup))
            else
              for (final kode in urutan) _kelompok(vitA[kode]!, warna(kode)),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _adaSemester2
                    ? 'Rekap 1 tahun (Januari-Desember $_tahun). Setiap anak mendapat vitamin A 2 kali setahun.'
                    : 'Rekap tahun berjalan (Januari-Juni $_tahun). Data Juli-Desember belum tersedia.',
                style: const TextStyle(fontSize: 15, color: AppColors.teksRedup),
              ),
            ),
          ],
        ),
      ),
      KartuRekap(
        title: 'Obat Cacing · Tahun $_tahun',
        child: cacing == null
            ? const Text('Belum ada data pada tahun ini',
                style: TextStyle(fontSize: 16, color: AppColors.teksRedup))
            : _kelompok(cacing, AppColors.kuning),
      ),
      KartuRekap(
        title: 'Belum Menerima',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (daftarBelum.isEmpty)
              const Text('Semua sasaran sudah menerima',
                  style: TextStyle(fontSize: 16, color: AppColors.teksRedup))
            else
              for (final a in daftarBelum)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: garisKartuRekap, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _barisSup('Nama', a.nama, lebar: 130),
                      _barisSup('Jenis Kelamin', a.jk, lebar: 130),
                      _barisSup('Umur', a.umur, lebar: 130),
                      _barisSup('Kelompok', a.kelompok, lebar: 130),
                      _barisSup('Belum menerima', a.belum.join(', '), lebar: 130),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            _barisSup('Total balita', '${daftarBelum.length}', lebar: 110),
          ],
        ),
      ),
    ];
  }
}