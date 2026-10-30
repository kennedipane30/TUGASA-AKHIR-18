import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/notifikasi_service.dart';
import 'core/role_home_scaffold.dart';
import 'features/Admin/admin_home.dart';
import 'features/Admin/akun/admin_kelola_akun_page.dart';
import 'features/Bidan/pendattan/bidan_hasil_pendataan_page.dart';
import 'features/Bidan/bidan_home.dart';
import 'features/Kader/kader_home.dart';
import 'features/Kader/pendataan/kader_pendataan_page.dart';
import 'features/OrangTua/riwayat/orangtua_grafik_page.dart';
import 'features/OrangTua/orangtua_home.dart';
import 'features/akun/akun_page.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_page.dart';
import 'features/auth/ubah_sandi_page.dart';

const _roleDikenal = {'sekretaris', 'bidan', 'kader', 'orang_tua'};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotifikasiService.instance.init();

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

    final wajibGanti = auth.user != null &&
        auth.role == 'orang_tua' &&
        auth.user!['must_change_password'] == true;

    final sesiAktif = auth.initialized &&
        auth.user != null &&
        _roleDikenal.contains(auth.role);

    Widget home;

    if (!auth.initialized) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (wajibGanti) {
      home = const UbahSandiPage();
    } else {
      switch (auth.role) {
        case 'sekretaris':
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
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: _PemantauSesi(
        aktif: sesiAktif,
        role: auth.role?.toString(),
        child: home,
      ),
    );
  }
}

/// Mendaftarkan / melepas token notifikasi saat login dan logout.
class _PemantauSesi extends StatefulWidget {
  final bool aktif;
  final String? role;
  final Widget child;

  const _PemantauSesi({
    required this.aktif,
    required this.role,
    required this.child,
  });

  @override
  State<_PemantauSesi> createState() => _PemantauSesiState();
}

class _PemantauSesiState extends State<_PemantauSesi> {
  @override
  void initState() {
    super.initState();
    if (widget.aktif) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotifikasiService.instance.setelahLogin(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _PemantauSesi old) {
    super.didUpdateWidget(old);
    if (old.aktif == widget.aktif && old.role == widget.role) return;

    final keluar = old.aktif && (!widget.aktif || old.role != widget.role);
    final masuk = widget.aktif;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final svc = NotifikasiService.instance;
      if (keluar) await svc.setelahLogout();
      if (masuk) await svc.setelahLogin();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}