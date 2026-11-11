import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/Sekretaris/jadwal/admin_jadwal_page.dart';
import '../features/OrangTua/pendaftaran/orangtua_kartu_antrean_page.dart';
import '../features/OrangTua/pendaftaran/orangtua_pendaftaran_page.dart';
import '../features/OrangTua/riwayat/orangtua_grafik_page.dart';
import '../features/OrangTua/riwayat/orangtua_pemeriksaan_page.dart';
import '../features/OrangTua/vaksin/orangtua_vaksin_page.dart';
import '../features/auth/auth_provider.dart';
import 'app_colors.dart';
import 'balita_detail_page.dart';
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
    case 'peringatan_timbang':
      return (Icons.warning_amber_rounded, AppColors.merah, AppColors.merahMuda);
    // pengingat kesehatan anak (imunisasi, Vitamin A, obat cacing)
    case 'rencana_posyandu':
      return (Icons.event_note, AppColors.hijau, AppColors.hijauMuda);
    case 'pengingat_imunisasi':
      return (Icons.vaccines_outlined, AppColors.biru, AppColors.biruMuda);
    case 'pengingat_suplemen':
      return (Icons.medication_outlined, AppColors.kuning, AppColors.kuningMuda);
    case 'imunisasi_terlambat':
      return (Icons.running_with_errors, AppColors.merah, AppColors.merahMuda);
    case 'imunisasi_faskes':
      return (Icons.local_hospital_outlined, AppColors.merah, AppColors.merahMuda);
    case 'jadwal_belum_ada':
      return (Icons.event_busy, AppColors.kuning, AppColors.kuningMuda);
    case 'laporan_kipi':
      return (Icons.healing_outlined, AppColors.merah, AppColors.merahMuda);
    case 'hasil_pemeriksaan':
      return (Icons.fact_check_outlined, AppColors.hijau, AppColors.hijauMuda);
    default:
      return (Icons.notifications, AppColors.hijau, AppColors.hijauMuda);
  }
}

String _roleDari(BuildContext context) {
  try {
    return (Provider.of<AuthProvider>(context, listen: false).user?['role'] ?? '').toString();
  } catch (_) {
    return '';
  }
}

/// Label tombol tujuan notifikasi; null bila notifikasi cukup dibaca saja.
String? labelTujuanNotifikasi(String jenis, String role, String? objekId) {
  final adaObjek = objekId != null && objekId.isNotEmpty;
  switch (jenis) {
    case 'jadwal_baru':
    case 'pengingat_jadwal':
      return role == 'orang_tua' ? 'Daftar Sekarang' : null;
    case 'jadwal_diubah':
      return role == 'orang_tua' ? 'Lihat Jadwal & Pendaftaran' : null;
    case 'checkin_dibuka':
      return role == 'orang_tua' ? 'Lihat Nomor Antrean' : null;
    case 'peringatan_timbang':
      return adaObjek ? 'Lihat Data Anak' : null;
    case 'rencana_posyandu':
    case 'pengingat_imunisasi':
    case 'pengingat_suplemen':
      return role == 'orang_tua' ? 'Lihat Rencana & Daftar' : null;
    case 'imunisasi_terlambat':
    case 'imunisasi_faskes':
      return role == 'orang_tua' ? 'Lihat Jadwal Vaksin Anak' : null;
    case 'jadwal_belum_ada':
      return role == 'sekretaris' ? 'Buat Jadwal Posyandu' : null;
    case 'laporan_kipi':
      return role == 'bidan' && adaObjek ? 'Lihat Vaksin Anak' : null;
    case 'hasil_pemeriksaan':
      return role == 'orang_tua' ? 'Lihat Detail Pemeriksaan' : null;
  }
  return null;
}

