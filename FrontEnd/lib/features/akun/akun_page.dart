import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../auth/auth_provider.dart';

class AkunPage extends StatelessWidget {
  const AkunPage({super.key});

  String _labelPeran(String? role) => switch (role) {
        'admin' => 'Admin',
        'bidan' => 'Bidan',
        'kader' => 'Kader',
        'orang_tua' => 'Orang Tua',
        _ => '-',
      };

  Future<void> _keluar(BuildContext context) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Data yang belum tersinkron tetap tersimpan di perangkat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ya == true && context.mounted) {
      context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nama = (auth.user?['nama'] ?? 'Pengguna').toString();
    final inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Akun', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.hijau,
                  child: Text(inisial,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nama,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Pill(_labelPeran(auth.role)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline, color: AppColors.hijau),
                  title: const Text('Profil Saya'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => soon(context, 'Profil'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline, color: AppColors.hijau),
                  title: const Text('Ubah Kata Sandi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => soon(context, 'Ubah kata sandi'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_none, color: AppColors.hijau),
                  title: const Text('Notifikasi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => soon(context, 'Pengaturan notifikasi'),
                ),
              ],
            ),
          ),
          AppButton('Keluar',
              icon: Icons.logout,
              filled: false,
              color: AppColors.merah,
              onPressed: () => _keluar(context)),
        ],
      ),
    );
  }
}