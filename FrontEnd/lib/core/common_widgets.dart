import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/auth/auth_provider.dart';
import 'app_colors.dart';
import 'notifikasi_page.dart';
import 'notifikasi_service.dart';

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
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const _namaBulanSingkat = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatTanggal(DateTime d) =>
    '${d.day} ${_namaBulan[d.month - 1]} ${d.year}';

String formatJam(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}.'
    '${d.minute.toString().padLeft(2, '0')}';

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
// Kerangka halaman home
// ---------------------------------------------------------------------------

const _hijauTua = Color(0xFF0B3D2E);
const _hijauGelap = Color(0xFF14634A);
const _hijauAksen = Color(0xFF1F7A5C);
const _headerTeksTerang = Color(0xFFBFF3DE);
const _oranye2 = Color(0xFFF97316);
const _headerAwal = Color(0xFF0E7A55);
const _headerTengah = Color(0xFF13705F);
const _headerAkhir = Color(0xFF0F5F5C);
const _cincinAvatar = Color(0xFF7DD3FC);
const _isiAvatar = Color(0xFFE6FBF4);

class HomeShell extends StatelessWidget {
  final String peran;
  final String lokasi;

  /// Tidak dipakai lagi; jumlah notifikasi diambil dari server.
  final int notif;
  final List<Widget> children;

  const HomeShell({
    super.key,
    required this.peran,
    required this.lokasi,
    required this.children,
    this.notif = 0,
  });

  void _bukaNotifikasi(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotifikasiPage()),
    );
  }

  Future<void> _keluar(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await NotifikasiService.instance.sebelumLogout();
    auth.logout();
  }

  /// Inisial dua huruf dari nama, mis. "Sara Rumapea" -> "SR".
  String _inisial(String nama) {
    final kata = nama.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (kata.isEmpty) return '?';
    if (kata.length == 1) {
      return kata.first.length >= 2
          ? kata.first.substring(0, 2).toUpperCase()
          : kata.first.toUpperCase();
    }
    return (kata[0][0] + kata[1][0]).toUpperCase();
  }

  Widget _tombolBulat({required Widget child}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _lonceng(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotifikasiService.instance.belumDibaca,
      builder: (context, jumlah, _) => Tooltip(
        message: jumlah > 0 ? '$jumlah notifikasi belum dibaca' : 'Notifikasi',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _bukaNotifikasi(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _tombolBulat(
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              if (jumlah > 0)
                Positioned(
                  right: 7,
                  top: 6,
                  child: IgnorePointer(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _oranye2,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.6),
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

  Widget _avatar(BuildContext context, String nama) {
    return PopupMenuButton<String>(
      tooltip: 'Akun',
      onSelected: (v) {
        if (v == 'keluar') _keluar(context);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            nama.isEmpty ? 'Pengguna' : nama,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const PopupMenuItem(
          value: 'keluar',
          child: Text('Keluar'),
        ),
      ],
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _cincinAvatar,
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _isiAvatar,
          ),
          alignment: Alignment.center,
          child: Text(
            _inisial(nama),
            style: const TextStyle(
              color: _hijauTua,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Image.asset(
        'logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.monitor_heart_outlined,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String nama) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_headerAwal, _headerTengah, _headerAkhir],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33064E3B),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        child: Stack(
          children: [
            // Kilau lembut di kiri atas dan kanan bawah
            Positioned(
              left: -60,
              top: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x40A7F3D0), Color(0x00A7F3D0)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -50,
              bottom: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x3367E8F9), Color(0x0067E8F9)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, topInset + 14, 16, 26),
              child: Row(
                children: [
                  _logo(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Posyandu Care',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: _headerTeksTerang,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                lokasi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: _headerTeksTerang,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _lonceng(context),
                  const SizedBox(width: 10),
                  _avatar(context, nama),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final nama = (user?['nama'] ?? '').toString();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.latar,
        body: Column(
          children: [
            _header(context, nama),
            Expanded(
              child: SafeArea(
                top: false,
                child: RefreshIndicator(
                  onRefresh: NotifikasiService.instance.perbaruiJumlah,
                  notificationPredicate: (n) => n.depth == 0,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    children: children,
                  ),
                ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    Icon(icon, size: 20, color: _hijauGelap),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _hijauTua,
                      ),
                    ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            nilai,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.teksRedup,
            ),
          ),
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final teks = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    );
    final ikon = icon == null ? null : Icon(icon, size: 17);

    if (filled) {
      final gaya = ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: shape,
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      );

      return ikon == null
          ? ElevatedButton(
              style: gaya,
              onPressed: onPressed,
              child: teks,
            )
          : ElevatedButton.icon(
              style: gaya,
              onPressed: onPressed,
              icon: ikon,
              label: teks,
            );
    }

    final gaya = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color),
      shape: shape,
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 12,
      ),
    );

    return ikon == null
        ? OutlinedButton(
            style: gaya,
            onPressed: onPressed,
            child: teks,
          )
        : OutlinedButton.icon(
            style: gaya,
            onPressed: onPressed,
            icon: ikon,
            label: teks,
          );
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
    final bg = online ? const Color(0xFFE3F6EC) : AppColors.kuningMuda;
    final fg = online ? _hijauGelap : AppColors.kuning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: online ? const Color(0xFFBFE5D0) : const Color(0xFFF3DFA8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'Mode Online Terhubung' : 'Mode Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: fg,
                  ),
                ),
                Text(
                  '$tertunda data belum terkirim · '
                  'sinkron terakhir $sinkronTerakhir',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (onSinkron != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hijauGelap,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: sedangSinkron ? null : onSinkron,
              icon: sedangSinkron
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync, size: 16),
              label: Text(
                sedangSinkron ? 'Proses' : 'Sinkron',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
    this.warna = _hijauAksen,
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
                  Text(
                    nilai[i].toInt().toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: tinggi * nilai[i] / maks,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: warna,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label[i],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.teksRedup,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}