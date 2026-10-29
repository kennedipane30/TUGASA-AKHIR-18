import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import 'keluarga_common.dart';
import 'kartu_lengkapi_keluarga.dart';

class DataKeluargaPage extends StatelessWidget {
  const DataKeluargaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      body: Column(
        children: [
          const HeaderKeluarga(judul: 'Data Keluarga', sinkron: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: const [
                KartuLengkapiKeluarga(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}