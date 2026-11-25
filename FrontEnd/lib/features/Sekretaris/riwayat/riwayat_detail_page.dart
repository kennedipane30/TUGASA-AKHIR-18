part of 'riwayat_page.dart';

// ---------------------------------------------------------------------------
// HALAMAN 2: DAFTAR ANAK PADA SATU JADWAL
// ---------------------------------------------------------------------------
class _DaftarAnakPage extends StatefulWidget {
  final Map<String, dynamic> jadwal;
  const _DaftarAnakPage({required this.jadwal});

  String get jadwalId => _teks(jadwal['id']);

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
    final j = widget.jadwal;
    return _halaman(
      judul: 'Detail Riwayat',
      isi: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _kartu(
              title: _fmtHari(_tgl(j['tanggal'])),
              sub: _fmtTgl(_tgl(j['tanggal'])),
              kanan: _fmtWaktu(j),
              child: _bagian(Icons.location_on_outlined, 'Lokasi', _teks(j['lokasi'])),
            ),
            if (_memuat)
              _memuatBox()
            else if (_gagal != null)
              _gagalKartu(_gagal!, () {
                setState(() => _memuat = true);
                _muat();
              })
            else
              _kartu(
                title: 'Daftar Balita',
                kanan: '${_data.length} anak',
                child: _data.isEmpty
                    ? const Text('Belum ada anak yang check-in pada jadwal ini.',
                        style: TextStyle(fontSize: 16, color: AppColors.teksRedup))
                    : Column(children: [for (final a in _data) _baris(a)]),
              ),
          ],
        ),
      ),
    );
  }

  /// Label status: hijau bila sudah, kuning bila belum (warna sama untuk ukur & catat).
  Widget _status(String teks, bool sudah) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sudah ? _hijauHeader : AppColors.kuningMuda,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(teks,
            maxLines: 1,
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: sudah ? Colors.white : AppColors.kuning)),
      );

  Widget _baris(Map<String, dynamic> a) {
    final nomor = int.tryParse(_teks(a['nomor_antrean']));
    final kode = nomor == null ? '-' : 'A-${nomor.toString().padLeft(3, '0')}';
    final diukur = a['sudah_diukur'] == true;
    final selesai = _teks(a['status_catatan']) == 'selesai';
    final usia = int.tryParse(_teks(a['usia_bulan'])) ?? 0;
    final gizi = pilGizi(a['status_gizi']);

    // Kartu putih bila belum dicatat bidan, hijau bila sudah dicatat.
    final bg = selesai ? AppColors.hijauMuda : Colors.white;
    final garis = selesai ? const Color(0xFFBFE5D0) : _garisDetail;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _HasilAnakPage(pendaftaranId: _teks(a['pendaftaran_id'])),
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: garis, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Antrean $kode',
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.hijau)),
                const SizedBox(height: 2),
                Text(_teks(a['nama']),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: _teksGelap)),
                Text(
                    '${_teks(a['jenis_kelamin']) == 'P' ? 'Perempuan' : 'Laki-laki'} · ${_usia(usia, lahir: a['tanggal_lahir'])}',
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.teksRedup)),
                if (gizi.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: gizi),
                ],
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      _status(diukur ? 'Sudah diukur' : 'Belum diukur', diukur),
                      const SizedBox(width: 6),
                      _status(selesai ? 'Dicatat bidan' : 'Belum dicatat bidan', selesai),
                    ],
                  ),
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
  Map<String, String> _namaImunisasi = {};
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
        _namaImunisasi = peta;
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
                  style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
            ),
            Expanded(
              child: Text(nilai.isEmpty ? '-' : nilai,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500, color: _teksGelap)),
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
                      fontSize: 19, fontWeight: FontWeight.w600, color: fg)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5, color: AppColors.teksRedup)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _halaman(
      judul: 'Hasil Pendataan',
      isi: RefreshIndicator(
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
              _kartu(
                title: 'Data Tidak Tersedia',
                child: const Text('Data tidak tersedia.',
                    style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
              )
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
    final ulang = _tgl(c?['tanggal_kunjungan_ulang']);
    final peringatan = _teks(u?['peringatan_validasi']);

    return [
      _kartu(
        title: _teks(anak['nama']).isEmpty ? 'Anak' : _teks(anak['nama']),
        kanan: _fmtTgl(_tgl(jadwal['tanggal'])),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baris('Jenis kelamin',
                _teks(anak['jenis_kelamin']) == 'P' ? 'Perempuan' : 'Laki-laki'),
            _baris('Usia', _usia(usia, lahir: anak['tanggal_lahir'], pada: _tgl(jadwal['tanggal']))),
            if (_jam(jadwal['jam_mulai']).isNotEmpty)
              _baris('Sesi posyandu', '${_jam(jadwal['jam_mulai'])} WIB'),
          ],
        ),
      ),
      _kartu(
        title: 'Hasil Pengukuran (Kader)',
        child: u == null
            ? const Text('Kader belum menginput pengukuran.',
                style: TextStyle(fontSize: 16, color: AppColors.teksRedup))
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
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
      ),
      _kartu(
        title: 'Status Gizi',
        child: u == null
            ? const Text(
                'Belum ada pengukuran.',
                style: TextStyle(fontSize: 16, color: AppColors.teksRedup),
              )
            : KotakStatusGizi(d['status_gizi']),
      ),
      _kartu(
        title: 'Catatan Bidan',
        child: c == null
            ? const Text('Bidan belum menuliskan catatan.',
                style: TextStyle(fontSize: 16, color: AppColors.teksRedup))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _baris('Keluhan', _teks(c['keluhan'])),
                  _baris('Hasil pemeriksaan', _teks(c['catatan_evaluasi'])),
                  _baris('Catatan untuk orang tua', _teks(c['saran_gizi'])),
                  _baris('Kunjungan ulang', ulang == null ? '' : _fmtTgl(ulang)),
                ],
              ),
      ),
      if (imun.isNotEmpty)
        _kartu(
          title: 'Imunisasi',
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
                          '${_namaImunisasi[_teks(v['jenis_imunisasi_id'])] ?? 'Imunisasi'} · Dosis ${_teks(v['dosis_ke'])}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              color: _teksGelap)),
                      if (_teks(v['kondisi_anak']).isNotEmpty)
                        Text('Kondisi: ${_kondisiTeks(v['kondisi_anak'])}',
                            style: const TextStyle(
                                fontSize: 16, color: AppColors.teksRedup)),
                      if (_teks(v['nomor_batch']).isNotEmpty)
                        Text('No. batch: ${_teks(v['nomor_batch'])}',
                            style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                      if (_teks(v['reaksi_kipi']).isNotEmpty)
                        Text('Reaksi setelah imunisasi: ${_teks(v['reaksi_kipi'])}',
                            style: const TextStyle(fontSize: 16, color: AppColors.merah)),
                      if (_teks(v['tempat']).isNotEmpty)
                        Text('Tempat: ${_teks(v['tempat'])}',
                            style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                      if (_teks(v['catatan']).isNotEmpty)
                        Text('Catatan: ${_teks(v['catatan'])}',
                            style: const TextStyle(
                                fontSize: 16, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (sup.isNotEmpty)
        _kartu(
          title: 'Suplemen',
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
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              color: _teksGelap)),
                      if (_teks(s['keterangan_dosis']).isNotEmpty)
                        Text('Dosis: ${_teks(s['keterangan_dosis'])}',
                            style: const TextStyle(
                                fontSize: 16, color: AppColors.teksRedup)),
                      if (_teks(s['catatan']).isNotEmpty)
                        Text('Catatan: ${_teks(s['catatan'])}',
                            style: const TextStyle(
                                fontSize: 16, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}