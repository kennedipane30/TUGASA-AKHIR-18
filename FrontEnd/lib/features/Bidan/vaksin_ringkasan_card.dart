import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';

/// Kartu pintasan fitur vaksin di halaman home. [tujuan] adalah halaman yang dibuka.
class VaksinRingkasanCard extends StatelessWidget {
  final String deskripsi;
  final Widget tujuan;

  const VaksinRingkasanCard({
    super.key,
    required this.deskripsi,
    required this.tujuan,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Vaksin Anak',
      icon: Icons.vaccines_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(deskripsi,
              style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: AppButton('Lihat Rencana & Riwayat Vaksin',
                icon: Icons.event_available_outlined,
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => tujuan))),
          ),
        ],
      ),
    );
  }
}