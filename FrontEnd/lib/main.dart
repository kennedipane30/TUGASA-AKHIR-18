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
import 'features/auth/ubah_pin_page.dart';

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

// Gaya teks seluruh aplikasi: font bawaan HP, ketebalan normal,
// ukuran mudah dibaca, dan jarak antarhuruf sedikit renggang.
const _warnaTeks = Color(0xFF1F2937);

TextTheme _gayaTeks(TextTheme t) {
  TextStyle? atur(TextStyle? s, double ukuran, FontWeight tebal) => s?.copyWith(
        fontSize: ukuran,
        fontWeight: tebal,
        letterSpacing: 0.3,
        height: 1.4,
      );

  return t
      .copyWith(
        headlineSmall: atur(t.headlineSmall, 23, FontWeight.w600),
        titleLarge: atur(t.titleLarge, 21, FontWeight.w600),
        titleMedium: atur(t.titleMedium, 17, FontWeight.w500),
        titleSmall: atur(t.titleSmall, 16, FontWeight.w500),
        bodyLarge: atur(t.bodyLarge, 17, FontWeight.w400),
        bodyMedium: atur(t.bodyMedium, 16, FontWeight.w400),
        bodySmall: atur(t.bodySmall, 14, FontWeight.w400),
        labelLarge: atur(t.labelLarge, 16, FontWeight.w600),
        labelMedium: atur(t.labelMedium, 14, FontWeight.w500),
        labelSmall: atur(t.labelSmall, 13, FontWeight.w500),
      )
      .apply(bodyColor: _warnaTeks, displayColor: _warnaTeks);
}

ThemeData _temaAplikasi() {
  final dasar = ThemeData(
    colorSchemeSeed: Colors.teal,
    useMaterial3: true,
  );
  return dasar.copyWith(
    textTheme: _gayaTeks(dasar.textTheme),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Hanya orang tua yang PIN-nya direset petugas wajib mengganti PIN dulu.
    // Sekretaris, bidan, dan kader langsung masuk ke beranda.
    final wajibGanti =
        auth.user != null && auth.role == 'orang_tua' && auth.wajibGantiPin;

    final sesiAktif = auth.initialized &&
        auth.user != null &&
        _roleDikenal.contains(auth.role);

    Widget home;

    if (!auth.initialized) {
      home = const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (wajibGanti) {
      home = const UbahPinPage(wajib: true);
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
      theme: _temaAplikasi(),
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