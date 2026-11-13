import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const _teal = Color(0xFF14A085);
const _tealMuda = Color(0xFFDDF4EF);
const _abu = Color(0xFF7C8796);

const double _ukuranIkon = 27;

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
        ikonAktif: Icon(ikonAktif, size: _ukuranIkon, color: _teal),
      );
}

/// Ikon aktif "Grafik": kotak teal dengan panah naik putih.
class IkonGrafikAktif extends StatelessWidget {
  const IkonGrafikAktif({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Icon(Icons.trending_up_rounded, size: 19, color: Colors.white),
    );
  }
}

/// Ikon garis yang ditebalkan tanpa memperbesar ukurannya
/// (lapisan bayangan tipis di sekeliling garis).
class _IkonTebal extends StatelessWidget {
  final IconData ikon;
  final Color warna;
  final double ukuran;
  final double tebal;

  const _IkonTebal(
    this.ikon, {
    required this.warna,
    this.ukuran = _ukuranIkon,
    this.tebal = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      ikon,
      size: ukuran,
      color: warna,
      shadows: [
        Shadow(color: warna, offset: Offset(tebal, 0)),
        Shadow(color: warna, offset: Offset(-tebal, 0)),
        Shadow(color: warna, offset: Offset(0, tebal)),
        Shadow(color: warna, offset: Offset(0, -tebal)),
      ],
    );
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
      backgroundColor: AppColors.latar,
      body: IndexedStack(index: _currentIndex, children: widget.pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -1)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
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
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 60,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aktif ? _tealMuda : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: aktif
                    ? data.ikonAktif
                    : _IkonTebal(data.ikon, warna: _abu),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                    color: aktif ? _teal : _abu,
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