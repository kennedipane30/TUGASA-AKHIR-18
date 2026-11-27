import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/common_widgets.dart';
import '../../core/utils/posyandu.dart';
import '../../core/pages/checkin/qr_checkin_page.dart';
import '../OrangTua/pendaftaran/pendaftaran_page.dart';
import '../../core/pages/anak/semua_anak_page.dart';
import '../auth/auth_provider.dart';
import 'pendataan/pendataan_page.dart';
import 'keluarga/keluarga_page.dart';
import 'daftarkan_anak/daftarkan_anak_page.dart';
import 'riwayat/riwayat_page.dart';
import 'rekap/anak_tidak_hadir_page.dart';
import 'imunisasi/imunisasi_page.dart';

const _namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

class KaderHome extends StatefulWidget {
  const KaderHome({super.key});

  @override
  State<KaderHome> createState() => _KaderHomeState();
}

class _KaderHomeState extends State<KaderHome> {
  JadwalTerdekatData? _jadwal;
  List<AntreanKader> _antrean = [];
  bool _memuat = true;
  String? _gagal;

  bool _sinkronBerjalan = false;
  int _tertunda = 0;
  String _sinkronTerakhir = 'baru saja';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      final list = j == null ? <AntreanKader>[] : await AntreanKader.ambil(j.id);
      if (!mounted) return;
      setState(() {
        _jadwal = j;
        _antrean = list;
        _gagal = null;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gagal = 'Gagal memuat data antrean dari server.';
        _memuat = false;
      });
    }
  }

  Future<void> _sinkronkan() async {
    setState(() => _sinkronBerjalan = true);
    await _muat();
    if (!mounted) return;
    setState(() {
      _sinkronBerjalan = false;
      _tertunda = 0;
      _sinkronTerakhir = 'baru saja';
    });
  }

  Future<void> _bukaAntrean() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderPendataanPage()),
    );
    _muat();
  }

  /// Tambahkan akun orang tua & data keluarga (keluarga tanpa akun / tanpa HP).
  void _bukaKeluarga() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KeluargaPage()),
    );
  }

  /// Daftarkan anak ke sesi posyandu hari ini (walk-in), lalu muat ulang antrean.
  Future<void> _bukaDaftarkanAnak() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DaftarkanAnakPage()),
    );
    _muat();
  }

  void _bukaQr() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrCheckinPage(role: 'kader')),
    );
  }

  void _bukaImunisasi() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderImunisasiPage()),
    );
  }

  void _bukaAnak() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SemuaAnakPage(prefix: '/kader')),
    );
  }

  void _bukaTidakHadir() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderTidakHadirPage()),
    );
  }

  void _bukaRiwayat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderRiwayatPage()),
    );
  }

  Widget _kartuGagal() {
    return KartuPesanHome(
      ikon: Icons.cloud_off,
      isi: warnaPeringatanIsiHome,
      warnaIkon: warnaPeringatanTeksHome,
      judul: 'Gagal memuat',
      pesan: _gagal ?? 'Data antrean tidak dapat dimuat dari server.',
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

  /// Nama depan pengguna yang login, huruf kapital (mis. "KENNEDI").
  String _namaSapaan(Map? user) {
    final nama = (user?['nama'] ?? '').toString().trim();
    if (nama.isEmpty) return 'KADER';
    return nama.split(RegExp(r'\s+')).first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final pos = (user?['posyandu'] ?? '').toString();
    final lokasi = pos.isEmpty
        ? 'Posyandu belum ditetapkan'
        : 'Posyandu ${labelPosyandu(pos)}';

    return HomeShell(
      peran: 'Kader',
      lokasi: lokasi,
      sapaan: _namaSapaan(user),
      kartuUtama: _kartuSesi(),
      children: [
        _layananUtama(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // KARTU STATUS: sesi posyandu terdekat beserta ringkasan antrean
  // -------------------------------------------------------------------------

  /// Keterangan waktu sesi: "Hari ini", "Besok", "3 hari lagi", atau "Selesai",
  /// beserta jenis lencana yang dipakai.
  (String, String) _statusSesi(DateTime tanggal) {
    final n = DateTime.now();
    final hari = DateTime(n.year, n.month, n.day);
    final t = DateTime(tanggal.year, tanggal.month, tanggal.day);
    final selisih = t.difference(hari).inDays;
    if (selisih == 0) return ('Hari ini', 'sukses');
    if (selisih == 1) return ('Besok', 'info');
    if (selisih > 1) return ('$selisih hari lagi', 'info');
    return ('Selesai', 'peringatan');
  }

  Widget _kartuSesi() {
    if (_memuat) {
      return const KartuHome(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_gagal != null) return _kartuGagal();

    final j = _jadwal;
    if (j == null) {
      return const KartuPesanHome(
        ikon: Icons.event_busy_rounded,
        judul: 'Sesi Posyandu',
        pesan: 'Belum ada jadwal aktif untuk posyandu Anda. Antrean pendataan muncul '
            'setelah sekretaris menerbitkan jadwal.',
      );
    }

    final (status, jenis) = _statusSesi(j.tanggal);
    final checkin = _antrean.length;
    final diukur = _antrean.where((a) => a.sudahDiukur).length;
    final menunggu = checkin - diukur;

    return KartuHome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KepalaKartuHome(
            ikon: Icons.event_available_rounded,
            judul: 'Sesi Posyandu',
            lencana: LencanaStatusHome.jenis(jenis, status),
          ),
          const SizedBox(height: 16),
          BarisInfoHome(
            Icons.event_rounded,
            'Jadwal',
            '${_namaHari[j.tanggal.weekday - 1]}, ${formatTanggal(j.tanggal)}',
          ),
          BarisInfoHome(Icons.schedule, 'Waktu', j.jam.isEmpty ? '' : '${j.jam} WIB'),
          BarisInfoHome(Icons.location_on, 'Lokasi', j.lokasi),

          // Ringkasan antrean pendataan
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 16),
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: warnaGarisHome.withValues(alpha: 0.4)),
              ),
            ),
            child: RingkasAngkaHome(
              item: [
                ('$checkin', 'Check-in', warnaTeksHome),
                ('$diukur', 'Sudah diukur', warnaUtamaHome),
                ('$menunggu', 'Menunggu', menunggu > 0 ? warnaPeringatanTeksHome : warnaTeksVarianHome),
              ],
            ),
          ),

          TombolUtamaHome(
            label: 'Lihat Antrean Pendataan',
            ikon: Icons.assignment_turned_in_outlined,
            onTap: _bukaAntrean,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // GRID LAYANAN (ikon memakai gambar yang sudah ada)
  // -------------------------------------------------------------------------
  Widget _layananUtama() {
    return GridLayananHome(
      judul: 'Layanan Kader',
      item: [
        ItemLayananHome(
          aset: 'qr_chekin.png',
          cadangan: Icons.qr_code_2_rounded,
          warna: const Color(0xFF1D6FD6),
          judul: 'QR\nCheck-in',
          onTap: _bukaQr,
        ),
        ItemLayananHome(
          aset: 'ukur_data.png',
          cadangan: Icons.calendar_view_week_rounded,
          warna: const Color(0xFF0B6B55),
          judul: 'Ukur Data\nBB TB LiLA',
          onTap: _bukaAntrean,
        ),
        ItemLayananHome(
          aset: 'data_keluarga.png',
          cadangan: Icons.person_add_alt_1_outlined,
          warna: const Color(0xFF7C3AED),
          judul: 'Tambah Akun\nOrang Tua',
          onTap: _bukaKeluarga,
        ),
        ItemLayananHome(
          aset: 'pendaftaran.png',
          cadangan: Icons.how_to_reg_outlined,
          warna: const Color(0xFF0F766E),
          judul: 'Daftarkan\nAnak',
          onTap: _bukaDaftarkanAnak,
        ),
        ItemLayananHome(
          aset: 'semua_anak.png',
          cadangan: Icons.child_care,
          warna: const Color(0xFFEA580C),
          judul: 'Semua\nAnak',
          onTap: _bukaAnak,
        ),
        ItemLayananHome(
          aset: 'riwatar_pemeriksaan.png',
          cadangan: Icons.history,
          warna: const Color(0xFF0E8F7E),
          judul: 'Riwayat\nPemeriksaan',
          onTap: _bukaRiwayat,
        ),
        ItemLayananHome(
          aset: 'anak_tidak_hadir.png',
          cadangan: Icons.person_search_outlined,
          warna: const Color(0xFFB45309),
          judul: 'Anak\nTidak Hadir',
          onTap: _bukaTidakHadir,
        ),
        ItemLayananHome(
          aset: 'imunisasi_anak.png',
          cadangan: Icons.vaccines_outlined,
          warna: const Color(0xFF0B7FBF),
          judul: 'Imunisasi\nAnak',
          onTap: _bukaImunisasi,
        ),
      ],
    );
  }
}