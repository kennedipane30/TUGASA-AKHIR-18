import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import 'jadwal_page.dart';
import 'riwayat_jadwal_page.dart';

/// Garis tepi kartu halaman detail: hitam lembut (tidak mencolok).
const _garisDetail = Color(0xFFB8BEC6);

/// Detail satu jadwal yang sudah selesai (hanya dilihat).
class RiwayatJadwalDetailPage extends StatelessWidget {
  final RiwayatJadwal jadwal;

  const RiwayatJadwalDetailPage({super.key, required this.jadwal});

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      color: warnaHeaderJadwal,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: judulHeaderJadwal('Detail Riwayat'),
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

  Widget _baris(String label, String nilai) {
    const gaya =
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: teksGelapRiwayat);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 108, child: Text(label, style: gaya)),
        const Text(': ', style: gaya),
        Expanded(child: Text(nilai, style: gaya)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = jadwal;
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _garisDetail, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _baris('Hari/Tanggal', tglPanjangJadwal(j.tanggal)),
                        const SizedBox(height: 6),
                        _baris('Waktu', '${j.jam} WIB'),
                        const SizedBox(height: 6),
                        _baris('Lokasi', j.lokasi.isEmpty ? '-' : j.lokasi),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFEDF1EF)),
                        ),
                        _baris('Terdaftar', '${j.totalDaftar} anak'),
                        const SizedBox(height: 6),
                        _baris('Check-in', '${j.checkin} anak'),
                        const SizedBox(height: 6),
                        _baris('Tidak hadir', '${j.tidakDatang} anak'),
                        const SizedBox(height: 6),
                        _baris('Batal', '${j.batal} anak'),
                      ],
                    ),
                  ),
                  // Bagian detail lain (mis. daftar anak) dapat ditambahkan di sini.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}