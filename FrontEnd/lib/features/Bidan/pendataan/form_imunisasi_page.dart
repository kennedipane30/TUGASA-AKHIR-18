part of 'catat_pemeriksaan_page.dart';

// ===========================================================================
// FORM IMUNISASI
// Dua bagian: imunisasi yang diberikan hari ini, dan riwayat imunisasi anak
// sebelum posyandu yang dicatat bidan sekali pada kunjungan pertama.
// ===========================================================================

class _PilihImunisasi {
  _PilihImunisasi();

  void dispose() {}
}

/// Judul header (gaya teks sama dengan halaman lain).

// ---------------------------------------------------------------------------
// TAMPILAN BAGIAN IMUNISASI HARI INI
// ---------------------------------------------------------------------------
mixin _FormImunisasi<T extends StatefulWidget> on _FormPemeriksaan<T> {
  // -------------------------------------------------------------------------
  // IMUNISASI HARI INI
  // -------------------------------------------------------------------------
  Widget _kartuImunisasi() {
    if (!_riwayatOk) {
      return kartuBidan(
        judul: 'Imunisasi Hari Ini',
        kanan: 'Terkunci',
        warnaKanan: AppColors.teksRedup,
        child: const Text(
          'Catat riwayat imunisasi anak di atas terlebih dahulu agar tidak ada imunisasi yang diberikan dua kali.',
          style: TextStyle(fontSize: 16.5, color: AppColors.teksRedup),
        ),
      );
    }

    final k = _kartu;
    if (k == null) {
      return kartuBidan(
        judul: 'Imunisasi Hari Ini',
        child: Column(
          children: [
            Text(
              _gagalKartu ?? 'Jadwal imunisasi anak tidak dapat dimuat',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16.5, color: AppColors.teksRedup),
            ),
            const SizedBox(height: 10),
            tombolGarisBidan('Muat Ulang', ikon: Icons.refresh, onPressed: () {
              setState(() => _memuat = true);
              _muat();
            }),
          ],
        ),
      );
    }

    final calon = k.jadwal
        .where((e) => (e.bisaDiberikan && !e.keFaskes) || _imunisasiSesiIni.contains(e.jadwal.kunci))
        .toList();
    final faskes = k.jadwal.where((e) => !e.sudah && e.keFaskes && e.status != StatusImunisasi.terlewat).toList();
    final sakit = _kondisi == KondisiImunisasi.sakit;

    return kartuBidan(
      judul: 'Imunisasi Hari Ini',
      kanan: '${_imunisasiDipilih.length} dipilih',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_otomatis && _imunisasiDipilih.isNotEmpty)
            _info('Imunisasi sesuai jadwal sudah dicentang otomatis. Hapus centang bila tidak diberikan.',
                ikon: Icons.auto_awesome, bg: AppColors.hijauMuda, fg: AppColors.hijau),
          if (calon.isEmpty)
            const Text('Tidak ada imunisasi yang perlu diberikan hari ini.',
                style: TextStyle(fontSize: 16.5, color: AppColors.teksRedup))
          else ...[
            // Kondisi anak diambil dari pendataan kader (Kondisi Anak: "Sedang sakit").
            const Text('Kondisi anak (dari pendataan kader)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: _teksGelap)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sakit ? AppColors.merah : _hijauHeader,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sakit ? Icons.sick_outlined : Icons.favorite_outline, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(sakit ? 'Sedang sakit' : 'Sehat',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (sakit)
              _info('Anak sedang sakit: tunda imunisasi sampai anak sehat.',
                  ikon: Icons.do_not_disturb_on_outlined, bg: AppColors.merahMuda, fg: AppColors.merah)
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Centang imunisasi yang diberikan hari ini.',
                    style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
              ),
            for (final e in calon) _barisCalon(e, terkunci: sakit),
          ],
          if (faskes.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final e in faskes)
              _info('${e.jadwal.namaDosis}: ${e.teksJadwal}',
                  ikon: Icons.local_hospital_outlined, bg: AppColors.merahMuda, fg: AppColors.merah),
          ],
        ],
      ),
    );
  }

  Widget _barisCalon(JadwalImunisasiAnak e, {required bool terkunci}) {
    final kunci = e.jadwal.kunci;
    final pilih = _imunisasiDipilih[kunci];
    final dipilih = pilih != null;
    final tersimpan = _imunisasiSesiIni.contains(kunci);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: dipilih ? AppColors.hijauMuda : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dipilih ? _hijauHeader : garisKartuBidan, width: 1.2),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: dipilih,
            activeColor: _hijauHeader,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.only(left: 4, right: 10),
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onChanged: (terkunci && !dipilih)
                ? null
                : (v) => setState(() {
                      if (v == true) {
                        _imunisasiDipilih[kunci] = _PilihImunisasi();
                      } else {
                        _imunisasiDipilih.remove(kunci)?.dispose();
                      }
                    }),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Usia ${e.jadwal.labelUsia}',
                          style: const TextStyle(color: aksenKartuBidan),
                        ),
                        if (e.susulan)
                          const TextSpan(text: '  ·  Susulan', style: TextStyle(color: AppColors.kuning)),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(e.jadwal.namaDosis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, color: _teksGelap)),
              ],
            ),
            subtitle: Text(
              [
                if (e.susulan) e.labelStatus,
                if (e.jadwal.jenis.penyakit.isNotEmpty) 'Mencegah ${e.jadwal.jenis.penyakit}',
                if (e.jadwal.jenis.caraPemberian.isNotEmpty) e.jadwal.jenis.caraPemberian,
              ].join(' · '),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (pilih != null && tersimpan)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 12, 10),
              child: Text('Tersimpan',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _hijauHeader)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORM RIWAYAT IMUNISASI SEBELUM POSYANDU (bidan, kunjungan pertama anak)
