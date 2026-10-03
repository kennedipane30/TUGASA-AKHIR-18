import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/auth_provider.dart';
import 'app_colors.dart';

// ---------------------------------------------------------------------------
// Fungsi bantu
// ---------------------------------------------------------------------------

/// Pesan sementara untuk fitur yang belum dibuat.
void soon(BuildContext context, String fitur) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('$fitur akan tersedia pada tahap berikutnya')),
    );
}

const _namaBulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _namaBulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String formatTanggal(DateTime d) => '${d.day} ${_namaBulan[d.month - 1]} ${d.year}';
String formatJam(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';
String bulanSingkat(DateTime d) => _namaBulanSingkat[d.month - 1];

/// Tingkat status gizi: hijau (baik), kuning (waspada), merah (berisiko).
enum Gizi { baik, waspada, risiko }

Color giziFg(Gizi g) => switch (g) {
      Gizi.baik => AppColors.hijau,
      Gizi.waspada => AppColors.kuning,
      Gizi.risiko => AppColors.merah,
    };

Color giziBg(Gizi g) => switch (g) {
      Gizi.baik => AppColors.hijauMuda,
      Gizi.waspada => AppColors.kuningMuda,
      Gizi.risiko => AppColors.merahMuda,
    };

// ---------------------------------------------------------------------------
// Kerangka halaman home (header + isi yang bisa di-scroll)
// ---------------------------------------------------------------------------

class HomeShell extends StatelessWidget {
  final String peran;
  final String lokasi;
  final int notif;
  final List<Widget> children;

  const HomeShell({
    super.key,
    required this.peran,
    required this.lokasi,
    required this.children,
    this.notif = 0,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final nama = (user?['nama'] ?? '').toString();
    final inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.latar,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.hijau,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.child_care, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Posyandu Sehat',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.hijau)),
                        Text('Beranda $peran',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(lokasi,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.teksRedup)),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifikasi',
                        icon: const Icon(Icons.notifications_none),
                        onPressed: () => soon(context, 'Daftar notifikasi'),
                      ),
                      if (notif > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.merah,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$notif',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Akun',
                    onSelected: (v) {
                      if (v == 'keluar') context.read<AuthProvider>().logout();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(nama.isEmpty ? 'Pengguna' : nama,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const PopupMenuItem(value: 'keluar', child: Text('Keluar')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.hijau,
                        child: Text(inisial,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Komponen kecil
// ---------------------------------------------------------------------------

class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final Color color;

  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: AppColors.hijau),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(title!,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  const Pill(
    this.text, {
    super.key,
    this.bg = AppColors.hijauMuda,
    this.fg = AppColors.hijau,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Kotak angka ringkas (misalnya Terdaftar 42).
class StatBox extends StatelessWidget {
  final String nilai;
  final String label;
  final Color bg;
  final Color fg;

  const StatBox({
    super.key,
    required this.nilai,
    required this.label,
    this.bg = AppColors.isiField,
    this.fg = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(nilai,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
        ],
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final Color color;

  const AppButton(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.filled = true,
    this.color = AppColors.hijau,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final teks = Text(label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13));
    final ikon = icon == null ? null : Icon(icon, size: 17);

    if (filled) {
      final gaya = ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: shape,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      );
      return ikon == null
          ? ElevatedButton(style: gaya, onPressed: onPressed, child: teks)
          : ElevatedButton.icon(
              style: gaya, onPressed: onPressed, icon: ikon, label: teks);
    }
    final gaya = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color),
      shape: shape,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
    return ikon == null
        ? OutlinedButton(style: gaya, onPressed: onPressed, child: teks)
        : OutlinedButton.icon(
            style: gaya, onPressed: onPressed, icon: ikon, label: teks);
  }
}

/// Indikator status online/offline, data tertunda, dan sinkron terakhir.
class SyncStrip extends StatelessWidget {
  final bool online;
  final int tertunda;
  final String sinkronTerakhir;
  final bool sedangSinkron;
  final VoidCallback? onSinkron;

  const SyncStrip({
    super.key,
    required this.online,
    required this.tertunda,
    required this.sinkronTerakhir,
    this.sedangSinkron = false,
    this.onSinkron,
  });

  @override
  Widget build(BuildContext context) {
    final bg = online ? AppColors.hijauMuda : AppColors.kuningMuda;
    final fg = online ? AppColors.hijau : AppColors.kuning;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(online ? 'Mode Online Terhubung' : 'Mode Offline',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg)),
                Text('$tertunda data belum terkirim · sinkron terakhir $sinkronTerakhir',
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          if (onSinkron != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hijau,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: sedangSinkron ? null : onSinkron,
              icon: sedangSinkron
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync, size: 16),
              label: Text(sedangSinkron ? 'Proses' : 'Sinkron',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// Grafik batang sederhana tanpa package tambahan.
class MiniBars extends StatelessWidget {
  final List<double> nilai;
  final List<String> label;
  final double tinggi;
  final Color warna;

  const MiniBars({
    super.key,
    required this.nilai,
    required this.label,
    this.tinggi = 90,
    this.warna = AppColors.hijau,
  });

  @override
  Widget build(BuildContext context) {
    final maks = nilai.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: tinggi + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < nilai.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(nilai[i].toInt().toString(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Container(
                    height: tinggi * nilai[i] / maks,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: warna,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(label[i],
                      style: const TextStyle(fontSize: 10, color: AppColors.teksRedup)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
