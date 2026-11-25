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

  /// Memulihkan sesi dari token tersimpan.
  ///
  /// Apa pun hasilnya, [initialized] wajib menjadi true: selama masih false,
  /// main.dart menahan layar di CircularProgressIndicator. Maka pemanggilan
  /// dibatasi waktu dan dibungkus try/finally, supaya backend yang mati atau
  /// alamat yang salah berujung ke halaman login, bukan loading tanpa henti.
  Future<void> restoreSession() async {
    try {
      user = await _svc.me().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('restoreSession gagal: $e');
      user = null;
    } finally {
      initialized = true;
      notifyListeners();
    }
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