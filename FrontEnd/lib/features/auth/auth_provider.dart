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

  Future<void> login(String identifier, String pin) async {
    loading = true;
    notifyListeners();
    try {
      user = await _svc.login(identifier, pin);
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