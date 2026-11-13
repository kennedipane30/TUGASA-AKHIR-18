part of 'catat_pemeriksaan_page.dart';

// ===========================================================================
// TAMPILAN FORM PEMERIKSAAN BIDAN
// Data anak, status gizi, riwayat vaksin, imunisasi hari ini, suplemen.
// ===========================================================================
mixin _KartuPemeriksaan<T extends StatefulWidget> on _FormPemeriksaan<T> {
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
          trailing: Pill('Antrean $nomor'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$jk · $usiaTeks', style: const TextStyle(fontSize: 16.5, color: AppColors.teksRedup)),
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
                  style: const TextStyle(fontSize: 16, color: AppColors.teksRedup),
                ),
              ],
              if ((ukur['keluhan']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Keluhan (kader): ${ukur['keluhan']}', style: const TextStyle(fontSize: 16.5)),
              ],
              if ((ukur['catatan']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Catatan kader: ${ukur['catatan']}', style: const TextStyle(fontSize: 16.5)),
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
        if (ukur.isNotEmpty)
          SectionCard(
            title: 'Status Gizi',
            child: KotakStatusGizi(d['status_gizi']),
          ),
        if (!_riwayatOk) _kartuRiwayat(),
        SectionCard(
          title: 'Catatan Pemeriksaan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _teks(_keluhan, 'Keluhan', hint: 'Mis. demam 2 hari, batuk pilek'),
              _teks(_catatanOrtu, 'Catatan untuk orang tua', baris: 3),
              _teks(_saranGizi, 'Saran gizi', baris: 3),
              const Text('Tanggal kunjungan ulang', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
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
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500),
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
                  style: TextStyle(fontSize: 16, color: AppColors.teksRedup)),
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
                child: Text(r.namaDosis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
            style: const TextStyle(fontSize: 16, color: AppColors.teksRedup),
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
        trailing: const Pill('Terkunci', bg: AppColors.latar, fg: AppColors.teksRedup, icon: Icons.lock_outline),
        child: const Text(
          'Konfirmasi riwayat vaksin anak di atas terlebih dahulu agar tidak ada vaksin yang diberikan dua kali.',
          style: TextStyle(fontSize: 16.5, color: AppColors.teksRedup),
        ),
      );
    }

    final k = _kartu;
    if (k == null) {
      return SectionCard(
        title: 'Imunisasi Hari Ini',
        child: Column(
          children: [
            Text(
              _gagalKartu ?? 'Jadwal imunisasi anak tidak dapat dimuat',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16.5, color: AppColors.teksRedup),
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
      trailing: Pill('${_vaksinDipilih.length} dipilih', bg: AppColors.hijauMuda, fg: AppColors.hijau),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_otomatis && _vaksinDipilih.isNotEmpty)
            _info('Vaksin sesuai jadwal sudah dicentang otomatis. Hapus centang bila tidak diberikan.',
                ikon: Icons.auto_awesome, bg: AppColors.hijauMuda, fg: AppColors.hijau),
          if (calon.isEmpty)
            const Text('Tidak ada vaksin yang perlu diberikan hari ini.',
                style: TextStyle(fontSize: 16.5, color: AppColors.teksRedup))
          else ...[
            const Text('Kondisi anak sebelum imunisasi',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
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
          if (berikutnya.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Jadwal berikutnya', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
                          style: const TextStyle(fontSize: 16, height: 1.35)),
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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Pill('Usia ${e.jadwal.labelUsia}', bg: AppColors.biruMuda, fg: AppColors.biru),
                      if (e.susulan) const Pill('Susulan', bg: AppColors.kuningMuda, fg: AppColors.kuning),
                    ],
                  ),
                ),
                Text(e.jadwal.namaDosis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
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
          if (pilih != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tersimpan) ...[
                    const Pill('Tersimpan', bg: Colors.white, fg: AppColors.hijau),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: pilih.batch,
                    style: const TextStyle(fontSize: 16.5),
                    maxLength: 50,
                    decoration: _dekor('Nomor batch vaksin (opsional)').copyWith(
                      counterText: '',
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pilih.reaksi,
                    style: const TextStyle(fontSize: 16.5),
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
          labelStyle: const TextStyle(fontSize: 16),
          backgroundColor: AppColors.latar,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: onTap,
        );

    return SectionCard(
      title: 'Suplemen Hari Ini',
      trailing: _suplemen.isEmpty ? null : Pill('${_suplemen.length} item', bg: AppColors.kuningMuda, fg: AppColors.kuning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tambah cepat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
                  style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup)),
            ),
          const SizedBox(height: 12),
          if (_suplemen.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Belum ada suplemen yang diberikan hari ini.',
                  style: TextStyle(fontSize: 16.5, color: AppColors.teksRedup)),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                        style: const TextStyle(fontSize: 17),
                        decoration: _dekor('Catatan (opsional)'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      TextField(
                        controller: s.nama,
                        style: const TextStyle(fontSize: 17.5),
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 100,
                        decoration: _dekor('Nama suplemen').copyWith(counterText: ''),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: s.dosis,
                        style: const TextStyle(fontSize: 17.5),
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
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
                              style: const TextStyle(fontSize: 17.5, color: Colors.black87),
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
                        style: const TextStyle(fontSize: 17.5),
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