import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../Bidan/vaksin/vaksin_lihat_body.dart';

const _hijauHeader = Color(0xFF065F46);

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
class VaksinAnakLihatPage extends StatelessWidget {
  final String anakId;
  final String namaAnak;
  final String usia;

  const VaksinAnakLihatPage({
    super.key,
    required this.anakId,
    required this.namaAnak,
    required this.usia,
  });

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak orang tua: polos, judul di tengah)
  // Usia anak ditampilkan sebagai baris kecil di bawah judul.
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
              // Judul + usia di tengah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _judulTebal('Vaksin · $namaAnak'),
                    Text(
                      'Usia $usia',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              // Tombol kembali di kiri
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
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
            _header(context),
            Expanded(child: VaksinLihatBody(anakId: anakId)),
          ],
        ),
      ),
    );
  }
}