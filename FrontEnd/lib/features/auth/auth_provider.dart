import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final _svc = AuthService();

  Map<String, dynamic>? user;
  bool loading = false;
  bool initialized = false;

  String? get role => user?['role'];

  /// true bila PIN dibuat/direset petugas dan wajib diganti pemilik akun.
  bool get wajibGantiPin => user?['wajib_ganti_pin'] == true;

  Future<void> restoreSession() async {
    user = await _svc.me();
    initialized = true;
    notifyListeners();
  }

  /// [noHp]: format +62 (mis. +6281234567890).
  Future<void> login(String noHp, String pin) async {
    loading = true;
    notifyListeners();
    try {
      user = await _svc.login(noHp, pin);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _svc.logout();
    user = null;
    notifyListeners();
  }
}