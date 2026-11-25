import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/utils/posyandu.dart';
import '../../core/widgets/status_gizi_widget.dart';
import '../auth/auth_provider.dart';
import 'bukupanduan/buku_panduan_page.dart';
import 'datadiri/data_keluarga_page.dart';
import 'pendaftaran/kartu_antrean_page.dart';
import 'pendaftaran/pendaftaran_page.dart';
import 'riwayat/grafik_page.dart';
import 'riwayat/pemeriksaan_page.dart';
import 'rujukan/rujukan_anak_page.dart';
import 'imunisasi/imunisasi_page.dart';

DateTime _tambahBulan(DateTime d, int n) {
  final total = d.month - 1 + n;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final akhir = DateTime.utc(y, m + 1, 0).day;
  return DateTime.utc(y, m, d.day > akhir ? akhir : d.day);
}

/// Usia detail dari tanggal lahir "dd/mm/yyyy":
/// "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan", "2 tahun".
String _usiaAnak(String tgl) {
  final p = tgl.split('/');
  if (p.length != 3) return '-';

  final d = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return '-';

  final n = DateTime.now();
  final a = DateTime.utc(y, m, d);
  final b = DateTime.utc(n.year, n.month, n.day);
  if (b.isBefore(a)) return '0 hari';

  var bulan = (b.year - a.year) * 12 + b.month - a.month;
  if (_tambahBulan(a, bulan).isAfter(b)) bulan--;
  final hari = b.difference(_tambahBulan(a, bulan)).inDays;
  final tahun = bulan ~/ 12;
  final sisa = bulan % 12;

  if (bulan == 0) return '$hari hari';
  if (tahun == 0) return hari == 0 ? '$bulan bulan' : '$bulan bulan $hari hari';
  return sisa == 0 ? '$tahun tahun' : '$tahun tahun $sisa bulan';
}

String _kapital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _namaHari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

class OrangTuaHome extends StatefulWidget {
  const OrangTuaHome({super.key});

  @override
  State<OrangTuaHome> createState() => _OrangTuaHomeState();
}

class _OrangTuaHomeState extends State<OrangTuaHome> {
  int _aktif = 0;
  List<DataAnak> _daftar = [];
  bool _memuat = true;
  String? _gagal;
  JadwalTerdekatData? _jadwal;
  final _kunciGizi = GlobalKey<KartuPeringatanGiziState>();

  DataAnak? get _anak => _daftar.isEmpty ? null : _daftar[_aktif];

  AnakStatusJadwal? _statusAnakDari(DataAnak a) {
    final j = _jadwal;
    if (j == null) return null;

    for (final s in j.anak) {
      if (s.anakId == a.id) return s;
    }
    return null;
  }

  AnakStatusJadwal? get _statusAnak {
    final a = _anak;
    if (a == null) return null;
    return _statusAnakDari(a);
  }

  String get _hadir => _statusAnak?.status ?? 'belum_daftar';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    _kunciGizi.currentState?.muatUlang();
    JadwalTerdekatData? jadwal;
    try {
      jadwal = await JadwalTerdekatData.ambil();
    } catch (_) {
      jadwal = null;
    }

