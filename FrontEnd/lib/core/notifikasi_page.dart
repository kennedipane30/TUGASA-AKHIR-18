import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'common_widgets.dart';
import 'notifikasi_service.dart';

const _hijauHeader = Color(0xFF14634A);
const _teksGelap = Color(0xFF1F2937);

String _pesanError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server tidak merespons. Periksa koneksi dan alamat server.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server.';
      default:
        return 'Terjadi kesalahan (kode ${e.response?.statusCode ?? '-'}).';
    }
  }
  return 'Terjadi kesalahan: $e';
}

String waktuNotifikasi(DateTime t) {
  final s = DateTime.now().difference(t);
  if (s.inMinutes < 1) return 'Baru saja';
  if (s.inMinutes < 60) return '${s.inMinutes} menit lalu';
  if (s.inHours < 24) return '${s.inHours} jam lalu';
  if (s.inDays < 7) return '${s.inDays} hari lalu';
  return '${formatTanggal(t)} ${formatJam(t)}';
}

(IconData, Color, Color) _gayaJenis(String jenis) {
  switch (jenis) {
    case 'jadwal_baru':
      return (Icons.event_available, AppColors.hijau, AppColors.hijauMuda);
    case 'pengingat_jadwal':
      return (Icons.alarm, AppColors.kuning, AppColors.kuningMuda);
    case 'checkin_dibuka':
      return (Icons.qr_code_scanner, AppColors.biru, AppColors.biruMuda);
    case 'jadwal_diubah':
      return (Icons.edit_calendar, AppColors.biru, AppColors.biruMuda);
    case 'jadwal_dibatalkan':
      return (Icons.event_busy, AppColors.merah, AppColors.merahMuda);
    default:
      return (Icons.notifications, AppColors.hijau, AppColors.hijauMuda);
  }
}

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  final _svc = NotifikasiService.instance;
  final _scroll = ScrollController();

  List<NotifikasiItem> _data = [];
  int _total = 0;
  bool _memuat = true;
  bool _memuatLagi = false;
  bool _hanyaBelum = false;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_cekAkhir);
    _svc.versi.addListener(_dengarBaru);
    _muat();
  }

  @override
  void dispose() {
    _svc.versi.removeListener(_dengarBaru);
    _scroll.removeListener(_cekAkhir);
    _scroll.dispose();
    super.dispose();
  }

  void _dengarBaru() => _muat();

  void _cekAkhir() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _muatLagi();
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _muat() async {
    try {
      final (list, total) = await _svc.ambil(
        limit: 20,
        offset: 0,
        hanyaBelumDibaca: _hanyaBelum,
      );
      if (!mounted) return;
      setState(() {
        _data = list;
        _total = total;
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = _pesanError(e);
        _memuat = false;
      });
    }
  }

  Future<void> _muatLagi() async {
    if (_memuatLagi || _memuat || _data.length >= _total) return;
    setState(() => _memuatLagi = true);
    try {
      final (list, total) = await _svc.ambil(
        limit: 20,
        offset: _data.length,
        hanyaBelumDibaca: _hanyaBelum,
      );
      if (!mounted) return;
      setState(() {
        _data = [..._data, ...list];
        _total = total;
        _memuatLagi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _memuatLagi = false);
      _snack(_pesanError(e));
    }
  }

  void _gantiFilter(bool belum) {
    if (_hanyaBelum == belum) return;
    setState(() {
      _hanyaBelum = belum;
      _memuat = true;
    });
    _muat();
  }

  Future<void> _tandaiSemua() async {
    try {
      await _svc.tandaiSemuaDibaca();
      if (!mounted) return;
      setState(() {
        for (final n in _data) {
          n.sudahDibaca = true;
        }
        if (_hanyaBelum) {
          _data = [];
          _total = 0;
        }
      });
      _snack('Semua notifikasi ditandai sudah dibaca');
    } catch (e) {
      _snack(_pesanError(e));
    }
  }

  Future<void> _ketuk(NotifikasiItem n) async {
    if (!n.sudahDibaca) {
      setState(() => n.sudahDibaca = true);
      _svc.tandaiDibaca(n.id);
    }
    final (ikon, fg, bg) = _gayaJenis(n.jenis);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(ikon, color: fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      n.judul,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _teksGelap,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                n.isi,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: _teksGelap,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${formatTanggal(n.dibuat)} pukul ${formatJam(n.dibuat)} WIB',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.teksRedup,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: AppButton('Tutup', onPressed: () => Navigator.pop(ctx)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _hapus(NotifikasiItem n) async {
    try {
      await _svc.hapus(n.id);
      if (!mounted) return true;
      setState(() {
        _data.remove(n);
        _total = _total > 0 ? _total - 1 : 0;
      });
      _snack('Notifikasi dihapus');
      return true;
    } catch (e) {
      _snack(_pesanError(e));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: _hijauHeader,
        surfaceTintColor: _hijauHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _hijauHeader,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _svc.belumDibaca,
            builder: (_, jumlah, __) => IconButton(
              tooltip: 'Tandai semua sudah dibaca',
              onPressed: jumlah > 0 ? _tandaiSemua : null,
              icon: Icon(
                Icons.done_all,
                color: jumlah > 0 ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                _filter('Semua', !_hanyaBelum, () => _gantiFilter(false)),
                const SizedBox(width: 8),
                ValueListenableBuilder<int>(
                  valueListenable: _svc.belumDibaca,
                  builder: (_, jumlah, __) => _filter(
                    jumlah > 0 ? 'Belum dibaca ($jumlah)' : 'Belum dibaca',
                    _hanyaBelum,
                    () => _gantiFilter(true),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE6ECE8)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _muat,
              child: _isi(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filter(String label, bool aktif, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: aktif ? _hijauHeader : AppColors.latar,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: aktif ? _hijauHeader : const Color(0xFFE6ECE8),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: aktif ? Colors.white : _teksGelap,
          ),
        ),
      ),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_gagal != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.kuningMuda,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE6ECE8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: AppColors.kuning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _gagal!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _memuat = true);
                    _muat();
                  },
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_data.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.hijauMuda,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: AppColors.hijau,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _hanyaBelum
                ? 'Semua notifikasi sudah dibaca.'
                : 'Belum ada notifikasi.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _teksGelap,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pengingat jadwal posyandu dan pemberitahuan check-in akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _data.length + (_data.length < _total ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _data.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _kartu(_data[i]);
      },
    );
  }

  Widget _kartu(NotifikasiItem n) {
    final (ikon, fg, bg) = _gayaJenis(n.jenis);
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _hapus(n),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.merahMuda,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.merah),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: n.sudahDibaca ? Colors.white : const Color(0xFFF0FAF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.sudahDibaca
                ? const Color(0xFFE6ECE8)
                : const Color(0xFFBFE5D0),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _ketuk(n),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(ikon, color: fg, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.judul,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: n.sudahDibaca
                                      ? FontWeight.w700
                                      : FontWeight.w900,
                                  color: _teksGelap,
                                ),
                              ),
                            ),
                            if (!n.sudahDibaca)
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(left: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.merah,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.isi,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          waktuNotifikasi(n.dibuat),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.teksRedup,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}