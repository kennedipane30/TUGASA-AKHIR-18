import 'package:flutter/material.dart';

import 'common_widgets.dart';

// ===========================================================================
// NAVIGASI BAWAH (sama untuk semua peran)
//
// Tiga tombol: Beranda | fungsi utama peran | Akun.
// Tombol aktif ditandai pil hijau muda di belakang ikonnya.
// ===========================================================================

const double _ukuranIkon = 22;

/// Satu tombol navigasi bawah.
class NavItemData {
  final String label;
  final IconData ikon;
  final Widget ikonAktif;

  const NavItemData({
    required this.label,
    required this.ikon,
    required this.ikonAktif,
  });

  /// Tombol dengan ikon aktif berupa ikon terisi biasa.
  factory NavItemData.ikon({
    required String label,
    required IconData ikon,
    required IconData ikonAktif,
  }) =>
      NavItemData(
        label: label,
        ikon: ikon,
        ikonAktif: Icon(ikonAktif, size: _ukuranIkon, color: warnaUtamaHome),
      );
}

/// Ikon aktif "Perkembangan": grafik garis tebal berwarna hijau utama.
class IkonGrafikAktif extends StatelessWidget {
  const IkonGrafikAktif({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.show_chart_rounded, size: _ukuranIkon, color: warnaUtamaHome);
  }
}

/// Kerangka navigasi bawah: Beranda | Fungsi Utama | Akun.
class RoleNavScaffold extends StatefulWidget {
  final List<Widget> pages;
  final List<NavItemData> navItems;

  const RoleNavScaffold({
    super.key,
    required this.pages,
    required this.navItems,
  }) : assert(pages.length == navItems.length, 'Pages dan NavItems harus berjumlah sama');

  @override
  State<RoleNavScaffold> createState() => _RoleNavScaffoldState();
}

class _RoleNavScaffoldState extends State<RoleNavScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: warnaLatarHome,
      body: IndexedStack(index: _currentIndex, children: widget.pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: warnaGarisHome.withValues(alpha: 0.6))),
          boxShadow: const [
            BoxShadow(color: Color(0x0F003828), blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                for (var i = 0; i < widget.navItems.length; i++)
                  Expanded(
                    child: _NavTombol(
                      data: widget.navItems[i],
                      aktif: i == _currentIndex,
                      onTap: () => setState(() => _currentIndex = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTombol extends StatelessWidget {
  final NavItemData data;
  final bool aktif;
  final VoidCallback onTap;

  const _NavTombol({
    required this.data,
    required this.aktif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: aktif,
      label: data.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pil hijau muda di belakang ikon tombol yang sedang dibuka.
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 64,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aktif ? warnaLembutHome : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: aktif
                    ? data.ikonAktif
                    : Icon(data.ikon, size: _ukuranIkon, color: warnaTeksVarianHome),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: aktif ? FontWeight.w600 : FontWeight.w500,
                    color: aktif ? warnaUtamaHome : warnaTeksVarianHome,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}