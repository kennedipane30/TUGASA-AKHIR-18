import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/Admin/admin_home.dart';
import 'features/Bidan/bidan_home.dart';
import 'features/Kader/kader_home.dart';
import 'features/OrangTua/orangtua_home.dart';
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
          home = const AdminHome();
          break;
        case 'bidan':
          home = const BidanHome();
          break;
        case 'kader':
          home = const KaderHome();
          break;
        case 'orang_tua':
          home = const OrangTuaHome();
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