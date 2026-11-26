part of 'catat_pemeriksaan_page.dart';

// ---------------------------------------------------------------------------
// HALAMAN EDIT PEMERIKSAAN (anak yang catatan bidannya sudah tersimpan)
// Catatan, imunisasi, dan suplemen yang tersimpan dimuat ke form.
// ---------------------------------------------------------------------------
class EditPemeriksaanPage extends StatefulWidget {
  final String pendaftaranId;
  final String nomor;

  const EditPemeriksaanPage({
    super.key,
    required this.pendaftaranId,
    required this.nomor,
  });

  @override
  State<EditPemeriksaanPage> createState() => _EditPemeriksaanState();
}

class _EditPemeriksaanState extends State<EditPemeriksaanPage>
    with _FormPemeriksaan<EditPemeriksaanPage>,
        _FormSuplemen<EditPemeriksaanPage>,
        _FormImunisasi<EditPemeriksaanPage>,
        _FormKpsp<EditPemeriksaanPage>,
        _KartuPemeriksaan<EditPemeriksaanPage> {
  @override
  String get pendaftaranId => widget.pendaftaranId;

  @override
  String get nomor => widget.nomor;

  @override
  bool get modeEdit => true;

  @override
  void initState() {
    super.initState();
    _muat();
    _jam = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _mulaiSesi != null) setState(() {});
    });
  }

  @override
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

      // Isi form dari catatan yang sudah tersimpan.
      final c = detail['catatan'];
      if (c is Map) {
        _catatanOrtu.text = c['catatan_evaluasi']?.toString() ?? '';
        _saranGizi.text = c['saran_gizi']?.toString() ?? '';
      }

      // Riwayat imunisasi sebelum posyandu.
      final status = detail['status_riwayat_vaksin']?.toString() ?? '';
      final luar = <RiwayatImunisasi>[];
      final rl = detail['riwayat_luar'];
      if (rl is List) {
        for (final e in rl) {
          if (e is Map) luar.add(RiwayatImunisasi.fromJson(Map<String, dynamic>.from(e)));
        }
      }

      // Imunisasi yang sudah tersimpan pada kunjungan ini.
      for (final v in _imunisasiDipilih.values) {
        v.dispose();
      }
      _imunisasiDipilih.clear();
      _imunisasiSesiIni.clear();
      _kondisi = null;
      final imun = detail['imunisasi'];
      if (imun is List) {
        for (final e in imun) {
          if (e is Map && e['jenis_vaksin_id'] != null) {
            final k = '${e['jenis_vaksin_id']}|${e['dosis_ke']}';
            _imunisasiDipilih[k] = _PilihImunisasi();
            _imunisasiSesiIni.add(k);
          }
        }
      }

      // Kondisi anak sebelum imunisasi mengikuti pendataan kader ("Sedang sakit").
      final ukurKader = detail['pengukuran'] is Map
          ? Map<String, dynamic>.from(detail['pengukuran'] as Map)
          : const <String, dynamic>{};
      final sakitKader = ukurKader['sedang_sakit'] == true;
      _kondisi = sakitKader ? KondisiImunisasi.sakit : KondisiImunisasi.sehat;

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
            aturanPakai: e['aturan_pakai']?.toString() ?? '',
            jumlah: dataLama ? 1 : jumlah,
            satuan: satuan.isEmpty ? 'kapsul' : satuan,
            tetap: _namaVitaminA(jenis) || _namaObatCacing(jenis),
          ));
        }
      }

      // Form suplemen langsung tampil (satu baris kosong bila belum ada suplemen).
      _siapkanFormSuplemen();

      // KPSP: umur anak menentukan lembar yang dipakai; jawaban yang sudah
      // tersimpan ditampilkan kembali agar bidan dapat mengubahnya.
      _kpspUsiaAnak = int.tryParse(detail['usia_bulan']?.toString() ?? '') ?? 0;
      _isiKpspTersimpan(detail['kpsp']);

      // Kartu imunisasi anak (jadwal + status).
      KartuImunisasi? kartu;
      String? gagalKartu;
      final anakId = (detail['anak'] is Map) ? (detail['anak']['id']?.toString() ?? '') : '';
      if (anakId.isNotEmpty) {
        try {
          kartu = await _svcImunisasi.kartuAnak(anakId);
        } catch (e) {
          gagalKartu = _pesanError(e);
        }
      }

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _mulaiSesi = mulaiSesi;
        _statusRiwayat = status.isEmpty ? StatusRiwayatImunisasi.belumDitanya : status;
        _riwayatLuar = luar;
        _kartu = kartu;
        _gagalKartu = gagalKartu;
        _otomatis = false;
        _gagal = null;
        _memuat = false;
      });
      unawaited(_muatKpsp());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesanError(e);
        _memuat = false;
      });
    }
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
                child: _judulTebal('Edit Pemeriksaan'),
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
                                Text(_gagal!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
                                const SizedBox(height: 12),
                                tombolHijauBidan('Coba Lagi', ikon: Icons.refresh, onPressed: () {
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
      bottomNavigationBar: (_memuat || _gagal != null) ? null : _tombolBawah(),
    );
  }

  Widget _tombolBawah() {
    final terkunci = _mulaiNanti != null || _jadwalSelesai;
    final label = _jadwalSelesai
        ? 'Jadwal Sudah Selesai'
        : _mulaiNanti != null
            ? 'Sesi Belum Dimulai'
            : _kirim
                ? 'Menyimpan...'
                : 'Simpan Perubahan';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _kirim ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.merah,
                    side: const BorderSide(color: AppColors.merah, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: (_kirim || terkunci) ? null : _simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hijauHeader,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _hijauHeader.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}