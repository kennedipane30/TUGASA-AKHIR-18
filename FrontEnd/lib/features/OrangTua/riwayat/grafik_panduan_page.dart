import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

// Warna tampilan: semuanya diambil dari AppColors agar seragam dengan
// halaman grafik dan halaman lain.
const _latar = AppColors.latar;
const _teksGelap = AppColors.teksGelap;
const _teksAbu = AppColors.teksAbu;
const _hijauTua = AppColors.hijauTua;
const _garis = AppColors.garis;
const _aksen = AppColors.aksen;
const _bayangan = AppColors.bayanganKartu;

/// Judul header (gaya teks sama dengan halaman lain).
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

class OrangTuaGrafikPanduanPage extends StatelessWidget {
  const OrangTuaGrafikPanduanPage({super.key});

  // Header hijau polos: tombol kembali di kiri, judul di tengah.
  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _hijauTua,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal('Panduan Membaca Grafik'),
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

  /// Kartu putih berbayang: kepala kapital + garis aksen, lalu isi.
  Widget _kartu({required String judul, String? kanan, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Column(
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
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: _teksGelap,
                    ),
                  ),
                ),
                if (kanan != null) ...[
                  const SizedBox(width: 10),
                  Text(kanan,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: _hijauTua)),
                ],
              ],
            ),
          ),
          Container(height: 3, color: _aksen),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  /// Keterangan berwarna (pengganti badge).
  Widget _badge(String teks, Color bg, Color fg) {
    return Text(
      teks,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
    );
  }

  Widget _garisSd({
    required Color titik,
    required String judul,
    required String badge,
    required Color badgeBg,
    required Color badgeFg,
    required String isi,
    required Color bg,
    required Color border,
  }) {
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
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: titik,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _teksGelap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: _badge(badge, badgeBg, badgeFg),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              isi,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.45,
                color: _teksAbu,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kondisiLk({
    required IconData ikon,
    required Color warna,
    required String judul,
    String? badge,
    required String isi,
    required Color bg,
    required Color border,
  }) {
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
          Text(
            judul,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: warna,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            _badge(
              badge,
              const Color(0xFFFFE4E6),
              const Color(0xFFDC2626),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            isi,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.45,
              color: _teksAbu,
            ),
          ),
        ],
      ),
    );
  }

  Widget _langkah(int no, String judul, String isi) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _hijauTua,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$no',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _teksGelap,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isi,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.45,
                    color: _teksAbu,
                  ),
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
    return Scaffold(
      backgroundColor: _latar,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  // Pengantar
                  _kartu(
                    judul: 'Memahami Kurva Pertumbuhan Anak',
                    child: const Text(
                      'Grafik kurva pertumbuhan digunakan untuk menilai apakah perkembangan fisik anak sesuai dengan acuan populasi sehat internasional (Z-Score), disesuaikan berdasarkan usia dan jenis kelamin.',
                      style: TextStyle(fontSize: 15.5, height: 1.5, color: _teksAbu),
                    ),
                  ),

                  // Arti garis SD
                  _kartu(
                    judul: 'Arti Garis Standar Deviasi (SD)',
                    kanan: 'Z-Score',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _garisSd(
                          titik: const Color(0xFF16A34A),
                          judul: 'Garis Hijau (Median 0)',
                          badge: 'Sangat Baik',
                          badgeBg: const Color(0xFFBBF7D0),
                          badgeFg: const Color(0xFF166534),
                          isi:
                              'Garis tengah ideal. Menandakan ukuran anak berada tepat di rata-rata acuan populasi anak sehat.',
                          bg: const Color(0xFFEBFBF1),
                          border: const Color(0xFFC9EFD8),
                        ),
                        _garisSd(
                          titik: const Color(0xFFF59E0B),
                          judul: 'Garis Oranye (+1 SD s/d -1 SD)',
                          badge: 'Batas Wajar',
                          badgeBg: const Color(0xFFFDE68A),
                          badgeFg: const Color(0xFF92400E),
                          isi:
                              'Variasi normal pertumbuhan anak. Pola pertumbuhan terus dipantau pada jadwal Posyandu bulanan.',
                          bg: const Color(0xFFFFFAEB),
                          border: const Color(0xFFFBE7B0),
                        ),
                        _garisSd(
                          titik: const Color(0xFFEA580C),
                          judul: 'Garis Oranye Tua/Merah (+2 SD s/d -2 SD)',
                          badge: 'Waspada',
                          badgeBg: const Color(0xFFFFD6B8),
                          badgeFg: const Color(0xFFC2410C),
                          isi:
                              'Ambang batas bawah atau batas atas normal. Memerlukan perhatian ekstra pada asupan gizi serta teknik ukur berkala.',
                          bg: const Color(0xFFFFF4EA),
                          border: const Color(0xFFFAD7B8),
                        ),
                        _garisSd(
                          titik: const Color(0xFF111827),
                          judul: 'Garis Hitam (> +3 SD atau < -3 SD)',
                          badge: 'Perlu Tindakan',
                          badgeBg: const Color(0xFFFFE4E6),
                          badgeFg: const Color(0xFFDC2626),
                          isi:
                              'Penyimpangan signifikan. Memerlukan konsultasi medis langsung dengan bidan/dokter spesialis anak di Puskesmas.',
                          bg: const Color(0xFFFFF1F2),
                          border: const Color(0xFFFAD0D5),
                        ),
                      ],
                    ),
                  ),

                  // Panduan khusus LK
                  _kartu(
                    judul: 'Panduan Khusus: Lingkar Kepala',
                    kanan: '0-24 bulan',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pengukuran Lingkar Kepala (LK) sangat penting di 2 tahun pertama karena kehidupan kepala mencerminkan perkembangan volume otak dan penutupan ubun-ubun anak secara optimal.',
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.5,
                            color: _teksAbu,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _kondisiLk(
                          ikon: Icons.check,
                          warna: const Color(0xFF16A34A),
                          judul: 'Normal (-2 SD sampai +2 SD)',
                          isi:
                              'Volume otak berkembang sesuai kurva ideal. Lanjutkan stimulasi sensorik dan ASI/MPASI bergizi.',
                          bg: const Color(0xFFEBFBF1),
                          border: const Color(0xFFC9EFD8),
                        ),
                        _kondisiLk(
                          ikon: Icons.priority_high,
                          warna: const Color(0xFFEF4444),
                          judul: 'Mikrosefali (< -2 SD)',
                          badge: 'Peringatan',
                          isi:
                              'Ukuran kepala berada di bawah standar usianya. Wajib diperiksa ulang oleh dokter anak untuk mengevaluasi perkembangan saraf dan nutrisi.',
                          bg: const Color(0xFFFFF1F2),
                          border: const Color(0xFFFAD0D5),
                        ),
                        _kondisiLk(
                          ikon: Icons.arrow_upward,
                          warna: const Color(0xFFF59E0B),
                          judul: 'Makrosefali (> +2 SD)',
                          isi:
                              'Ukuran kepala lebih besar dari rata-rata. Perlu dipastikan apakah faktor genetik keluarga atau akumulasi cairan intrakranial.',
                          bg: const Color(0xFFFFFAEB),
                          border: const Color(0xFFFBE7B0),
                        ),
                      ],
                    ),
                  ),

                  // Langkah tindakan
                  _kartu(
                    judul: 'Langkah Tindakan untuk Orang Tua',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _langkah(
                          1,
                          'Tetap Tenang & Hindari Self-Diagnosis',
                          'Posisi pita ukur yang miring atau gerakan bayi dapat memengaruhi milimeter hasil. Jangan langsung panik.',
                        ),
                        _langkah(
                          2,
                          'Pantau Tren, Bukan Sekadar Satu Titik',
                          'Yang terpenting adalah garis pertumbuhan naik mengikuti pita kurva, bukan mendadak atau tiba-tiba menurun drastis.',
                        ),
                        _langkah(
                          3,
                          'Konfirmasi Langsung ke Tenaga Kesehatan',
                          'Bawa buku KIA dan tunjukkan grafik riwayat aplikasi Posyandu Care pada Bidan Desa atau Dokter Puskesmas terdekat.',
                        ),
                      ],
                    ),
                  ),

                  // Tombol kembali
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hijauTua,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text(
                        'Kembali ke Grafik Anak',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Kementerian Kesehatan Republik Indonesia • Standar Baku Antropometri',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.5, color: _teksAbu),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}