    try {
      final data = await KeluargaApi.ambil();
      final daftar = ((data['anak'] as List?) ?? [])
          .map((e) => DataAnak.fromApi(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (!mounted) return;
      setState(() {
        _daftar = daftar;
        _jadwal = jadwal;
        if (_aktif >= daftar.length) _aktif = 0;
        _gagal = null;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gagal = 'Gagal memuat data anak dari server.';
        _memuat = false;
      });
    }
  }

  Future<void> _bukaPendaftaran() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrangTuaPendaftaranPage(),
      ),
    );
    _muat();
  }

  /// Anak terpilih terdaftar tetapi belum check-in: langsung buka kamera scan QR.
  /// Berhasil check-in -> diarahkan ke halaman nomor antrean.
  Future<void> _scanSekarang() async {
    final j = _jadwal;
    final a = _anak;
    final s = _statusAnak;
    if (j == null || a?.id == null || s == null) return;
    if (!s.bolehCheckin) {
      final buka = j.checkinBuka;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(buka == null
              ? 'Check-in belum dapat dilakukan'
              : 'Check-in dibuka pukul ${formatJam(buka)} WIB (1 jam sebelum jadwal dimulai)'),
        ));
      return;
    }
    final ok = await scanCheckin(context, jadwalId: j.id, anakId: a!.id!.toString());
    if (!mounted) return;
    if (ok) {
      await _bukaNomorAntrean();
    } else {
      _muat();
    }
  }

  /// Anak terpilih sudah check-in: buka halaman nomor antrean.
  Future<void> _bukaNomorAntrean() async {
    final j = _jadwal;
    final a = _anak;
    if (j == null || a?.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KartuAntreanPage(jadwalId: j.id, anakId: a!.id!.toString()),
      ),
    );
    _muat();
  }

  void _bukaBukuPanduan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BukuPanduanPage()),
    );
  }

  void _bukaImunisasi() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrangTuaImunisasiPage()),
    );
  }

  void _bukaRujukan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrangTuaRujukanPage()),
    );
  }

  void _bukaPemeriksaan() {
    final a = _anak;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaPemeriksaanPage(
          anakId: a?.id?.toString(),
        ),
      ),
    );
  }

  /// Anak selesai dilayani: buka hasil pemeriksaan kunjungan hari ini.
  void _bukaHasilSelesai() {
    final st = _statusAnak;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaPemeriksaanPage(
          anakId: st?.anakId ?? _anak?.id?.toString(),
          pendaftaranId: (st == null || st.pendaftaranId.isEmpty) ? null : st.pendaftaranId,
        ),
      ),
    );
  }

  void _bukaPemeriksaanAnak(String anakId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaPemeriksaanPage(anakId: anakId),
      ),
    );
  }

  void _bukaGrafik() {
    final a = _anak;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrangTuaGrafikPage(
          anakId: a?.id?.toString(),
        ),
      ),
    );
  }

  Future<void> _bukaDataKeluarga() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DataKeluargaPage(),
      ),
    );
    _muat();
  }

  /// Nama depan pengguna yang login, huruf kapital (mis. "KENNEDI").
  String _namaSapaan(Map? user) {
    final nama = (user?['nama'] ?? '').toString().trim();
    if (nama.isEmpty) return 'BUNDA';
    return nama.split(RegExp(r'\s+')).first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final pos = (user?['posyandu'] ?? '').toString();
    final lokasi = pos.isEmpty
        ? 'Posyandu belum ditetapkan'
        : 'Posyandu ${labelPosyandu(pos)}';
    final siap = !_memuat && _gagal == null && _daftar.isNotEmpty;

    return HomeShell(
      peran: 'Orang Tua',
      lokasi: lokasi,
      sapaan: _namaSapaan(user),
      kartuUtama: _kartuStatus(),
      children: [
        if (siap) ...[
          KartuPeringatanGizi(
            key: _kunciGizi,
            onLihat: _bukaPemeriksaanAnak,
          ),
          const SizedBox(height: 8),
        ],
        _layananPosyandu(),
      ],
    );
  }

  Widget _kartuGagal() {
    return KartuPesanHome(
      ikon: Icons.cloud_off,
      warnaIkon: warnaPeringatanTeksHome,
      isi: warnaPeringatanIsiHome,
      judul: 'Gagal memuat',
      pesan: _gagal ?? 'Data tidak dapat dimuat dari server.',
      aksi: TombolUtamaHome(
        label: 'Coba Lagi',
        ikon: Icons.refresh,
        onTap: () {
          setState(() => _memuat = true);
          _muat();
        },
      ),
    );
  }

  Widget _kartuBelumAdaAnak() {
    return KartuPesanHome(
      ikon: Icons.child_care,
      judul: 'Data Anak',
      pesan: 'Belum ada data anak. Lengkapi data keluarga terlebih dahulu.',
      aksi: TombolUtamaHome(
        label: 'Lengkapi Data Keluarga',
        ikon: Icons.family_restroom,
        onTap: _bukaDataKeluarga,
      ),
    );
  }

  void _pilihAnakSheet() {
    if (_daftar.length < 2) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Pilih Anak',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < _daftar.length; i++)
              ListTile(
                leading: Icon(
                  i == _aktif
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: i == _aktif
                      ? AppColors.hijau
                      : AppColors.teksRedup,
                ),
                title: Text(
                  _daftar[i].nama,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(_usiaAnak(_daftar[i].tglLahir)),
                onTap: () {
                  setState(() => _aktif = i);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // KARTU STATUS: jadwal posyandu terdekat untuk anak yang dipilih
  // -------------------------------------------------------------------------

  /// Lencana status pelayanan anak pada jadwal terdekat.
  Widget _lencanaStatus() {
    final s = _statusAnak?.statusTampil ?? _hadir;
    final (label, _, _) = labelStatusHadir(s);
    final jenis = switch (s) {
      'selesai' => 'sukses',
      'terdaftar' || 'belum_checkin' || 'sudah_checkin' || 'menunggu_kader' || 'menunggu_bidan' =>
        'info',
      'tidak_hadir' || 'tidak_dilayani' => 'bahaya',
      _ => 'peringatan',
    };
    return LencanaStatusHome.jenis(jenis, label);
  }

  /// Tombol utama kartu status (mengikuti anak yang dipilih):
  ///  - belum daftar   : "Buka Pendaftaran & Check-in" -> halaman pendaftaran
  ///  - terdaftar      : "Scan Sekarang"   -> kamera scan QR -> halaman nomor antrean
  ///  - sudah check-in : "Nomor Antrean"   -> halaman nomor antrean
  ///  - selesai dilayani (bidan sudah mencatat): "Lihat Hasil Pemeriksaan"
  Widget _tombolDaftar() {
    final terdaftar = _hadir == 'terdaftar';
    final sudahCheckin = _hadir == 'sudah_checkin';
    final selesai = _statusAnak?.selesai ?? false;
    final (String label, IconData ikon, VoidCallback aksi) = terdaftar
        ? ('Scan Sekarang', Icons.qr_code_scanner, _scanSekarang)
        : selesai
            ? ('Lihat Hasil Pemeriksaan', Icons.fact_check_outlined, _bukaHasilSelesai)
            : sudahCheckin
                ? ('Nomor Antrean', Icons.confirmation_number_outlined, _bukaNomorAntrean)
                : ('Buka Pendaftaran & Check-in', Icons.app_registration_rounded, _bukaPendaftaran);
    return TombolUtamaHome(label: label, ikon: ikon, onTap: aksi);
  }

  /// Kartu status yang menumpuk header: jadwal, waktu, lokasi, dan tombol utama.
  Widget _kartuStatus() {
    if (_memuat) {
      return const KartuHome(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_gagal != null) return _kartuGagal();
    if (_daftar.isEmpty) return _kartuBelumAdaAnak();

    final j = _jadwal;
    final pos = (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();

    if (j == null) {
      return KartuPesanHome(
        ikon: Icons.event_busy_rounded,
        judul: 'Belum ada jadwal',
        pesan: pos.isEmpty
            ? 'Belum ada jadwal posyandu mendatang.'
            : 'Belum ada jadwal mendatang untuk Posyandu ${labelPosyandu(pos)}.',
      );
    }

    final hariIni = DateTime.now();
    final selisih = DateTime(j.tanggal.year, j.tanggal.month, j.tanggal.day)
        .difference(DateTime(hariIni.year, hariIni.month, hariIni.day))
        .inDays;
    final hitung = selisih <= 0 ? 'Hari ini' : (selisih == 1 ? 'Besok' : 'H-$selisih');
    final hari = _namaHari[j.tanggal.weekday - 1];
    // Lokasi dan jadwal sesuai data yang dimasukkan sekretaris.
    final lokasi = j.lokasi.trim().isNotEmpty
        ? j.lokasi.trim()
        : (pos.isEmpty ? '' : 'Posyandu ${labelPosyandu(pos)}');
    final jam = j.jam.trim();

    return KartuHome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KepalaKartuHome(
            judul: _kapital(_anak?.nama ?? '-'),
            onJudul: _daftar.length > 1 ? _pilihAnakSheet : null,
            lencana: _lencanaStatus(),
          ),
          const SizedBox(height: 16),
          BarisInfoHome(
            Icons.event_rounded,
            'Jadwal',
            '$hari, ${formatTanggal(j.tanggal)}  ·  $hitung',
          ),
          BarisInfoHome(Icons.schedule, 'Waktu', jam.isEmpty ? '' : '$jam WIB'),
          if (lokasi.isNotEmpty) BarisInfoHome(Icons.location_on, 'Lokasi', lokasi),
          if (j.checkinBuka != null)
            BarisInfoHome(
              Icons.qr_code_scanner,
              'Scan QR',
              'Dibuka pukul ${formatJam(j.checkinBuka!)}',
            ),
          const SizedBox(height: 4),
          _tombolDaftar(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // GRID LAYANAN (ikon memakai gambar yang sudah ada)
  // -------------------------------------------------------------------------
  Widget _layananPosyandu() {
    return GridLayananHome(
      judul: 'Layanan Posyandu',
      item: [
        ItemLayananHome(
          aset: 'pendaftaran.png',
          cadangan: Icons.person_add_alt_1_rounded,
          warna: const Color(0xFF0B6B55),
          judul: 'Pendaftaran\nPosyandu',
          onTap: _bukaPendaftaran,
        ),
        ItemLayananHome(
          aset: 'hasil_pemeriksaan.png',
          cadangan: Icons.assignment_rounded,
          warna: const Color(0xFF0369A1),
          judul: 'Hasil\nPemeriksaan',
          onTap: _bukaPemeriksaan,
        ),
        ItemLayananHome(
          aset: 'grafik_anak.png',
          cadangan: Icons.show_chart_rounded,
          warna: const Color(0xFF0B6B55),
          judul: 'Grafik\nAnak',
          onTap: _bukaGrafik,
        ),
        ItemLayananHome(
          aset: 'imunisasi_anak.png',
          cadangan: Icons.vaccines_rounded,
          warna: const Color(0xFF2563EB),
          judul: 'Imunisasi\nAnak',
          onTap: _bukaImunisasi,
        ),
        ItemLayananHome(
          aset: 'rujukan_anak.png',
          cadangan: Icons.description_rounded,
          warna: const Color(0xFFB45309),
          judul: 'Rujukan\nAnak',
          onTap: _bukaRujukan,
        ),
        ItemLayananHome(
          aset: 'buku_panduan.png',
          cadangan: Icons.menu_book_rounded,
          warna: const Color(0xFF2563EB),
          judul: 'Buku\nPanduan',
          onTap: _bukaBukuPanduan,
        ),
        ItemLayananHome(
          aset: 'data_keluarga.png',
          cadangan: Icons.family_restroom_rounded,
          warna: const Color(0xFF0B6B55),
          judul: 'Data\nKeluarga',
          onTap: _bukaDataKeluarga,
        ),
      ],
    );
  }
}