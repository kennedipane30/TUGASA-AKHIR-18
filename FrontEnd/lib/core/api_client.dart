import 'package:dio/dio.dart';
import 'token_storage.dart';

class ApiClient {
  // 10.0.2.2 = localhost laptop jika memakai emulator Android.
  // HP fisik: pakai IP laptop, misal http://192.168.1.10:8080/api/v1
  static const baseUrl = 'http://10.0.2.2:8080/api/v1';

  static final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
  ))
    ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      final t = await TokenStorage.read();
      if (t != null) o.headers['Authorization'] = 'Bearer $t';
      h.next(o);
    }));
}