/// Membuka halaman tujuan sebuah notifikasi.
///   - Jadwal baru / pengingat jadwal / jadwal diubah (orang tua): halaman Pendaftaran.
///   - Check-in dibuka (orang tua): halaman Nomor Antrean anak yang sudah terdaftar
///     (pilih anak bila lebih dari satu; ke Pendaftaran bila belum ada yang terdaftar).
///   - Peringatan 2T/BGM: orang tua ke Grafik anak, petugas ke detail balita.
///   - Rencana / pengingat H-3 (orang tua): halaman Pendaftaran (kartu Rencana Pelayanan).
///   - Imunisasi terlambat / ke puskesmas (orang tua): halaman Vaksin Anak.
///   - Jadwal belum dibuat (sekretaris): halaman Kelola Jadwal.
///   - Laporan reaksi imunisasi / KIPI (bidan): tab Vaksin pada detail balita.
///   - Hasil pemeriksaan bidan (orang tua): langsung ke detail pemeriksaan kunjungan itu.
///   - Lainnya: daftar notifikasi.
void bukaObjekNotifikasi(NavigatorState nav, String jenis, String? objekId) {
  final role = _roleDari(nav.context);
  final id = objekId ?? '';
  final adaObjek = id.isNotEmpty;

  Widget halaman = const NotifikasiPage();
  switch (jenis) {
    case 'jadwal_baru':
    case 'pengingat_jadwal':
    case 'jadwal_diubah':
      if (role == 'orang_tua') halaman = const OrangTuaPendaftaranPage();
    case 'checkin_dibuka':
      if (role == 'orang_tua') {
        _bukaNomorAntrean(nav);
        return;
      }
    case 'peringatan_timbang':
      if (adaObjek) {
        halaman = switch (role) {
          'orang_tua' => OrangTuaGrafikPage(anakId: id),
          'bidan' => BalitaDetailPage(prefix: '/bidan', anakId: id, nama: 'Detail Balita', bisaKelolaVaksin: true),
          'kader' => BalitaDetailPage(prefix: '/kader', anakId: id, nama: 'Detail Balita'),
          'sekretaris' => BalitaDetailPage(prefix: '/sekretaris', anakId: id, nama: 'Detail Balita'),
          _ => const NotifikasiPage(),
        };
      }
    case 'rencana_posyandu':
    case 'pengingat_imunisasi':
    case 'pengingat_suplemen':
      if (role == 'orang_tua') halaman = const OrangTuaPendaftaranPage();
    case 'imunisasi_terlambat':
    case 'imunisasi_faskes':
      if (role == 'orang_tua') halaman = const OrangTuaVaksinPage();
    case 'jadwal_belum_ada':
      if (role == 'sekretaris') halaman = const AdminJadwalPage();
    case 'laporan_kipi':
      if (role == 'bidan' && adaObjek) {
        halaman = BalitaDetailPage(
          prefix: '/bidan',
          anakId: id,
          nama: 'Detail Balita',
          bisaKelolaVaksin: true,
          tabAwal: 2,
        );
      }
    case 'hasil_pemeriksaan':
      if (role == 'orang_tua') {
        halaman = OrangTuaPemeriksaanPage(pendaftaranId: adaObjek ? id : null);
      }
  }
  nav.push(MaterialPageRoute(builder: (_) => halaman));
}