//   - Belum pernah diimunisasi, atau
//   - Sudah pernah: centang dosis imunisasi program + "imunisasi mandiri" di luar daftar.
// Data langsung sah. Dosis yang sudah tercatat tampil terkunci (tidak dobel).
// ---------------------------------------------------------------------------

/// Isian satu dosis imunisasi program yang dicentang.
class _DosisAwal {
  DateTime? tanggal;
  final tempat = TextEditingController();
  String foto = '';
  bool mengunggah = false;

  void dispose() => tempat.dispose();
}

/// Isian satu imunisasi di luar daftar program.
class _ImunisasiMandiriAwal {
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

class _FormRiwayatImunisasiAwal extends StatefulWidget {
  final String anakId;
  final String nama;
  final DateTime lahir;

  /// Kunci "jenisImunisasiId|dosisKe" yang sudah tercatat.
  final Set<String> sudahTercatat;

  /// Sudah ada catatan imunisasi dari luar posyandu (mis. laporan lama yang sudah dibenarkan).
  final bool adaRiwayatLuar;

  const _FormRiwayatImunisasiAwal({
    required this.anakId,
    required this.nama,
    required this.lahir,
    required this.sudahTercatat,
    required this.adaRiwayatLuar,
  });

  @override
  State<_FormRiwayatImunisasiAwal> createState() => _FormRiwayatImunisasiAwalState();
}

class _FormRiwayatImunisasiAwalState extends State<_FormRiwayatImunisasiAwal> {
  final _svc = ImunisasiService();
  String _status = ''; // sudah | belum_pernah
  List<JadwalImunisasi> _master = [];
  bool _memuatMaster = false;
  final Map<String, _DosisAwal> _dipilih = {};
  final List<_ImunisasiMandiriAwal> _mandiri = [];
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

