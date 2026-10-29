import 'package:dio/dio.dart';
import 'token_storage.dart';

class ApiClient {
  // HP fisik lewat Wi-Fi: pakai IP laptop (cek dengan ipconfig).

  static const baseUrl = 'http://10.49.228.127:8081/api/v1';
  //  static const baseUrl = 'http://10.0.2.2:8081/api/v1';

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