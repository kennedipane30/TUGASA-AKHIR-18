import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/notifikasi_service.dart';
import 'core/role_home_scaffold.dart';
import 'features/Sekretaris/admin_home.dart';
import 'features/Sekretaris/akun/admin_kelola_akun_page.dart';
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

// Ikon navigasi (gaya: garis saat tidak aktif, terisi dengan latar pil saat aktif).
final _navBeranda = NavItemData.ikon(
  label: 'Beranda',
  ikon: Icons.add_home_outlined,
  ikonAktif: Icons.add_home,
);

final _navAkun = NavItemData.ikon(
  label: 'Akun',
  ikon: Icons.person_outline_rounded,
  ikonAktif: Icons.person_rounded,
);

Widget _nav({
  required Widget beranda,
  required Widget tengah,
  required NavItemData navTengah,
}) {
  return RoleNavScaffold(
    pages: [beranda, tengah, const AkunPage()],
    navItems: [_navBeranda, navTengah, _navAkun],
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
            navTengah: NavItemData.ikon(
              label: 'Kelola Akun',
              ikon: Icons.manage_accounts_outlined,
              ikonAktif: Icons.manage_accounts,
            ),
          );
          break;
        case 'bidan':
          home = _nav(
            beranda: const BidanHome(),
            tengah: const BidanHasilPendataanPage(),
            navTengah: NavItemData.ikon(
              label: 'Hasil Pendataan',
              ikon: Icons.assignment_turned_in_outlined,
              ikonAktif: Icons.assignment_turned_in,
            ),
          );
          break;
        case 'kader':
          home = _nav(
            beranda: const KaderHome(),
            tengah: const KaderPendataanPage(),
            navTengah: NavItemData.ikon(
              label: 'Pendataan',
              ikon: Icons.assignment_turned_in_outlined,
              ikonAktif: Icons.assignment_turned_in,
            ),
          );
          break;
        case 'orang_tua':
          home = _nav(
            beranda: const OrangTuaHome(),
            tengah: const OrangTuaGrafikPage(),
            navTengah: const NavItemData(
              label: 'Grafik Perkembangan',
              ikon: Icons.show_chart_rounded,
              ikonAktif: IkonGrafikAktif(),
            ),
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