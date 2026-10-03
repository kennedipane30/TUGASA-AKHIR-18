import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/role_home_scaffold.dart';
import 'features/Admin/admin_home.dart';
import 'features/Admin/admin_kelola_akun_page.dart';
import 'features/Bidan/bidan_hasil_pendataan_page.dart';
import 'features/Bidan/bidan_home.dart';
import 'features/Kader/kader_home.dart';
import 'features/Kader/kader_pendataan_page.dart';
import 'features/OrangTua/orangtua_grafik_page.dart';
import 'features/OrangTua/orangtua_home.dart';
import 'features/akun/akun_page.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..restoreSession(),
      child: const MyApp(),
    ),
  );
}

Widget _nav({
  required Widget beranda,
  required Widget tengah,
  required String labelTengah,
  required IconData ikonTengah,
  required IconData ikonTengahAktif,
}) {
  return RoleNavScaffold(
    pages: [beranda, tengah, const AkunPage()],
    navItems: [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Beranda',
      ),
      BottomNavigationBarItem(
        icon: Icon(ikonTengah),
        activeIcon: Icon(ikonTengahAktif),
        label: labelTengah,
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Akun',
      ),
    ],
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    Widget home;
    if (!auth.initialized) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else {
      switch (auth.role) {
        case 'admin':
          home = _nav(
            beranda: const AdminHome(),
            tengah: const AdminKelolaAkunPage(),
            labelTengah: 'Kelola Akun',
            ikonTengah: Icons.manage_accounts_outlined,
            ikonTengahAktif: Icons.manage_accounts,
          );
          break;
        case 'bidan':
          home = _nav(
            beranda: const BidanHome(),
            tengah: const BidanHasilPendataanPage(),
            labelTengah: 'Hasil Pendataan',
            ikonTengah: Icons.fact_check_outlined,
            ikonTengahAktif: Icons.fact_check,
          );
          break;
        case 'kader':
          home = _nav(
            beranda: const KaderHome(),
            tengah: const KaderPendataanPage(),
            labelTengah: 'Pendataan',
            ikonTengah: Icons.edit_note_outlined,
            ikonTengahAktif: Icons.edit_note,
          );
          break;
        case 'orang_tua':
          home = _nav(
            beranda: const OrangTuaHome(),
            tengah: const OrangTuaGrafikPage(),
            labelTengah: 'Grafik Perkembangan',
            ikonTengah: Icons.show_chart,
            ikonTengahAktif: Icons.stacked_line_chart,
          );
          break;
        default:
          home = const LoginPage();
      }
    }

    return MaterialApp(
      title: 'Posyandu',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: home,
    );
  }
}