/// Check-in dibuka: buka halaman Nomor Antrean anak yang terdaftar pada jadwal terdekat.
Future<void> _bukaNomorAntrean(NavigatorState nav) async {
  JadwalTerdekatData? j;
  try {
    j = await JadwalTerdekatData.ambil();
  } catch (_) {
    j = null;
  }
  if (!nav.mounted) return;

  final terdaftar = j == null
      ? <AnakStatusJadwal>[]
      : j.anak
          .where((a) => a.status == 'terdaftar' || a.status == 'sudah_checkin')
          .toList();

  if (j == null || terdaftar.isEmpty) {
    nav.push(MaterialPageRoute(builder: (_) => const OrangTuaPendaftaranPage()));
    return;
  }

  final jadwalId = j.id;
  void bukaKartu(AnakStatusJadwal a) {
    nav.push(MaterialPageRoute(
      builder: (_) => KartuAntreanPage(jadwalId: jadwalId, anakId: a.anakId),
    ));
  }

  if (terdaftar.length == 1) {
    bukaKartu(terdaftar.first);
    return;
  }

  final pilih = await showModalBottomSheet<AnakStatusJadwal>(
    context: nav.context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Nomor Antrean Anak',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _teksGelap,
              ),
            ),
            const SizedBox(height: 12),
            for (final a in terdaftar)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.hijauMuda,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.confirmation_number_outlined, color: AppColors.hijau),
                ),
                title: Text(
                  a.nama,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  a.nomorAntrean == null
                      ? (a.status == 'sudah_checkin' ? 'Sudah check-in' : 'Terdaftar')
                      : 'Nomor A-${a.nomorAntrean.toString().padLeft(3, '0')}'
                          '${a.status == 'sudah_checkin' ? ' · Sudah check-in' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    ),
  );
  if (pilih != null && nav.mounted) bukaKartu(pilih);
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

  // mode pilih (hapus beberapa notifikasi sekaligus)
  bool _modePilih = false;
  bool _menghapus = false;
  final Set<String> _terpilih = {};

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
        _terpilih.removeWhere((id) => !list.any((n) => n.id == id));
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

  // -------------------------------------------------------------------------
  // Hapus notifikasi
  // -------------------------------------------------------------------------
  Future<bool> _konfirmasi({
    required String judul,
    required String isi,
    String tombol = 'Hapus',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          judul,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _teksGelap,
          ),
        ),
        content: Text(
          isi,
          style: const TextStyle(fontSize: 15, height: 1.5, color: _teksGelap),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.merah),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tombol),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _masukModePilih([NotifikasiItem? awal]) {
    HapticFeedback.selectionClick();
    setState(() {
      _modePilih = true;
      _terpilih.clear();
      if (awal != null) _terpilih.add(awal.id);
    });
  }

  void _keluarModePilih() {
    if (!_modePilih) return;
    setState(() {
      _modePilih = false;
      _terpilih.clear();
    });
  }

  void _togglePilih(NotifikasiItem n) {
    setState(() {
      if (!_terpilih.remove(n.id)) _terpilih.add(n.id);
    });
  }

  bool get _semuaTerpilih =>
      _data.isNotEmpty && _data.every((n) => _terpilih.contains(n.id));

  void _pilihSemua() {
    setState(() {
      if (_semuaTerpilih) {
        _terpilih.clear();
      } else {
        _terpilih.addAll(_data.map((n) => n.id));
      }
    });
  }

  Future<void> _hapusTerpilih() async {
    if (_terpilih.isEmpty || _menghapus) return;
    final ids = _terpilih.toSet();
    final ok = await _konfirmasi(
      judul: 'Hapus ${ids.length} Notifikasi?',
      isi: 'Notifikasi yang dipilih akan dihapus dari daftar dan tidak dapat dikembalikan.',
    );
    if (!ok || !mounted) return;
    setState(() => _menghapus = true);
    try {
      final n = await _svc.hapusBanyak(ids.toList());
      if (!mounted) return;
      setState(() {
        _data.removeWhere((x) => ids.contains(x.id));
        _total = _total - n < 0 ? 0 : _total - n;
        _modePilih = false;
        _terpilih.clear();
        _menghapus = false;
      });
      _snack('$n notifikasi dihapus');
      if (_data.length < 20 && _data.length < _total) _muat();
    } catch (e) {
      if (!mounted) return;
      setState(() => _menghapus = false);
      _snack(_pesanError(e));
    }
  }

  Future<void> _hapusSemua({bool hanyaSudahDibaca = false}) async {
    if (_menghapus) return;
    final ok = await _konfirmasi(
      judul: hanyaSudahDibaca ? 'Hapus Notifikasi yang Sudah Dibaca?' : 'Hapus Semua Notifikasi?',
      isi: hanyaSudahDibaca
          ? 'Semua notifikasi yang sudah dibaca akan dihapus. Notifikasi yang belum dibaca tetap tersimpan.'
          : 'Semua notifikasi, termasuk yang belum dibaca, akan dihapus dan tidak dapat dikembalikan.',
      tombol: 'Hapus',
    );
    if (!ok || !mounted) return;
    setState(() => _menghapus = true);
    try {
      final n = await _svc.hapusSemua(hanyaSudahDibaca: hanyaSudahDibaca);
      if (!mounted) return;
      if (hanyaSudahDibaca) {
        setState(() {
          _data.removeWhere((x) => x.sudahDibaca);
          _menghapus = false;
          _modePilih = false;
          _terpilih.clear();
        });
        await _muat();
      } else {
        setState(() {
          _data = [];
          _total = 0;
          _menghapus = false;
          _modePilih = false;
          _terpilih.clear();
        });
      }
      _snack(n > 0 ? '$n notifikasi dihapus' : 'Tidak ada notifikasi yang dihapus');
    } catch (e) {
      if (!mounted) return;
      setState(() => _menghapus = false);
      _snack(_pesanError(e));
    }
  }

  Future<void> _ketuk(NotifikasiItem n) async {
    if (!n.sudahDibaca) {
      setState(() => n.sudahDibaca = true);
      _svc.tandaiDibaca(n.id);
    }
    final (ikon, fg, bg) = _gayaJenis(n.jenis);
    final tujuan = labelTujuanNotifikasi(n.jenis, _roleDari(context), n.objekId);
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
                  fontSize: 15,
                  height: 1.5,
                  color: _teksGelap,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${formatTanggal(n.dibuat)} pukul ${formatJam(n.dibuat)} WIB',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.teksRedup,
                ),
              ),
              const SizedBox(height: 16),
              if (tujuan != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: AppButton(tujuan, icon: Icons.arrow_forward, onPressed: () {
                    Navigator.pop(ctx);
                    bukaObjekNotifikasi(Navigator.of(context), n.jenis, n.objekId);
                  }),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: AppButton('Tutup', filled: false, onPressed: () => Navigator.pop(ctx)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.merah,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await _konfirmasi(
                      judul: 'Hapus Notifikasi?',
                      isi: 'Notifikasi ini akan dihapus dari daftar dan tidak dapat dikembalikan.',
                    );
                    if (ok && mounted) await _hapus(n);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(
                    'Hapus Notifikasi',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
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

  // -------------------------------------------------------------------------
  // Tampilan
  // -------------------------------------------------------------------------
  PreferredSizeWidget _appBarBiasa() {
    return AppBar(
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
          fontSize: 20,
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
        PopupMenuButton<String>(
          tooltip: 'Lainnya',
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) {
            switch (v) {
              case 'pilih':
                _masukModePilih();
              case 'hapus_dibaca':
                _hapusSemua(hanyaSudahDibaca: true);
              case 'hapus_semua':
                _hapusSemua();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'pilih',
              enabled: _data.isNotEmpty,
              child: _itemMenu(Icons.checklist_rounded, 'Pilih notifikasi', _teksGelap),
            ),
            PopupMenuItem(
              value: 'hapus_dibaca',
              enabled: _total > 0,
              child: _itemMenu(Icons.mark_email_read_outlined, 'Hapus yang sudah dibaca', _teksGelap),
            ),
            PopupMenuItem(
              value: 'hapus_semua',
              enabled: _total > 0,
              child: _itemMenu(Icons.delete_sweep_outlined, 'Hapus semua', AppColors.merah),
            ),
          ],
        ),
      ],
    );
  }

  Widget _itemMenu(IconData ikon, String label, Color warna) {
    return Row(
      children: [
        Icon(ikon, size: 20, color: warna),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: warna),
        ),
      ],
    );
  }

  PreferredSizeWidget _appBarPilih() {
    final adaPilihan = _terpilih.isNotEmpty;
    return AppBar(
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
      leading: IconButton(
        tooltip: 'Batal',
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: _keluarModePilih,
      ),
      title: Text(
        adaPilihan ? '${_terpilih.length} dipilih' : 'Pilih notifikasi',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          tooltip: _semuaTerpilih ? 'Batalkan pilih semua' : 'Pilih semua',
          onPressed: _data.isEmpty ? null : _pilihSemua,
          icon: Icon(
            _semuaTerpilih ? Icons.deselect : Icons.select_all,
            color: Colors.white,
          ),
        ),
        IconButton(
          tooltip: 'Hapus yang dipilih',
          onPressed: adaPilihan && !_menghapus ? _hapusTerpilih : null,
          icon: Icon(
            Icons.delete_outline,
            color: adaPilihan ? Colors.white : Colors.white38,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: _modePilih ? _appBarPilih() : _appBarBiasa(),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                _filter('Semua', !_hanyaBelum, () {
                  _keluarModePilih();
                  _gantiFilter(false);
                }),
                const SizedBox(width: 8),
                ValueListenableBuilder<int>(
                  valueListenable: _svc.belumDibaca,
                  builder: (_, jumlah, __) => _filter(
                    jumlah > 0 ? 'Belum dibaca ($jumlah)' : 'Belum dibaca',
                    _hanyaBelum,
                    () {
                      _keluarModePilih();
                      _gantiFilter(true);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_menghapus)
            const LinearProgressIndicator(minHeight: 2, color: _hijauHeader)
          else
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
            fontSize: 13,
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
                      fontSize: 15,
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
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _teksGelap,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pengingat jadwal posyandu, check-in, imunisasi, Vitamin A, obat cacing, dan peringatan pertumbuhan anak akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.teksRedup),
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
    final dipilih = _modePilih && _terpilih.contains(n.id);
    return Dismissible(
      key: ValueKey(n.id),
      direction: _modePilih ? DismissDirection.none : DismissDirection.endToStart,
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
          color: dipilih
              ? const Color(0xFFE3F4EB)
              : (n.sudahDibaca ? Colors.white : const Color(0xFFF0FAF5)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dipilih
                ? _hijauHeader
                : (n.sudahDibaca
                    ? const Color(0xFFE6ECE8)
                    : const Color(0xFFBFE5D0)),
            width: dipilih ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _modePilih ? () => _togglePilih(n) : () => _ketuk(n),
            onLongPress: _modePilih ? null : () => _masukModePilih(n),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_modePilih)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: dipilih ? _hijauHeader : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: dipilih ? _hijauHeader : const Color(0xFFCBD5D0),
                          width: 1.5,
                        ),
                      ),
                      child: dipilih
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : null,
                    )
                  else
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
                                  fontSize: 15,
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
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          waktuNotifikasi(n.dibuat),
                          style: const TextStyle(
                            fontSize: 13,
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