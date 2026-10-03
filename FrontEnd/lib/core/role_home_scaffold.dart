import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Kerangka navigasi bawah 3 tombol: Beranda | Fungsi Utama | Akun.
class RoleNavScaffold extends StatefulWidget {
  final List<Widget> pages;
  final List<BottomNavigationBarItem> navItems;

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
      body: IndexedStack(index: _currentIndex, children: widget.pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -1)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.hijau,
          unselectedItemColor: AppColors.teksRedup,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _currentIndex = index),
          items: widget.navItems,
        ),
      ),
    );
  }
}