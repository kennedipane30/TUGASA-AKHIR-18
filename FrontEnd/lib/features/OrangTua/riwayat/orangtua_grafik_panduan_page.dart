// ===========================================================================
// FILE 2: orangtua_grafik_panduan_page.dart
// ===========================================================================
import 'package:flutter/material.dart';

const _latar = Color(0xFFF3F6FB);
const _teksGelap = Color(0xFF1E293B);
const _teksAbu = Color(0xFF64748B);
const _hijauTua = Color(0xFF065F46);
const _hijauHero = Color(0xFF0A5A43);

class OrangTuaGrafikPanduanPage extends StatelessWidget {
  const OrangTuaGrafikPanduanPage({super.key});

  Widget _kartu({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1E293B), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _badge(String teks, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(teks,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg)),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: titik, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(judul,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _teksGelap)),
              ),
              const SizedBox(width: 6),
              _badge(badge, badgeBg, badgeFg),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(isi,
                style: const TextStyle(
                    fontSize: 11.5, height: 1.45, color: _teksAbu)),
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
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
            child: Icon(ikon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(judul,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _teksGelap)),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      _badge(badge, const Color(0xFFFFE4E6), const Color(0xFFDC2626)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(isi,
                    style: const TextStyle(
                        fontSize: 11, height: 1.45, color: _teksAbu)),
              ],
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
                color: Color(0xFFE9EEF3), shape: BoxShape.circle),
            child: Text('$no',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _teksGelap)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _teksGelap)),
                const SizedBox(height: 3),
                Text(isi,
                    style: const TextStyle(
                        fontSize: 11.5, height: 1.45, color: _teksAbu)),
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Header
            Row(
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back, color: _teksGelap, size: 26),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Panduan Membaca Grafik',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: _teksGelap)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(46, 2, 0, 14),
              child: Text('Edukasi Tumbuh Kembang Posyandu',
                  style: TextStyle(fontSize: 12, color: _teksAbu)),
            ),

            // Hero
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _hijauHero,
                borderRadius: BorderRadius.circular(22),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      bottom: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF4ADE80),
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                const Text('Standar WHO & Kemenkes RI',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Memahami Kurva Pertumbuhan Anak',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          const Text(
                            'Grafik kurva pertumbuhan digunakan untuk menilai apakah perkembangan fisik anak sesuai dengan acuan populasi sehat internasional (Z-Score), disesuaikan berdasarkan usia dan jenis kelamin.',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12, height: 1.55),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Arti garis SD
            _kartu(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text('ARTI GARIS PITA STANDAR DEVIASI (SD)',
                            style: TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w800,
                                color: _teksAbu)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9F6E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Z-Score\nAcuan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9.5,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: _hijauTua)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFE9EEF3)),
                  const SizedBox(height: 6),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9F6E8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('LK',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _hijauTua)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Panduan Khusus: Lingkar Kepala',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: _teksGelap)),
                            Text('Pemantauan rutin usia 0 - 24 bulan',
                                style: TextStyle(fontSize: 11, color: _teksAbu)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pengukuran Lingkar Kepala (LK) sangat penting di 2 tahun pertama karena kehidupan kepala mencerminkan perkembangan volume otak dan penutupan ubun-ubun anak secara optimal.',
                    style: TextStyle(fontSize: 11.5, height: 1.5, color: _teksAbu),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LANGKAH TINDAKAN UNTUK ORANG TUA',
                      style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w800,
                          color: _teksAbu)),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFE9EEF3)),
                  const SizedBox(height: 8),
                  _langkah(1, 'Tetap Tenang & Hindari Self-Diagnosis',
                      'Posisi pita ukur yang miring atau gerakan bayi dapat memengaruhi milimeter hasil. Jangan langsung panik.'),
                  _langkah(2, 'Pantau Tren, Bukan Sekadar Satu Titik',
                      'Yang terpenting adalah garis pertumbuhan naik mengikuti pita kurva, bukan mendadak atau tiba-tiba menurun drastis.'),
                  _langkah(3, 'Konfirmasi Langsung ke Tenaga Kesehatan',
                      'Bawa buku KIA dan tunjukkan grafik riwayat aplikasi Posyandu Care pada Bidan Desa atau Dokter Puskesmas terdekat.'),
                ],
              ),
            ),

            // Tombol kembali
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hijauTua,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.chevron_left, size: 22),
                label: const Text('Kembali ke Grafik Anak',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Kementerian Kesehatan Republik Indonesia • Standar Baku Antropometri',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9.5, color: _teksAbu),
              ),
            ),
          ],
        ),
      ),
    );
  }
}