  Future<void> _fotoMandiri(_ImunisasiMandiriAwal v) async {
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
      setState(() => _galat = 'Pilih: belum pernah atau sudah pernah diimunisasi');
      return;
    }
    final items = <Map<String, dynamic>>[];
    final mandiri = <Map<String, dynamic>>[];
    if (_status == 'sudah') {
      for (final e in _dipilih.entries) {
        final d = e.value;
        if (d.tanggal == null || d.tempat.text.trim().isEmpty) {
          setState(() => _galat = 'Isi tanggal dan tempat untuk setiap imunisasi yang dicentang');
          return;
        }
        if (d.mengunggah) {
          setState(() => _galat = 'Tunggu foto selesai diunggah');
          return;
        }
        items.add({
          'jenis_vaksin_id': e.key.split('|').first,
          'dosis_ke': int.tryParse(e.key.split('|').last) ?? 1,
          'tanggal_pemberian': tanggalApiImunisasi(d.tanggal!),
          'tempat': d.tempat.text.trim(),
          'foto_bukti': d.foto,
        });
      }
      final kunciMandiri = <String>{};
      for (final v in _mandiri) {
        final nama = v.nama.text.trim();
        if (nama.isEmpty || v.tanggal == null || v.tempat.text.trim().isEmpty) {
          setState(() => _galat = 'Isi nama imunisasi, tanggal, dan tempat untuk setiap imunisasi mandiri');
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
          'tanggal_pemberian': tanggalApiImunisasi(v.tanggal!),
          'tempat': v.tempat.text.trim(),
          'foto_bukti': v.foto,
        });
      }
      if (items.isEmpty && mandiri.isEmpty && !widget.adaRiwayatLuar) {
        setState(() => _galat = 'Centang minimal satu imunisasi atau tambahkan imunisasi mandiri');
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

  /// Baris tanggal + tempat + foto (dipakai dosis program & imunisasi mandiri).
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

  Widget _barisImunisasi(JadwalImunisasi j) {
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
                child: Text('Imunisasi mandiri ${i + 1}',
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
                  decoration: dekorFormBidan('Nama imunisasi * (mis. Rotavirus, PCV)', ikon: Icons.vaccines_outlined)
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
            const Text('RIWAYAT IMUNISASI SEBELUM POSYANDU',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _teksGelap)),
            const SizedBox(height: 6),
            Container(height: 3, color: aksenKartuBidan),
            const SizedBox(height: 10),
            Text(
              'Apakah ${widget.nama.isEmpty ? 'anak' : widget.nama} sudah pernah menerima imunisasi sebelum ke posyandu '
              '(rumah sakit, puskesmas, klinik, atau bidan praktik)? Cocokkan dengan Buku KIA.',
              style: const TextStyle(fontSize: 16, color: AppColors.teksRedup, height: 1.4),
            ),
            const SizedBox(height: 14),
            _opsi('belum_pernah', 'Belum pernah', 'Anak belum pernah diimunisasi', Icons.block_outlined),
            _opsi('sudah', 'Sudah pernah', 'Centang imunisasi yang sudah diterima', Icons.vaccines_outlined),
            if (_status == 'sudah') ...[
              const SizedBox(height: 6),
              if (_memuatMaster)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final j in _master) _barisImunisasi(j),
              const SizedBox(height: 10),
              const Text('IMUNISASI MANDIRI (DI LUAR PROGRAM)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _teksGelap)),
              const SizedBox(height: 4),
              const Text('Mis. Rotavirus, PCV, Influenza, Varisela, Hepatitis A.',
                  style: TextStyle(fontSize: 15, color: AppColors.teksRedup)),
              const SizedBox(height: 8),
              for (var i = 0; i < _mandiri.length; i++) _barisMandiri(i),
              tombolGarisBidan(
                'Tambah Imunisasi Mandiri',
                ikon: Icons.add,
                onPressed: () => setState(() => _mandiri.add(_ImunisasiMandiriAwal())),
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
                'Imunisasi yang dicatat langsung sah dan tidak akan diberikan lagi di posyandu. '
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