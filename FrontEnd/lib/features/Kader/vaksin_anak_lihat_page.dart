import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../Bidan/vaksin_lihat_body.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: Text('Vaksin · $namaAnak', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Usia $usia',
                style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
          ),
        ),
      ),
      body: VaksinLihatBody(anakId: anakId),
    );
  }
}