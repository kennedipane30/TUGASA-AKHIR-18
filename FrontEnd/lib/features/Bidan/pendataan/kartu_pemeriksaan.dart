part of 'catat_pemeriksaan_page.dart';

// ===========================================================================
// RANGKA HALAMAN & KOMPONEN TAMPILAN BIDAN
// Komponen kartu/tombol/banner yang dipakai bersama seluruh bagian form,
// lalu _isi() yang merangkai urutan kartu pada halaman, kartu riwayat
// imunisasi sebelum posyandu, dan kartu laporan orang tua.
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
const bayanganKartuBidan = AppColors.bayanganKartu;

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

// ---------------------------------------------------------------------------
// RANGKA HALAMAN CATAT & EDIT PEMERIKSAAN
// ---------------------------------------------------------------------------
mixin _KartuPemeriksaan<T extends StatefulWidget>
    on _FormPemeriksaan<T>, _FormSuplemen<T>, _FormImunisasi<T>, _FormKpsp<T> {
  Widget _isi() {
    final d = _detail!;
    final balita = d['balita'] is Map ? Map<String, dynamic>.from(d['balita'] as Map) : <String, dynamic>{};
    final ukur = d['pengukuran'] is Map ? Map<String, dynamic>.from(d['pengukuran'] as Map) : <String, dynamic>{};
    final prev = d['pengukuran_sebelumnya'] is Map ? Map<String, dynamic>.from(d['pengukuran_sebelumnya'] as Map) : null;

    final usia = _usiaBulan;
    final lahirBalita = _lahir;
    final usiaTeks = lahirBalita != null
        ? usiaDariLahir(lahirBalita, DateTime.now())
        : (usia >= 12 ? '${usia ~/ 12} tahun ${usia % 12} bulan' : '$usia bulan');
    final jk = balita['jenis_kelamin']?.toString() == 'P' ? 'Perempuan' : 'Laki-laki';
    final peringatan = ukur['peringatan_validasi']?.toString() ?? '';
    final penilaian = PenilaianTimbang.dari(d['penilaian']);
    final balitaId = balita['id']?.toString() ?? '';
    final nama = balita['nama']?.toString() ?? '-';
    final mulaiNanti = _mulaiNanti;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (mulaiNanti != null) _bannerBelumMulai(mulaiNanti),
        if (_jadwalSelesai) _bannerJadwalSelesai(),
        kartuBidan(
          judul: nama,
          kanan: 'Antrean $nomor',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              barisInfoBidan('Jenis Kelamin', jk),
              barisInfoBidan('Umur', usiaTeks),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: kotakUkurBidan(_num(ukur['bb_kg']), 'BB (kg)')),
                  const SizedBox(width: 6),
                  Expanded(child: kotakUkurBidan(_num(ukur['tb_cm']), 'TB (cm)')),
                  const SizedBox(width: 6),
                  Expanded(child: kotakUkurBidan(_num(ukur['lingkar_kepala_cm']), 'LK (cm)')),
                  const SizedBox(width: 6),
                  Expanded(child: kotakUkurBidan(_num(ukur['lila_cm']), 'LiLA (cm)')),
                ],
              ),
              if (penilaian != null) ...[
                const SizedBox(height: 10),
                KotakPenilaian(p: penilaian),
              ],
              const SizedBox(height: 10),
              if (prev != null)
                barisInfoBidan('Sebelumnya',
                    'BB ${_num(prev['bb_kg'])} kg · TB ${_num(prev['tb_cm'])} cm'),
              if ((ukur['keluhan']?.toString() ?? '').isNotEmpty)
                barisInfoBidan('Keluhan (kader)', '${ukur['keluhan']}'),
              if ((ukur['catatan']?.toString() ?? '').isNotEmpty)
                barisInfoBidan('Catatan kader', '${ukur['catatan']}'),
              if (ukur['sedang_sakit'] == true)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Balita sedang sakit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.merah)),
                ),
              if (peringatan.isNotEmpty) ...[
                const SizedBox(height: 8),
                _info(peringatan, ikon: Icons.warning_amber_rounded, bg: AppColors.merahMuda, fg: AppColors.merah),
              ],
              if (balitaId.isNotEmpty) ...[
                const SizedBox(height: 6),
                tombolGarisBidan(
                  'Riwayat Imunisasi',
                  ikon: Icons.vaccines_outlined,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BidanImunisasiBalitaPage(balitaId: balitaId, namaBalita: nama, usia: usiaTeks),
                      ),
                    );
                    _muat();
                  },
                ),
              ],
            ],
          ),
        ),
        _kartuLaporanOrtu(),
        if (ukur.isNotEmpty)
          kartuBidan(
            judul: 'Status Gizi',
            child: KotakStatusGizi(d['status_gizi']),
          ),
        kartuBidan(
          judul: 'Hasil Pemeriksaan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Keluhan balita tampil di kartu pengukuran (diisi kader saat pendataan).
              // Disimpan di kolom yang sama (catatan_evaluasi & saran_gizi), hanya label yang berubah.
              _teks(_catatanOrtu, 'Hasil pemeriksaan',
                  baris: 3,
                  hint: 'Mis. balita demam sehingga imunisasi ditunda',
                  ikon: Icons.fact_check_outlined),
              _teks(_saranGizi, 'Catatan untuk orang tua', baris: 3, ikon: Icons.note_alt_outlined),
            ],
          ),
        ),
        // Urutan pendataan bidan: pemeriksaan -> KPSP -> imunisasi -> suplemen.
        _kartuKpsp(),
        // Kunjungan pertama balita: riwayat imunisasi sebelum posyandu ditanyakan
        // lebih dulu, karena menentukan imunisasi mana yang boleh diberikan hari ini.
        if (!_riwayatOk) _kartuRiwayat(),
        _kartuImunisasi(),
        _kartuSuplemen(),
        const SizedBox(height: 8),
      ],
    );
  }


  // -------------------------------------------------------------------------
  // LAPORAN ORANG TUA SETELAH IMUNISASI (tampil di atas form pemeriksaan)
  // Hanya muncul bila orang tua melapor; bila tidak, balita dianggap normal.
  // -------------------------------------------------------------------------
  Widget _kartuLaporanOrtu() {
    final daftar = _laporanOrtu;
    if (daftar.isEmpty) return const SizedBox.shrink();

    return kartuBidan(
      judul: 'Laporan Orang Tua Setelah Imunisasi',
      kanan: '${daftar.length} laporan',
      warnaKanan: AppColors.merah,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info('Orang tua melaporkan reaksi setelah imunisasi pada kunjungan sebelumnya. '
              'Tanyakan keadaan balita sekarang dan catat tindak lanjutnya.',
              ikon: Icons.report_gmailerrorred_outlined, bg: AppColors.merahMuda, fg: AppColors.merah),
          for (final r in daftar) _barisLaporanOrtu(r),
        ],
      ),
    );
  }

  Widget _barisLaporanOrtu(RiwayatImunisasi r) {
    final tglImunisasi = r.tanggal == null ? '' : formatTanggal(r.tanggal!);
    final tglLapor = r.kipiDilaporkanPada == null ? '' : formatTanggal(r.kipiDilaporkanPada!);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.merah.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.namaDosis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, color: _teksGelap)),
          if (tglImunisasi.isNotEmpty || tglLapor.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (tglImunisasi.isNotEmpty) 'Diimunisasi $tglImunisasi',
                  if (tglLapor.isNotEmpty) 'dilaporkan $tglLapor',
                ].join(' · '),
                style: const TextStyle(fontSize: 15.5, color: AppColors.teksRedup),
              ),
            ),
          const SizedBox(height: 6),
          Text(r.reaksiKipi, style: const TextStyle(fontSize: 16.5, height: 1.35, color: _teksGelap)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _prosesRiwayat ? null : () => _isiTindakLanjut(r),
              icon: const Icon(Icons.edit_note_outlined, size: 20),
              label: const Text('Isi tindak lanjut'),
            ),
          ),
        ],
      ),
    );
  }
}