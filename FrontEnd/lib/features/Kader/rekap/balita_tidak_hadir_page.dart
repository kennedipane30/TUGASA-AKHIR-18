import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/pages/rekap/rekap_posyandu_page.dart';

/// Kader: daftar balita sasaran yang tidak hadir (S − D) untuk ditindaklanjuti.
class KaderTidakHadirPage extends StatelessWidget {
  const KaderTidakHadirPage({super.key});

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
            headerRekap(context, 'Balita Tidak Hadir'),
            const Expanded(child: TidakHadirView(prefix: '/kader')),
          ],
        ),
      ),
    );
  }
}