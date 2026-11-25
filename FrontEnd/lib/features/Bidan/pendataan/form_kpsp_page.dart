part of 'catat_pemeriksaan_page.dart';

// ===========================================================================
// FORM KPSP (Kuesioner Pra Skrining Perkembangan)
//
// Kartu ini hanya muncul bila umur anak berada pada jangkauan KPSP (3-72
// bulan). Lembar yang dipakai ditentukan server dari tanggal lahir anak:
// tiap 3 bulan sampai umur 24 bulan, lalu tiap 6 bulan sampai 72 bulan.
//
// Bidan menjawab Ya/Tidak pada 10 pertanyaan. Hasil S/M/P yang tampil di layar
// hanyalah pratinjau; nilai yang disimpan selalu dihitung ulang di server dari
// jumlah jawaban "Ya", supaya tidak dapat dipalsukan dari aplikasi.
//
// Isian KPSP ikut tersimpan bersama hasil pemeriksaan, imunisasi, dan suplemen
// lewat satu tombol Simpan (lihat _simpan di form_pemeriksaan.dart).
// ===========================================================================

mixin _FormKpsp<T extends StatefulWidget> on _FormPemeriksaan<T> {
  /// Warna penanda tiap hasil skrining.
  Color _warnaKpsp(String hasil) {
    switch (hasil) {
      case kpspSesuai:
        return AppColors.hijauTua;
      case kpspMeragukan:
        return AppColors.kuning;
      case kpspPenyimpangan:
        return AppColors.merah;
    }
    return AppColors.teksAbu;
  }

  // -------------------------------------------------------------------------
  // KARTU KPSP
  // -------------------------------------------------------------------------
  Widget _kartuKpsp() {
    final lembar = _kpspLembar;

    // Di luar jangkauan KPSP (umur < 3 atau > 72 bulan): kartu disembunyikan.
    if (lembar != null && !lembar.berlaku) return const SizedBox.shrink();

    if (_kpspMemuat) {
      return kartuBidan(
        judul: 'KPSP (Skrining Perkembangan)',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      );
    }

    if (lembar == null || !lembar.siap) {
      return kartuBidan(
        judul: 'KPSP (Skrining Perkembangan)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _info(
              'Lembar KPSP belum dapat diambil. Periksa sambungan, lalu buka ulang halaman ini. '
              'Pemeriksaan lain tetap dapat disimpan tanpa KPSP.',
              ikon: Icons.cloud_off_outlined,
              bg: AppColors.kuningMuda,
              fg: AppColors.kuning,
            ),
            const SizedBox(height: 10),
            tombolGarisBidan('Coba Ambil Lagi', ikon: Icons.refresh, onPressed: _muatKpsp),
          ],
        ),
      );
    }

    final terjawab = _kpspJawaban.length;
    final lengkap = terjawab == 10;
    final jumlahYa = _kpspJawaban.values.where((v) => v).length;
    final hasil = hitungHasilKpsp(jumlahYa);

    return kartuBidan(
      judul: 'KPSP (Skrining Perkembangan)',
      kanan: 'Umur ${lembar.usiaBulan} bulan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info(
            'Tanyakan kepada orang tua, atau amati langsung bila memungkinkan. '
            'Jawab sesuai keadaan anak saat ini, bukan yang diharapkan.',
          ),
          const SizedBox(height: 12),
          for (final p in lembar.pertanyaan) _barisKpsp(p),
          const Divider(height: 22),
          _ringkasanKpsp(terjawab, jumlahYa, hasil, lengkap),
          const SizedBox(height: 10),
          _teks(
            _kpspCatatan,
            'Catatan KPSP (opsional)',
            baris: 2,
            hint: 'mis. anak rewel saat diperiksa, perlu diulang dua minggu lagi',
            ikon: Icons.sticky_note_2_outlined,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SATU PERTANYAAN + TOMBOL YA / TIDAK
  // -------------------------------------------------------------------------
  Widget _barisKpsp(PertanyaanKpsp p) {
    final jawab = _kpspJawaban[p.nomor];
    final belum = jawab == null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: belum ? AppColors.kuningMuda.withValues(alpha: 0.35) : Colors.white,
        border: Border.all(color: belum ? AppColors.kuning : garisKartuBidan),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24, height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aksenKartuBidan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('${p.nomor}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: _hijauHeader)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.pertanyaan,
                        style: const TextStyle(
                            fontSize: 14.5, height: 1.35, color: _teksGelap)),
                    const SizedBox(height: 3),
                    Text(p.labelAspek,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.teksAbu, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: _tombolJawabKpsp(p.nomor, true, 'Ya', jawab == true)),
              const SizedBox(width: 8),
              Expanded(child: _tombolJawabKpsp(p.nomor, false, 'Tidak', jawab == false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tombolJawabKpsp(int nomor, bool nilai, String label, bool aktif) {
    final warna = nilai ? AppColors.hijauTua : AppColors.merah;
    return InkWell(
      onTap: _kirim ? null : () => setState(() => _kpspJawaban[nomor] = nilai),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: aktif ? warna.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(color: aktif ? warna : garisKartuBidan, width: aktif ? 1.4 : 1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(nilai ? Icons.check_rounded : Icons.close_rounded,
                size: 17, color: aktif ? warna : AppColors.teksAbu),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    color: aktif ? warna : AppColors.teksAbu)),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // RINGKASAN HASIL
  // -------------------------------------------------------------------------
  Widget _ringkasanKpsp(int terjawab, int jumlahYa, String hasil, bool lengkap) {
    if (!lengkap) {
      return _info(
        'Terjawab $terjawab dari 10. Lengkapi seluruh jawaban agar hasil KPSP dapat disimpan, '
        'atau kosongkan semuanya bila KPSP tidak dilakukan hari ini.',
        ikon: Icons.pending_outlined,
        bg: AppColors.kuningMuda,
        fg: AppColors.kuning,
      );
    }
    final warna = _warnaKpsp(hasil);
    return Container(
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
                child: Text('Jawaban "Ya": $jumlahYa dari 10',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: warna)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(labelHasilKpsp(hasil),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: warna)),
          const SizedBox(height: 4),
          Text(saranHasilKpsp(hasil),
              style: const TextStyle(fontSize: 13, height: 1.35, color: _teksGelap)),
          const SizedBox(height: 6),
          Text('Hasil akhir dihitung ulang oleh sistem saat disimpan.',
              style: TextStyle(fontSize: 11.5, color: AppColors.teksAbu)),
        ],
      ),
    );
  }
}