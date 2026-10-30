import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'notifikasi_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> notifikasiLatarBelakang(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final Options _opsi = Options(receiveTimeout: const Duration(seconds: 15));

class NotifikasiItem {
  final String id;
  final String jenis;
  final String judul;
  final String isi;
  final String? objekId;
  final DateTime dibuat;
  bool sudahDibaca;

  NotifikasiItem({
    required this.id,
    required this.jenis,
    required this.judul,
    required this.isi,
    required this.objekId,
    required this.dibuat,
    required this.sudahDibaca,
  });

  factory NotifikasiItem.fromApi(Map<String, dynamic> j) {
    final t = DateTime.tryParse(j['created_at']?.toString() ?? '');
    return NotifikasiItem(
      id: j['id']?.toString() ?? '',
      jenis: j['jenis']?.toString() ?? '',
      judul: j['judul']?.toString() ?? '',
      isi: j['isi']?.toString() ?? '',
      objekId: j['objek_id']?.toString(),
      dibuat: (t ?? DateTime.now()).toLocal(),
      sudahDibaca: j['sudah_dibaca'] == true,
    );
  }
}

class NotifikasiService {
  NotifikasiService._();
  static final NotifikasiService instance = NotifikasiService._();

  static const AndroidNotificationChannel _kanal = AndroidNotificationChannel(
    'jadwal_posyandu',
    'Jadwal Posyandu',
    description: 'Pengingat jadwal posyandu dan pembukaan check-in',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _lokal = FlutterLocalNotificationsPlugin();

  /// Jumlah notifikasi belum dibaca (untuk lencana lonceng).
  final ValueNotifier<int> belumDibaca = ValueNotifier<int>(0);

  /// Bertambah setiap ada notifikasi baru (halaman daftar memuat ulang).
  final ValueNotifier<int> versi = ValueNotifier<int>(0);

  bool _siap = false;
  bool _firebaseSiap = false;
  bool _masuk = false;
  bool _bukaTertunda = false;
  String? _idTertunda;
  String? _token;
  Timer? _timer;
  StreamSubscription<String>? _subToken;
  StreamSubscription<RemoteMessage>? _subPesan;
  StreamSubscription<RemoteMessage>? _subBuka;

  // -------------------------------------------------------------------------
  // Inisialisasi
  // -------------------------------------------------------------------------
  Future<void> init() async {
    if (_siap) return;
    _siap = true;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(notifikasiLatarBelakang);
      _firebaseSiap = true;
    } catch (e) {
      debugPrint('notifikasi: Firebase gagal diinisialisasi: $e');
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _lokal.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (r) =>
            bukaHalaman(notifikasiId: r.payload),
      );
      await _lokal
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_kanal);

