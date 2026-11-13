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
    with _FormPemeriksaan<EditPemeriksaanPage>, _KartuPemeriksaan<EditPemeriksaanPage> {
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
        _otomatis = false;
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
      bottomNavigationBar: (_memuat || _gagal != null) ? null : _tombolBawah(),
    );
  }

  Widget _tombolBawah() {
    final terkunci = _mulaiNanti != null;
    final label = terkunci
        ? 'Sesi Belum Dimulai'
        : _kirim
            ? 'Menyimpan...'
            : 'Simpan Perubahan';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                    foregroundColor: _hijauHeader,
                    side: const BorderSide(color: _hijauHeader, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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