import 'dart:math' as math;

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
import 'vaksin/vaksin_page.dart';

const _hijauTua = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);
const _teksAbu = Color(0xFF64748B);
const _aset = '';

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Garis pemisah lembut.
const _garisLembut = Color(0xFFE5E7EB);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = [
  BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 3)),
];

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

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrangTuaVaksinPage()),
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

  Widget _sapaan(String nama) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
      child: Text(
        'Hi, $nama',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 21,
          height: 1.2,
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final pos = (user?['posyandu'] ?? '').toString();
    final lokasi = pos.isEmpty
        ? 'Posyandu belum ditetapkan, hubungi admin'
        : 'Posyandu ${labelPosyandu(pos)}';

    return HomeShell(
      peran: 'Orang Tua',
      lokasi: lokasi,
      notif: 2,
      children: [
        _sapaan(_namaSapaan(user)),
        if (_memuat)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_gagal != null)
          _kartuGagal()
        else if (_daftar.isEmpty)
          _kartuBelumAdaAnak()
        else ...[
          KartuPeringatanGizi(
            key: _kunciGizi,
            onLihat: _bukaPemeriksaanAnak,
          ),
          _jadwalPosyandu(),
          _layananPosyandu(),
        ],
      ],
    );
  }

  Widget _kartuGagal() {
    return SectionCard(
      color: AppColors.kuningMuda,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.kuning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _gagal!,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15.5,
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
    );
  }

  Widget _kartuBelumAdaAnak() {
    return SectionCard(
      title: 'Data Anak',
      icon: Icons.child_care,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Belum ada data anak. Lengkapi data keluarga terlebih dahulu.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.teksRedup,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              'Lengkapi Data Keluarga',
              icon: Icons.family_restroom,
              onPressed: _bukaDataKeluarga,
            ),
          ),
        ],
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
  // KARTU JADWAL POSYANDU TERDEKAT (putih berbayang, rapi dan ringkas)
  // -------------------------------------------------------------------------
  Widget _kartuJadwal({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// Kepala kartu: label kecil + judul, keterangan di kanan, garis aksen di bawah.
  Widget _kepalaJadwal({required String judul, String? sub, String? kanan, Color warnaKanan = _hijauTua}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('JADWAL POSYANDU',
                        style: TextStyle(
                            fontSize: 13.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: _aksen)),
                    const SizedBox(height: 4),
                    Text(judul.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 18,
                            height: 1.2,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w700,
                            color: _teksGelap)),
                    if (sub != null && sub.isNotEmpty)
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
                  ],
                ),
              ),
              if (kanan != null && kanan.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(kanan,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: warnaKanan)),
              ],
            ],
          ),
        ),
        Container(height: 3, color: _aksen),
      ],
    );
  }

  /// Baris keterangan: ikon kecil + "Label : nilai" (nilai lanjut ke samping).
  Widget _barisKet(IconData ikon, String label, String nilai, {Color? warnaNilai}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(ikon, size: 18, color: _aksen),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label : ',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _teksGelap),
                  ),
                  TextSpan(
                    text: nilai.isEmpty ? '-' : nilai,
                    style: TextStyle(
                      fontWeight: warnaNilai == null ? FontWeight.w500 : FontWeight.w700,
                      color: warnaNilai ?? const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 15.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Pemilih anak: nama anak (kapital) + panah bila anak lebih dari satu.
  Widget _pilihAnak() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _daftar.length > 1 ? _pilihAnakSheet : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Flexible(
              child: Text(
                _kapital(_anak?.nama ?? '-'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: _teksGelap,
                ),
              ),
            ),
            if (_daftar.length > 1) ...[
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _hijauTua, size: 22),
            ],
          ],
        ),
      ),
    );
  }

  /// Tombol utama kartu jadwal (mengikuti anak yang dipilih):
  ///  - belum daftar   : "Buka Pendaftaran & Check-in" -> halaman pendaftaran
  ///  - terdaftar      : "Scan Sekarang"   -> kamera scan QR -> halaman nomor antrean
  ///  - sudah check-in : "Nomor Antrean"   -> halaman nomor antrean
  ///  - selesai dilayani (bidan sudah mencatat): "Lihat Hasil Pemeriksaan"
  Widget _tombolDaftar() {
    final terdaftar = _hadir == 'terdaftar';
    final sudahCheckin = _hadir == 'sudah_checkin';
    final selesai = _statusAnak?.selesai ?? false;
    final (String label, IconData? ikon, VoidCallback aksi) = terdaftar
        ? ('Scan Sekarang', Icons.qr_code_scanner, _scanSekarang)
        : selesai
            ? ('Lihat Hasil Pemeriksaan', Icons.fact_check_outlined, _bukaHasilSelesai)
            : sudahCheckin
                ? ('Nomor Antrean', Icons.confirmation_number_outlined, _bukaNomorAntrean)
                : ('Buka Pendaftaran & Check-in', null, _bukaPendaftaran);
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: aksi,
        style: ElevatedButton.styleFrom(
          backgroundColor: _hijauTua,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              Icon(ikon, size: 21),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _jadwalPosyandu() {
    final j = _jadwal;
    final pos = (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();
    final (labelStatus, _, _) = labelStatusHadir(_statusAnak?.statusTampil ?? _hadir);
    final belumDaftar = _hadir == 'belum_daftar';

    if (j == null) {
      return _kartuJadwal(
        children: [
          _kepalaJadwal(judul: 'Belum ada jadwal'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(
              pos.isEmpty
                  ? 'Belum ada jadwal posyandu mendatang.'
                  : 'Belum ada jadwal mendatang untuk Posyandu ${labelPosyandu(pos)}.',
              style: const TextStyle(fontSize: 15.5, height: 1.4, color: _teksAbu),
            ),
          ),
        ],
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

    return _kartuJadwal(
      children: [
        _kepalaJadwal(
          judul: hari,
          sub: formatTanggal(j.tanggal),
          kanan: hitung,
          warnaKanan: selisih <= 0 ? _hijauTua : _aksen,
        ),

        // Nama anak yang dipilih + status pendaftaran
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pilihAnak(),
              const SizedBox(height: 2),
              Text(
                labelStatus,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: belumDaftar ? AppColors.merah : _hijauTua,
                ),
              ),
            ],
          ),
        ),

        // Waktu & lokasi
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _garisLembut)),
          ),
          child: Column(
            children: [
              _barisKet(Icons.schedule, 'Waktu', jam.isEmpty ? '' : '$jam WIB'),
              if (lokasi.isNotEmpty) _barisKet(Icons.location_on_outlined, 'Lokasi', lokasi),
              if (j.checkinBuka != null)
                _barisKet(Icons.qr_code_scanner, 'Scan QR', 'dibuka pukul ${formatJam(j.checkinBuka!)}'),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: _tombolDaftar(),
        ),
      ],
    );
  }

  Widget _layananPosyandu() {
    final menu = <(String, IconData, String, Color, VoidCallback)>[
      (
        '${_aset}pendaftaran.png',
        Icons.person_add_alt_1_rounded,
        'Pendaftaran\nPosyandu',
        const Color(0xFF0B6B55),
        _bukaPendaftaran,
      ),
      (
        '${_aset}hasil_pemeriksaan.png',
        Icons.assignment_rounded,
        'Hasil\nPemeriksaan',
        const Color(0xFF0369A1),
        _bukaPemeriksaan,
      ),
      (
        '${_aset}grafik_anak.png',
        Icons.show_chart_rounded,
        'Grafik\nAnak',
        const Color(0xFF0B6B55),
        _bukaGrafik,
      ),
      (
        '${_aset}vaksin_anak.png',
        Icons.vaccines_rounded,
        'Vaksin\nAnak',
        const Color(0xFF2563EB),
        _bukaVaksin,
      ),
      (
        '${_aset}rujukan_anak.png',
        Icons.description_rounded,
        'Rujukan\nAnak',
        const Color(0xFFB45309),
        _bukaRujukan,
      ),
      (
        '${_aset}buku_panduan.png',
        Icons.menu_book_rounded,
        'Buku\nPanduan',
        const Color(0xFF2563EB),
        _bukaBukuPanduan,
      ),
      (
        '${_aset}data_keluarga.png',
        Icons.family_restroom_rounded,
        'Data\nKeluarga',
        const Color(0xFF0B6B55),
        _bukaDataKeluarga,
      ),
    ];

    Widget item((String, IconData, String, Color, VoidCallback) m) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: m.$5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Image.asset(
                    m.$1,
                    width: 52,
                    height: 52,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Icon(
                      m.$2,
                      color: m.$4,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      m.$3,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        color: Color(0xFF0F2547),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final baris = <Widget>[];
    for (var i = 0; i < menu.length; i += 4) {
      final potong = menu.sublist(i, math.min(i + 4, menu.length));
      baris.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in potong) item(m),
              for (var k = potong.length; k < 4; k++)
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Layanan Posyandu',
                    style: TextStyle(
                      fontSize: 21,
                      height: 1.2,
                      color: _teksGelap,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...baris,
        ],
      ),
    );
  }
}