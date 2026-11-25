part of 'pemeriksaan_page.dart';

// ---------------------------------------------------------------------------
// HALAMAN 2: DETAIL RIWAYAT PEMERIKSAAN
// ---------------------------------------------------------------------------
class _DetailRiwayatPage extends StatelessWidget {
  final _Pemeriksaan data;

  const _DetailRiwayatPage({required this.data});

  static const _pemisah = Divider(height: 18, color: Color(0xFFE5E7EB));

  /// Kotak isi catatan: putih bergaris lembut, judul tebal.
  Widget _blok(String judul, String isi) {
    if (isi.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _garis, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _teksGelap)),
          const SizedBox(height: 3),
          Text(isi,
              style: const TextStyle(fontSize: 15.5, height: 1.4, color: Color(0xFF374151))),
        ],
      ),
    );
  }

  /// Satu item imunisasi / suplemen dalam kotak bergaris lembut.
  Widget _item(String judul, String kanan, List<String> baris) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _garis, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(judul,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16, color: _teksGelap)),
              ),
              if (kanan.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(kanan,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: _hijauHeader)),
              ],
            ],
          ),
          for (final b in baris)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(b,
                  style: const TextStyle(fontSize: 15.5, height: 1.35, color: Color(0xFF374151))),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final t = d.tanggal;
    final adaIsiCatatan =
        d.evaluasi.isNotEmpty || d.saranGizi.isNotEmpty || d.keluhan.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.latar,
      body: Column(
        children: [
          _header(context, 'Detail Riwayat'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Identitas anak + hasil pengukuran (digabung dalam satu kartu)
                _kartu(
                  judul: d.namaAnak,
                  kanan: t == null ? null : formatTanggal(t),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (d.adaUkur) _barisInfo('Usia', d.usiaTeks),
                      if (d.caraUkur.isNotEmpty) _barisInfo('Cara ukur', d.caraUkur),
                      if (d.jamMulai.isNotEmpty) _barisInfo('Sesi posyandu', '${d.jamMulai} WIB'),
                      if (d.adaUkur) ...[
                        _pemisah,
                        _barisInfo('Berat badan', '${_num(d.bb)} kg'),
                        _barisInfo('Tinggi/panjang', '${_num(d.tb)} cm'),
                        _barisInfo('Lingkar kepala', d.lk == '-' ? '-' : '${d.lk} cm'),
                        _barisInfo('LiLA', d.lila == '-' ? '-' : '${d.lila} cm'),
                      ] else
                        const Text('Belum ada hasil pengukuran untuk kunjungan ini.',
                            style: TextStyle(fontSize: 15.5, color: _teksAbu)),
                    ],
                  ),
                ),

                // Status gizi
                if (d.adaUkur && d.statusGizi != null)
                  _kartu(
                    judul: 'Status Gizi Anak',
                    child: KotakStatusGizi(d.statusGizi, untukOrangTua: true),
                  ),

                // Catatan bidan (+ kunjungan ulang)
                _kartu(
                  judul: 'Catatan Bidan',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!d.adaCatatan || !adaIsiCatatan)
                        const Text(
                          'Bidan belum menuliskan catatan untuk kunjungan ini.',
                          style: TextStyle(fontSize: 15.5, color: _teksAbu),
                        )
                      else ...[
                        _blok('Keluhan', d.keluhan),
                        _blok('Hasil pemeriksaan', d.evaluasi),
                        _blok('Catatan untuk orang tua', d.saranGizi),
                      ],
                      if (d.kunjunganUlang != null) ...[
                        const SizedBox(height: 4),
                        _barisInfo('Kunjungan ulang', formatTanggal(d.kunjunganUlang!), lebar: 140),
                      ],
                    ],
                  ),
                ),

                // Imunisasi
                if (d.imunisasi.isNotEmpty)
                  _kartu(
                    judul: 'Imunisasi',
                    kanan: '${d.imunisasi.length} imunisasi',
                    child: Column(
                      children: [
                        for (final v in d.imunisasi)
                          _item(v.nama, 'Dosis ${v.dosis}', [
                            if (v.kondisi.isNotEmpty) 'Kondisi: ${v.kondisi}',
                            if (v.catatan.isNotEmpty) 'Catatan: ${v.catatan}',
                          ]),
                      ],
                    ),
                  ),

                // KPSP (skrining perkembangan) — hanya tampil bila bidan mengisinya
                if (d.kpsp != null) _kartuKpspRiwayat(d.kpsp!),

                // Suplemen
                if (d.suplemen.isNotEmpty)
                  _kartu(
                    judul: 'Suplemen',
                    kanan: '${d.suplemen.length} item',
                    child: Column(
                      children: [
                        for (final s in d.suplemen)
                          _item(s.nama, '', [
                            if (s.dosis.isNotEmpty) 'Dosis: ${s.dosis}',
                            if (s.catatan.isNotEmpty) 'Catatan: ${s.catatan}',
                          ]),
                      ],
                    ),
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
// KARTU HASIL KPSP
// Ditampilkan pada riwayat pemeriksaan orang tua dan bidan. Hanya muncul bila
// bidan memang melakukan skrining pada kunjungan tersebut.
// ---------------------------------------------------------------------------
Widget _kartuKpspRiwayat(HasilKpsp k) {
  final warna = switch (k.hasil) {
    kpspSesuai => AppColors.hijauTua,
    kpspMeragukan => AppColors.kuning,
    kpspPenyimpangan => AppColors.merah,
    _ => AppColors.teksAbu,
  };
  return _kartu(
    judul: 'KPSP (Skrining Perkembangan)',
    kanan: 'Umur ${k.usiaBulan} bulan',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          decoration: BoxDecoration(
            color: warna.withValues(alpha: 0.08),
            border: Border.all(color: warna.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 18, color: warna),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(labelHasilKpsp(k.hasil),
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700, color: warna)),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text('Jawaban "Ya": ${k.jumlahYa} dari 10',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: warna)),
              const SizedBox(height: 4),
              Text(saranHasilKpsp(k.hasil),
                  style: const TextStyle(fontSize: 13, height: 1.35, color: _teksGelap)),
            ],
          ),
        ),
        if (k.catatan.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Catatan bidan',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.teksAbu)),
          const SizedBox(height: 3),
          Text(k.catatan,
              style: const TextStyle(fontSize: 13.5, height: 1.35, color: _teksGelap)),
        ],
      ],
    ),
  );
}