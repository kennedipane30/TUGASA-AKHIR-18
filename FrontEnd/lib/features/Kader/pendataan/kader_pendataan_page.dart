import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

class KaderPendataanPage extends StatelessWidget {
  const KaderPendataanPage({super.key});

  Widget _aksi(BuildContext context, IconData icon, String label, String fitur) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => soon(context, fitur),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.hijauMuda,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.hijau, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // DATA CONTOH. Ganti dengan data dari database lokal perangkat kader.
    const riwayat = [
      ('Rayyan Al-Fatih', 'BB 11.2 · TB 80.0 · LK 47.0 · LiLA 14.5', 'Tersimpan di perangkat'),
      ('Annisa Zahra', 'BB 12.0 · TB 84.5 · LK 47.5 · LiLA 15.0', 'Tersinkron'),
      ('Dimas Pratama', 'BB 13.1 · TB 88.0 · LK 48.2 · LiLA 15.4', 'Terverifikasi'),
    ];

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Pendataan', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            readOnly: true,
            onTap: () => soon(context, 'Pencarian anak'),
            decoration: InputDecoration(
              hintText: 'Cari nama atau NIK balita',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Mulai Pendataan',
            icon: Icons.edit_note,
            child: Column(
              children: [
                Row(
                  children: [
                    _aksi(context, Icons.qr_code_scanner, 'Scan QR\nCheck-in', 'Pemindai QR'),
                    const SizedBox(width: 8),
                    _aksi(context, Icons.straighten, 'Ukur Data\nBB TB LK LiLA',
                        'Form pengukuran'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _aksi(context, Icons.directions_walk, 'Check-in\nWalk-in',
                        'Check-in walk-in'),
                    const SizedBox(width: 8),
                    _aksi(context, Icons.person_add_alt_1, 'Daftar\nBalita Baru',
                        'Pendataan balita baru'),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Riwayat Pendataan Hari Ini',
            icon: Icons.history,
            trailing: Pill('${riwayat.length} data', bg: AppColors.biruMuda, fg: AppColors.biru),
            child: Column(
              children: [
                for (final r in riwayat)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.$1,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    subtitle: Text(r.$2, style: const TextStyle(fontSize: 11.5)),
                    trailing: Pill(r.$3,
                        bg: r.$3 == 'Terverifikasi'
                            ? AppColors.hijauMuda
                            : r.$3 == 'Tersinkron'
                                ? AppColors.biruMuda
                                : AppColors.kuningMuda,
                        fg: r.$3 == 'Terverifikasi'
                            ? AppColors.hijau
                            : r.$3 == 'Tersinkron'
                                ? AppColors.biru
                                : AppColors.kuning),
                    onTap: () => soon(context, 'Detail pendataan'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}