      final awalLokal = await _lokal.getNotificationAppLaunchDetails();
      if (awalLokal?.didNotificationLaunchApp == true) {
        _bukaTertunda = true;
        _idTertunda = awalLokal?.notificationResponse?.payload;
      }
    } catch (e) {
      debugPrint('notifikasi: notifikasi lokal gagal diinisialisasi: $e');
    }

    if (!_firebaseSiap) return;

    try {
      final fm = FirebaseMessaging.instance;
      await fm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _subPesan = FirebaseMessaging.onMessage.listen(_pesanDepan);
      _subBuka = FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => bukaHalaman(notifikasiId: m.data['notifikasi_id']?.toString()),
      );
      _subToken = fm.onTokenRefresh.listen((t) {
        _token = t;
        if (_masuk) _kirimToken(t);
      });

      final awal = await fm.getInitialMessage();
      if (awal != null) {
        _bukaTertunda = true;
        _idTertunda = awal.data['notifikasi_id']?.toString();
      }
    } catch (e) {
      debugPrint('notifikasi: FCM gagal diinisialisasi: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _subToken?.cancel();
    _subPesan?.cancel();
    _subBuka?.cancel();
  }

  // -------------------------------------------------------------------------
  // Sesi
  // -------------------------------------------------------------------------
  Future<void> setelahLogin() async {
    if (_masuk) return;
    _masuk = true;

    await perbaruiJumlah();
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => perbaruiJumlah(),
    );

    if (_firebaseSiap) {
      try {
        final fm = FirebaseMessaging.instance;
        await fm.requestPermission(alert: true, badge: true, sound: true);
        final t = await fm.getToken();
        if (t != null && t.isNotEmpty) {
          _token = t;
          await _kirimToken(t);
        }
      } catch (e) {
        debugPrint('notifikasi: gagal mengambil token FCM: $e');
      }
    }

    if (_bukaTertunda) {
      _bukaTertunda = false;
      final id = _idTertunda;
      _idTertunda = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => bukaHalaman(notifikasiId: id),
      );
    }
  }

  /// Dipanggil sebelum logout (token akun masih berlaku).
  Future<void> sebelumLogout() async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    try {
      await ApiClient.dio.delete(
        '/perangkat/token',
        data: {'token': t},
        options: _opsi,
      );
    } catch (_) {}
  }

  /// Dipanggil setelah sesi berakhir.
  Future<void> setelahLogout() async {
    if (!_masuk) return;
    _masuk = false;
    _timer?.cancel();
    _timer = null;
    belumDibaca.value = 0;
    if (_firebaseSiap) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
    _token = null;
  }

  Future<void> _kirimToken(String token) async {
    try {
      await ApiClient.dio.post(
        '/perangkat/token',
        data: {
          'token': token,
          'platform': defaultTargetPlatform.name,
          'nama_perangkat': defaultTargetPlatform.name,
          'versi_aplikasi': '1.0.0',
        },
        options: _opsi,
      );
    } catch (e) {
      debugPrint('notifikasi: gagal mengirim token perangkat: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Pesan masuk
  // -------------------------------------------------------------------------
  Future<void> _pesanDepan(RemoteMessage m) async {
    final judul = m.notification?.title ??
        m.data['judul']?.toString() ??
        'Posyandu';
    final isi = m.notification?.body ?? m.data['isi']?.toString() ?? '';

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _lokal.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 % 2147483647,
          judul,
          isi,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _kanal.id,
              _kanal.name,
              channelDescription: _kanal.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              styleInformation: BigTextStyleInformation(isi),
            ),
          ),
          payload: m.data['notifikasi_id']?.toString(),
        );
      } catch (e) {
        debugPrint('notifikasi: gagal menampilkan notifikasi: $e');
      }
    }

    versi.value++;
    await perbaruiJumlah();
  }

  void bukaHalaman({String? notifikasiId}) {
    final nav = navigatorKey.currentState;
    if (!_masuk || nav == null) {
      _bukaTertunda = true;
      _idTertunda = notifikasiId;
      return;
    }
    if (notifikasiId != null && notifikasiId.isNotEmpty) {
      tandaiDibaca(notifikasiId);
    }
    nav.push(MaterialPageRoute(builder: (_) => const NotifikasiPage()));
  }

  // -------------------------------------------------------------------------
  // API
  // -------------------------------------------------------------------------
  Future<(List<NotifikasiItem>, int)> ambil({
    int limit = 20,
    int offset = 0,
    bool hanyaBelumDibaca = false,
  }) async {
    final r = await ApiClient.dio.get(
      '/notifikasi',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (hanyaBelumDibaca) 'belum_dibaca': 'true',
      },
      options: _opsi,
    );
    final d = r.data;
    final list = <NotifikasiItem>[];
    var total = 0;
    if (d is Map) {
      final data = d['data'];
      if (data is List) {
        for (final e in data) {
          if (e is Map) {
            list.add(NotifikasiItem.fromApi(Map<String, dynamic>.from(e)));
          }
        }
      }
      total = int.tryParse(d['total']?.toString() ?? '') ?? list.length;
      final belum = int.tryParse(d['belum_dibaca']?.toString() ?? '');
      if (belum != null) belumDibaca.value = belum;
    }
    return (list, total);
  }

  Future<void> perbaruiJumlah() async {
    if (!_masuk) return;
    try {
      final r = await ApiClient.dio.get(
        '/notifikasi/jumlah-belum-dibaca',
        options: _opsi,
      );
      final d = r.data;
      dynamic v;
      if (d is Map) {
        v = d['data'] is Map ? (d['data'] as Map)['belum_dibaca'] : d['belum_dibaca'];
      }
      belumDibaca.value = int.tryParse(v?.toString() ?? '') ?? 0;
    } catch (_) {}
  }

  Future<void> tandaiDibaca(String id) async {
    try {
      await ApiClient.dio.patch('/notifikasi/$id/baca', options: _opsi);
    } catch (_) {}
    await perbaruiJumlah();
  }

  Future<void> tandaiSemuaDibaca() async {
    await ApiClient.dio.post('/notifikasi/baca-semua', options: _opsi);
    belumDibaca.value = 0;
  }

  Future<void> hapus(String id) async {
    await ApiClient.dio.delete('/notifikasi/$id', options: _opsi);
    await perbaruiJumlah();
  }
}