// lib/features/akun/akun_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/utils/posyandu.dart';
import '../auth/auth_provider.dart';
import '../auth/ubah_pin_page.dart';

const Color _hijauHeader = Color(0xFF065F46);

class AkunPage extends StatelessWidget {
  const AkunPage({super.key});

  String _labelPeran(String? role) => switch (role) {
        'sekretaris' => 'Sekretaris',
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
        content: const Text(
          'Data yang belum tersinkron tetap tersimpan di perangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (ya == true && context.mounted) {
      context.read<AuthProvider>().logout();
    }
  }

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
  // Tanpa tombol kembali, sama seperti sebelumnya (halaman tab).
  // -------------------------------------------------------------------------
  Widget _header() {
    return Container(
      width: double.infinity,
      color: _hijauHeader,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: _judulTebal('Akun'),
            ),
          ),
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nama = (auth.user?['nama'] ?? 'Pengguna').toString();
    final inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';
    final pos = (auth.user?['posyandu'] ?? '').toString();

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
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.hijau,
                          child: Text(
                            inisial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Pill(_labelPeran(auth.role)),
                                  if (auth.role != null)
                                    Pill(
                                      pos.isEmpty
                                          ? 'Posyandu belum dipilih'
                                          : 'Posyandu ${labelPosyandu(pos)}',
                                      bg: AppColors.biruMuda,
                                      fg: AppColors.biru,
                                      icon: Icons.place_outlined,
                                    ),
                                ],
                              ),
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
                          leading: const Icon(
                            Icons.person_outline,
                            color: AppColors.hijau,
                          ),
                          title: const Text(
                            'Profil Saya',
                            style: TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => soon(context, 'Profil'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.pin_outlined,
                            color: AppColors.hijau,
                          ),
                          title: const Text(
                            'Ubah PIN',
                            style: TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UbahPinPage(),
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.notifications_none,
                            color: AppColors.hijau,
                          ),
                          title: const Text(
                            'Notifikasi',
                            style: TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => soon(context, 'Pengaturan notifikasi'),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    'Keluar',
                    icon: Icons.logout,
                    filled: false,
                    color: AppColors.merah,
                    onPressed: () => _keluar(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}