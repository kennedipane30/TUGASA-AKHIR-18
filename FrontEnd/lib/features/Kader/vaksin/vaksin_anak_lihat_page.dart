import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../Bidan/vaksin/vaksin_lihat_body.dart';

const _hijauHeader = Color(0xFF0B6043);

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
        title: Text(
          'Vaksin · $namaAnak',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: _hijauHeader,
        surfaceTintColor: _hijauHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _hijauHeader,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Usia $usia',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
      body: VaksinLihatBody(anakId: anakId),
    );
  }
}