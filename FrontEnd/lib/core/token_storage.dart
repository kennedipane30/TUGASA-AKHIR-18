import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _s = FlutterSecureStorage();
  static Future<void> save(String t) => _s.write(key: 'token', value: t);
  static Future<String?> read() => _s.read(key: 'token');
  static Future<void> clear() => _s.delete(key: 'token');
}