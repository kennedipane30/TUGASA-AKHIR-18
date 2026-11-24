import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import 'vaksin_lihat_body.dart';

const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
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

/// Halaman vaksin (hanya lihat) untuk satu anak yang sudah dipilih.
/// Bidan: riwayat vaksin yang sudah diterima dan suplemen anak, serta pencatatan
/// vaksin yang diberikan di luar posyandu.
class BidanVaksinAnakPage extends StatelessWidget {
  final String anakId;
  final String namaAnak;
  final String usia;

  const BidanVaksinAnakPage({
    super.key,
    required this.anakId,
    required this.namaAnak,
    required this.usia,
  });

  // -------------------------------------------------------------------------
  // HEADER (polos, judul di tengah, tombol kembali di kiri)
  // -------------------------------------------------------------------------
  Widget _header(BuildContext context) {
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
                child: _judulTebal('Vaksin Anak'),
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

  // -------------------------------------------------------------------------
  // KARTU DATA ANAK: nama (kapital) di kiri, usia di kanan, garis aksen di bawah.
  // -------------------------------------------------------------------------
  Widget _kartuAnak() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
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
                      (namaAnak.isEmpty ? 'Anak' : namaAnak).toUpperCase(),
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
                  const SizedBox(width: 10),
                  Text(
                    usia.isEmpty ? '-' : usia,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: _teksGelap,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 3, color: _aksen),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                'Riwayat vaksin yang sudah diterima dan suplemen anak.',
                style: TextStyle(fontSize: 15.5, height: 1.35, color: Color(0xFF374151)),
              ),
            ),
          ],
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
            _header(context),
            _kartuAnak(),
            Expanded(child: VaksinLihatBody(anakId: anakId, bisaKelola: true, hanyaRiwayat: true)),
          ],
        ),
      ),
    );
  }
}