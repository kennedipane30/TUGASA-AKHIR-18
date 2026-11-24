import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../service/vaksin_service.dart';

const _hijauTua = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi kotak di dalam kartu & field: hitam lembut.
const _garis = Color(0xFFB8BEC6);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = [
  BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 3)),
];

BoxDecoration _dekorKartu() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Kepala kartu: judul kapital tebal di kiri, keterangan di kanan, garis aksen di bawah.
Widget _kepala(String judul, {String? kanan, Color warnaKanan = _teksGelap}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                judul.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _teksGelap,
                ),
              ),
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(kanan,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: warnaKanan)),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Kartu putih berbayang: kepala + isi.
Widget _kartuIsi({
  required String judul,
  String? kanan,
  Color warnaKanan = _teksGelap,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    decoration: _dekorKartu(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kepala(judul, kanan: kanan, warnaKanan: warnaKanan),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ],
    ),
  );
}

/// Tautan kecil bergaris bawah.
Widget _tautan(String teks, {Color warna = _aksen}) => Text(
      teks,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: warna,
        decoration: TextDecoration.underline,
        decorationColor: warna,
      ),
    );

Widget _isiTombol(String label, IconData? ikon) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ikon != null) ...[Icon(ikon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

/// Tombol hijau penuh (tinggi 50, sudut 14).
Widget _tombolHijau(String label, {IconData? ikon, VoidCallback? onPressed}) => SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _hijauTua,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF7FAF9F),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        ),
        child: _isiTombol(label, ikon),
      ),
    );

/// Tombol bergaris (tinggi 50, sudut 14).
Widget _tombolGaris(String label, {IconData? ikon, VoidCallback? onPressed, Color warna = _hijauTua}) =>
    SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: warna,
          backgroundColor: Colors.white,
          side: BorderSide(color: warna, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        ),
        child: _isiTombol(label, ikon),
      ),
    );

/// Dekorasi field form: putih, garis tepi hitam lembut, ikon di depan.
InputDecoration _dekorForm(String label, IconData ikon, {String? hint}) {
  OutlineInputBorder garis(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Icon(ikon, color: _aksen),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: garis(_garis, 1.2),
    enabledBorder: garis(_garis, 1.2),
    focusedBorder: garis(_hijauTua, 1.6),
  );
}

/// Judul lembar bawah: kapital + garis aksen.
Widget _judulLembar(String teks) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(teks.toUpperCase(),
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _teksGelap)),
        const SizedBox(height: 8),
        Container(height: 3, color: _aksen),
      ],
    );

/// Tampilkan foto bukti vaksin (diambil lewat API agar memakai sesi login).
Future<void> tampilkanBuktiVaksin(BuildContext context, String nama) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _judulLembar('Foto Bukti Vaksin'),
            const SizedBox(height: 10),
            FutureBuilder<List<int>>(
              future: VaksinService().ambilBukti(nama),
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator());
                }
                if (snap.hasError || (snap.data ?? []).isEmpty) {
                  return const Padding(padding: EdgeInsets.all(24), child: Text('Foto tidak dapat dimuat.'));
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: InteractiveViewer(
                    child: Image.memory(Uint8List.fromList(snap.data!), fit: BoxFit.contain),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _tombolGaris('Tutup', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    ),
  );
}

/// Isi halaman vaksin anak (dipakai bidan, kader, sekretaris, dan orang tua).
/// Tab: Jadwal (dengan status) · Riwayat Vaksin · Suplemen.
/// [hanyaRiwayat] = true: tab Jadwal dan ringkasan jadwal disembunyikan, hanya vaksin
/// yang sudah diterima (riwayat) dan suplemen yang tampil (dipakai di halaman bidan).
/// [bisaKelola] = true untuk bidan: mencatat vaksin dari luar posyandu, membatalkan
/// catatan dari luar, dan menindaklanjuti reaksi setelah imunisasi (KIPI).
/// [bisaLaporKipi] = true untuk orang tua: melaporkan reaksi setelah imunisasi.
class VaksinLihatBody extends StatefulWidget {
  final String anakId;
  final bool bisaKelola;
  final bool bisaLaporKipi;
  final bool hanyaRiwayat;

  const VaksinLihatBody({
    super.key,
    required this.anakId,
    this.bisaKelola = false,
    this.bisaLaporKipi = false,
    this.hanyaRiwayat = false,
  });

  @override
  State<VaksinLihatBody> createState() => _VaksinLihatBodyState();
}

class _GayaStatus {
  final Color fg;
  final Color bg;
  final IconData ikon;
  const _GayaStatus(this.fg, this.bg, this.ikon);
}

const _abu = Color(0xFF6B7280);
const _abuMuda = Color(0xFFF1F2F4);

_GayaStatus _gaya(JadwalVaksinAnak e) {
  if (e.riwayat?.menungguKonfirmasi == true) {
    return const _GayaStatus(AppColors.kuning, AppColors.kuningMuda, Icons.pending_actions);
  }
  if (e.keFaskes && !e.sudah) {
    return const _GayaStatus(AppColors.merah, AppColors.merahMuda, Icons.local_hospital_outlined);
  }
  switch (e.status) {
    case StatusVaksin.sudah:
      return const _GayaStatus(AppColors.hijau, AppColors.hijauMuda, Icons.check_circle);
    case StatusVaksin.jatuhTempo:
      return const _GayaStatus(AppColors.biru, AppColors.biruMuda, Icons.vaccines);
    case StatusVaksin.terlambat:
      return const _GayaStatus(AppColors.merah, AppColors.merahMuda, Icons.warning_amber_rounded);
    case StatusVaksin.menunggu:
      return const _GayaStatus(AppColors.kuning, AppColors.kuningMuda, Icons.hourglass_top);
    case StatusVaksin.terlewat:
      return const _GayaStatus(_abu, _abuMuda, Icons.block);
    default:
      return const _GayaStatus(_abu, _abuMuda, Icons.schedule);
  }
}

/// Label status singkat untuk pil di daftar jadwal.
String _labelPil(JadwalVaksinAnak e) {
  if (e.riwayat?.menungguKonfirmasi == true) return 'Menunggu konfirmasi';
  if (e.sudah) return 'Sudah';
  if (e.keFaskes) return 'Ke puskesmas';
  switch (e.status) {
    case StatusVaksin.jatuhTempo:
      return 'Saatnya';
    case StatusVaksin.terlambat:
      return 'Susulan';
    case StatusVaksin.menunggu:
      return 'Menunggu dosis';
    case StatusVaksin.terlewat:
      return 'Terlewat';
  }
  return 'Belum waktunya';
}

class _VaksinLihatBodyState extends State<VaksinLihatBody> {
  final _svc = VaksinService();
  KartuVaksin? _kartu;
  bool _memuat = true;
  String? _gagal;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.hanyaRiwayat) _tab = 1; // langsung ke Riwayat
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = _kartu == null;
      _gagal = null;
    });
    try {
      final k = await _svc.kartuAnak(widget.anakId);
      if (!mounted) return;
      setState(() {
        _kartu = k;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = e.toString().replaceFirst('Exception: ', '');
        _memuat = false;
      });
    }
  }

  void _snack(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  // ===================================================================== build

  @override
  Widget build(BuildContext context) {
    if (_memuat) return const Center(child: CircularProgressIndicator());
    if (_kartu == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_gagal ?? 'Data vaksin tidak dapat dimuat',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16.5, color: _teksGelap)),
              const SizedBox(height: 12),
              _tombolHijau('Coba Lagi', ikon: Icons.refresh, onPressed: () {
                setState(() => _memuat = true);
                _muat();
              }),
            ],
          ),
        ),
      );
    }
    final k = _kartu!;
    return RefreshIndicator(
      onRefresh: _muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (!widget.hanyaRiwayat) _ringkasan(k),
          if (!k.anak.riwayatDikonfirmasi) ...[
            _infoRiwayatAwal(k),
            const SizedBox(height: 12),
          ],
          _pilihTab(k),
          const SizedBox(height: 14),
          if (widget.bisaKelola && _tab == 1) ...[
            _tombolGaris(
              'Catat Vaksin dari Luar Posyandu',
              ikon: Icons.add_circle_outline,
              onPressed: () => _formLuar(k),
            ),
            const SizedBox(height: 14),
          ],
          if (_tab == 0) ..._isiJadwal(k),
          if (_tab == 1) ..._isiRiwayat(k),
          if (_tab == 2) ..._isiSuplemen(k),
        ],
      ),
    );
  }

  // ================================================================= ringkasan

  static const _pemisah = Divider(height: 1, color: Color(0xFFE5E7EB));

  /// Baris ringkasan: keterangan di kiri, total di kanan.
  Widget _barisJumlah(String label, String nilai, {Color warna = _teksGelap, bool redup = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _teksGelap)),
          ),
          const SizedBox(width: 10),
          Text(nilai,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: redup ? AppColors.teksRedup : warna)),
        ],
      ),
    );
  }

  /// Status imunisasi: satu kartu, baris keterangan di kiri dan total di kanan.
  Widget _ringkasan(KartuVaksin k) {
    final r = k.ringkasan;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _dekorKartu(),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala('Status Imunisasi', kanan: '${r.persen}%', warnaKanan: _hijauTua),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                // Diurutkan dari yang paling perlu diperhatikan.
                _barisJumlah('Susulan', '${r.terlambat} dosis',
                    warna: AppColors.merah, redup: r.terlambat == 0),
                _pemisah,
                _barisJumlah('Saatnya diberikan', '${r.jatuhTempo} dosis',
                    warna: AppColors.biru, redup: r.jatuhTempo == 0),
                _pemisah,
                if (r.terlewat > 0) ...[
                  _barisJumlah('Lewat batas usia', '${r.terlewat} dosis', redup: true),
                  _pemisah,
                ],
                _barisJumlah('Imunisasi rutin diberikan', '${r.sudah} / ${r.totalDosis} dosis'),
                _pemisah,
                _barisJumlah('Riwayat vaksin', '${k.riwayat.length} vaksin'),
                _pemisah,
                _barisJumlah('Imunisasi dasar', r.dasarLengkap ? 'Lengkap' : 'Belum lengkap',
                    warna: r.dasarLengkap ? _hijauTua : AppColors.kuning),
                _pemisah,
                _barisJumlah('Imunisasi lanjutan', r.lanjutanLengkap ? 'Lengkap' : 'Belum lengkap',
                    warna: r.lanjutanLengkap ? _hijauTua : AppColors.teksRedup),
                _pemisah,
                _barisJumlah('Usia anak', k.anak.usiaTeks),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRiwayatAwal(KartuVaksin k) {
    final pesan = widget.bisaKelola
        ? 'Riwayat vaksin anak sebelum posyandu belum dicatat. Catat di halaman Catatan Bidan saat kunjungan pertama.'
        : 'Riwayat vaksin anak sebelum posyandu akan dicatat bidan saat kunjungan pertama. '
            'Bawa Buku KIA atau kartu vaksin anak.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kuningMuda,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _bayangan,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fact_check_outlined, size: 20, color: AppColors.kuning),
          const SizedBox(width: 8),
          Expanded(child: Text(pesan, style: const TextStyle(fontSize: 16, height: 1.35))),
        ],
      ),
    );
  }

  Widget _pilihTab(KartuVaksin k) {
    // Indeks tab asli (0 Jadwal, 1 Riwayat, 2 Suplemen) beserta labelnya.
    final tab = <(int, String)>[
      if (!widget.hanyaRiwayat) (0, 'Jadwal'),
      (1, 'Riwayat (${k.riwayat.length + k.vaksinMandiri.length})'),
      (2, 'Suplemen (${k.suplemen.length})'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _bayangan,
      ),
      child: Row(
        children: [
          for (final (i, teks) in tab)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == i ? _hijauTua : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    teks,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _tab == i ? Colors.white : _teksGelap,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kosong(IconData ikon, String teks) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: _dekorKartu(),
        child: Text(teks,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
      );

  // ==================================================================== jadwal

  List<Widget> _isiJadwal(KartuVaksin k) {
    if (k.jadwal.isEmpty) return [_kosong(Icons.event_busy, 'Jadwal imunisasi belum tersedia')];

    // kelompokkan per usia ideal (urutan dari server sudah berdasarkan usia)
    final grup = <String, List<JadwalVaksinAnak>>{};
    for (final e in k.jadwal) {
      grup.putIfAbsent(e.jadwal.labelUsia, () => []).add(e);
    }
    return [
      for (final g in grup.entries)
        _kartuIsi(
          judul: g.key == '< 24 jam' ? 'Baru lahir (< 24 jam)' : 'Usia ${g.key}',
          kanan: '${g.value.where((e) => e.sudah).length}/${g.value.length} dosis',
          warnaKanan: g.value.every((e) => e.sudah || e.opsional) ? _hijauTua : _teksGelap,
          child: Column(children: [for (final e in g.value) _barisJadwal(e)]),
        ),
    ];
  }

  String _subJadwal(JadwalVaksinAnak e) {
    final r = e.riwayat;
    if (r != null) {
      return 'Diberikan ${r.tanggal == null ? '-' : formatTanggal(r.tanggal!)} · usia ${r.usiaTeks}'
          '${r.tempat.isNotEmpty ? ' · ${r.tempat}' : ''}';
    }
    if (e.status == StatusVaksin.terlewat || (e.keFaskes && e.labelPosyandu.isEmpty)) return e.labelStatus;
    return e.teksJadwal;
  }

  Widget _barisJadwal(JadwalVaksinAnak e) {
    final g = _gaya(e);
    final tambahan = [
      if (e.jadwal.lanjutan) 'Lanjutan',
      if (e.opsional) 'Khusus daerah endemis',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _detailJadwal(e),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _garis, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.jadwal.namaDosis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, color: _teksGelap)),
                const SizedBox(height: 2),
                Text(_subJadwal(e),
                    style: const TextStyle(fontSize: 15.5, height: 1.35, color: Color(0xFF374151))),
                if (tambahan.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tambahan,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _aksen)),
                ],
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(_labelPil(e),
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: g.fg)),
                    ),
                    _tautan('Lihat detail'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Baris "Label : nilai" (hitam tebal, nilai lanjut ke samping).
  Widget _info(String label, String nilai) {
    if (nilai.trim().isEmpty) return const SizedBox.shrink();
    const gaya = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: _teksGelap);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: gaya)),
          const Text(': ', style: gaya),
          Expanded(child: Text(nilai, style: gaya)),
        ],
      ),
    );
  }

  void _detailJadwal(JadwalVaksinAnak e) {
    final j = e.jadwal;
    final r = e.riwayat;
    final g = _gaya(e);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: _garis, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              _judulLembar(j.namaDosis),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(g.ikon, size: 20, color: g.fg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e.labelStatus,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: g.fg)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _info('Mencegah', j.jenis.penyakit),
              _info('Cara pemberian', j.jenis.caraPemberian),
              _info('Usia pemberian', j.labelUsia),
              _info('Kelompok', j.lanjutan ? 'Imunisasi lanjutan' : 'Imunisasi dasar'),
              if (j.usiaMaksBulan != null)
                _info('Batas usia', j.usiaMaksBulan == 0 ? 'Usia 7 hari' : '${j.usiaMaksBulan} bulan'),
              if (j.jarakMinimalHari != null) _info('Jarak minimal', '${j.jarakMinimalHari} hari dari dosis sebelumnya'),
              if (r == null && e.status != StatusVaksin.terlewat) _info('Jadwal', e.teksJadwal),
              _info('Keterangan', j.keterangan),
              if (r != null) ...[
                const SizedBox(height: 10),
                _judulLembar('Riwayat Pemberian'),
                const SizedBox(height: 10),
                ..._isiDetailRiwayat(r),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _isiDetailRiwayat(RiwayatVaksin r) => [
        _info('Tanggal', r.tanggal == null ? '-' : formatTanggal(r.tanggal!)),
        _info('Usia saat diberikan', r.usiaTeks),
        _info('Tempat', r.tempat),
        _info('Sumber data', r.labelSumber),
        _info('Diberikan oleh', r.namaPemberi),
        _info('Nomor batch', r.nomorBatch),
        _info('Kondisi anak', KondisiImunisasi.label(r.kondisiAnak)),
        _info('Catatan', r.catatan),
      ];

  // =================================================================== riwayat

  List<Widget> _isiRiwayat(KartuVaksin k) {
    if (k.riwayat.isEmpty && k.vaksinMandiri.isEmpty) {
      return [_kosong(Icons.vaccines_outlined, 'Belum ada riwayat vaksin')];
    }
    return [
      for (final r in k.riwayat) _kartuRiwayat(r),
      if (k.vaksinMandiri.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text('VAKSIN MANDIRI (DI LUAR PROGRAM)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _teksGelap)),
        ),
        for (final v in k.vaksinMandiri) _kartuVaksinMandiri(v),
      ],
    ];
  }

  Widget _kartuVaksinMandiri(VaksinMandiri v) {
    return _kartuIsi(
      judul: v.namaDosis,
      kanan: v.tanggal == null ? '-' : formatTanggal(v.tanggal!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info('Usia', v.usiaTeks),
          _info('Tempat', v.tempat),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 14,
            runSpacing: 4,
            children: [
              if (v.fotoBukti.isNotEmpty)
                InkWell(
                  onTap: () => tampilkanBuktiVaksin(context, v.fotoBukti),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _tautan('Lihat foto bukti'),
                  ),
                ),
              if (widget.bisaKelola)
                InkWell(
                  onTap: () => _hapusMandiri(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _tautan('Hapus catatan', warna: AppColors.merah),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _hapusMandiri(VaksinMandiri v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus catatan vaksin mandiri?'),
        content: Text('${v.namaDosis} '
            '(${v.tanggal == null ? '-' : formatTanggal(v.tanggal!)}) akan dihapus dari riwayat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.merah)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.hapusVaksinMandiri(v.id);
      _snack('Catatan vaksin mandiri dihapus');
      await _muat();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  bool _dalam30Hari(RiwayatVaksin r) {
    final t = r.tanggal;
    if (t == null) return false;
    return DateTime.now().difference(t).inDays <= 30;
  }

  Widget _kartuRiwayat(RiwayatVaksin r) {
    final adaReaksi = r.reaksiKipi.isNotEmpty;
    return _kartuIsi(
      judul: r.namaDosis,
      kanan: r.tanggal == null ? '-' : formatTanggal(r.tanggal!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.menungguKonfirmasi)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Menunggu konfirmasi bidan',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.kuning)),
            ),
          _info('Usia', r.usiaTeks),
          _info('Tempat', r.tempat.isEmpty ? r.labelSumber : r.tempat),
          _info(r.dariPosyandu ? 'Diberikan oleh' : 'Petugas', r.namaPemberi),
          _info('Nomor batch', r.nomorBatch),
          _info('Kondisi anak', r.kondisiAnak.isEmpty ? '' : KondisiImunisasi.label(r.kondisiAnak)),
          _info('Catatan', r.catatan),
          if (adaReaksi) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.merah.withValues(alpha: 0.6), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reaksi setelah imunisasi',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.merah)),
                  const SizedBox(height: 2),
                  Text(r.reaksiKipi,
                      style: const TextStyle(fontSize: 16, height: 1.35, color: _teksGelap)),
                  const SizedBox(height: 6),
                  Text(
                    r.kipiTindakLanjut.isEmpty
                        ? 'Menunggu tindak lanjut bidan'
                        : 'Tindak lanjut bidan: ${r.kipiTindakLanjut}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: r.kipiTindakLanjut.isEmpty ? AppColors.kuning : _hijauTua,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 14,
            runSpacing: 4,
            children: [
              if (r.fotoBukti.isNotEmpty)
                InkWell(
                  onTap: () => tampilkanBuktiVaksin(context, r.fotoBukti),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _tautan('Lihat foto bukti'),
                  ),
                ),
              if (widget.bisaLaporKipi && !adaReaksi && _dalam30Hari(r))
                InkWell(
                  onTap: () => _laporKipi(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _tautan('Laporkan reaksi', warna: AppColors.merah),
                  ),
                ),
              if (widget.bisaKelola && (adaReaksi || _dalam30Hari(r)))
                InkWell(
                  onTap: () => _tindakLanjut(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _tautan(adaReaksi ? 'Isi tindak lanjut' : 'Catat reaksi'),
                  ),
                ),
              if (widget.bisaKelola && r.dariLuar)
                InkWell(
                  onTap: () => _hapus(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _tautan('Batalkan catatan', warna: AppColors.merah),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _hapus(RiwayatVaksin r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan catatan vaksin?'),
        content: Text('${r.namaDosis} '
            '(${r.tanggal == null ? '-' : formatTanggal(r.tanggal!)}) akan dihapus dari riwayat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.merah)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.hapusRiwayat(r.id);
      _snack('Catatan vaksin dihapus');
      await _muat();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<String?> _isian({
    required String judul,
    required String keterangan,
    required String label,
    String awal = '',
    String? label2,
    String awal2 = '',
    void Function(String)? simpanKedua,
  }) async {
    final c1 = TextEditingController(text: awal);
    final c2 = TextEditingController(text: awal2);
    final hasil = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _judulLembar(judul),
            const SizedBox(height: 10),
            Text(keterangan, style: const TextStyle(fontSize: 16, color: AppColors.teksRedup, height: 1.35)),
            const SizedBox(height: 12),
            if (label2 != null) ...[
              TextField(
                controller: c2,
                maxLines: 2,
                maxLength: 500,
                decoration: _dekorForm(label2, Icons.sick_outlined),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: c1,
              maxLines: 3,
              maxLength: 500,
              autofocus: true,
              decoration: _dekorForm(label, Icons.edit_note_outlined),
            ),
            const SizedBox(height: 10),
            _tombolHijau('Kirim', ikon: Icons.send_outlined, onPressed: () {
              if (c1.text.trim().isEmpty) return;
              simpanKedua?.call(c2.text.trim());
              Navigator.pop(ctx, c1.text.trim());
            }),
          ],
        ),
      ),
    );
    c1.dispose();
    c2.dispose();
    return hasil;
  }

  Future<void> _laporKipi(RiwayatVaksin r) async {
    final reaksi = await _isian(
      judul: 'Laporkan Reaksi Setelah Imunisasi',
      keterangan: 'Ceritakan reaksi yang dialami anak setelah ${r.namaDosis}, misalnya demam, bengkak, '
          'kemerahan, atau rewel terus-menerus. Laporan dikirim ke bidan. Bila anak kejang, sesak napas, '
          'atau tidak sadar, segera bawa ke puskesmas atau IGD terdekat.',
      label: 'Reaksi yang dialami anak',
    );
    if (reaksi == null || reaksi.isEmpty) return;
    try {
      await _svc.laporKipi(r.id, reaksi);
      _snack('Laporan terkirim ke bidan');
      await _muat();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _tindakLanjut(RiwayatVaksin r) async {
    var reaksi = r.reaksiKipi;
    final tindak = await _isian(
      judul: 'Reaksi Setelah Imunisasi',
      keterangan: r.namaDosis,
      label: 'Tindak lanjut bidan',
      awal: r.kipiTindakLanjut,
      label2: 'Reaksi yang dialami anak',
      awal2: r.reaksiKipi,
      simpanKedua: (v) => reaksi = v,
    );
    if (tindak == null || tindak.isEmpty) return;
    try {
      await _svc.tindakLanjutKipi(r.id, reaksi: reaksi, tindakLanjut: tindak);
      _snack('Tindak lanjut tersimpan');
      await _muat();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ================================================================== suplemen

  List<Widget> _isiSuplemen(KartuVaksin k) {
    if (k.suplemen.isEmpty) return [_kosong(Icons.medication_outlined, 'Belum ada riwayat suplemen')];
    return [
      for (final s in k.suplemen)
        _kartuIsi(
          judul: s.nama,
          kanan: s.tanggal == null ? '-' : formatTanggal(s.tanggal!),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _info('Usia', s.usiaTeks),
              _info('Dosis', s.ringkasDosis),
              _info('Catatan', s.catatan),
              _info('Diberikan oleh', s.namaPemberi),
            ],
          ),
        ),
    ];
  }

  // ============================================================ vaksin dari luar

  Future<void> _formLuar(KartuVaksin k) async {
    final opsi = k.jadwal
        .where((e) => !e.sudah && !e.opsional && e.status != StatusVaksin.terlewat && e.status != StatusVaksin.menunggu)
        .toList();
    if (opsi.isEmpty) {
      _snack('Tidak ada dosis yang dapat dicatat');
      return;
    }
    final tersimpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormLuar(anakId: k.anak.id, lahir: k.anak.tanggalLahir, opsi: opsi, svc: _svc),
    );
    if (tersimpan == true) {
      _snack('Vaksin dari luar posyandu tercatat');
      await _muat();
    }
  }
}

/// Bidan mencatat vaksin yang diberikan di luar posyandu berdasarkan keterangan orang tua.
class _FormLuar extends StatefulWidget {
  final String anakId;
  final DateTime? lahir;
  final List<JadwalVaksinAnak> opsi;
  final VaksinService svc;

  const _FormLuar({required this.anakId, required this.lahir, required this.opsi, required this.svc});

  @override
  State<_FormLuar> createState() => _FormLuarState();
}

class _FormLuarState extends State<_FormLuar> {
  String? _kunci;
  DateTime? _tanggal;
  final _tempat = TextEditingController();
  final _batch = TextEditingController();
  final _pemberi = TextEditingController();
  final _catatan = TextEditingController();
  bool _kirim = false;
  String? _gagal;

  @override
  void dispose() {
    _tempat.dispose();
    _batch.dispose();
    _pemberi.dispose();
    _catatan.dispose();
    super.dispose();
  }

  JadwalVaksinAnak? get _dipilih {
    for (final e in widget.opsi) {
      if (e.jadwal.kunci == _kunci) return e;
    }
    return null;
  }

  InputDecoration _dekor(String label, IconData ikon, {String? hint}) =>
      _dekorForm(label, ikon, hint: hint);

  Future<void> _pilihTanggal() async {
    final n = DateTime.now();
    final hari = DateTime(n.year, n.month, n.day);
    final awal = widget.lahir ?? DateTime(n.year - 6);
    final t = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? hari,
      firstDate: awal,
      lastDate: hari,
    );
    if (t != null) setState(() => _tanggal = t);
  }

  Future<void> _simpan() async {
    final d = _dipilih;
    if (d == null || _tanggal == null || _tempat.text.trim().isEmpty) {
      setState(() => _gagal = 'Pilih vaksin, tanggal, dan isi tempat pemberian');
      return;
    }
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan vaksin dari luar?'),
        content: Text(
          'Pastikan orang tua menyatakan ${d.jadwal.namaDosis} benar sudah diberikan pada '
          '${formatTanggal(_tanggal!)} di ${_tempat.text.trim()}. Vaksin ini tidak akan diberikan lagi di posyandu.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Periksa lagi')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, simpan')),
        ],
      ),
    );
    if (ya != true) return;
    setState(() {
      _kirim = true;
      _gagal = null;
    });
    try {
      await widget.svc.catatRiwayat(
        anakId: widget.anakId,
        jenisVaksinId: d.jadwal.jenis.id,
        dosisKe: d.jadwal.dosisKe,
        tanggal: _tanggal!,
        tempat: _tempat.text.trim(),
        nomorBatch: _batch.text.trim(),
        pemberiLuar: _pemberi.text.trim(),
        catatan: _catatan.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kirim = false;
        _gagal = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lahir = widget.lahir;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _judulLembar('Catat Vaksin dari Luar Posyandu'),
              const SizedBox(height: 10),
              const Text(
                'Isi sesuai keterangan orang tua untuk vaksin yang diberikan di rumah sakit, puskesmas, klinik, atau bidan praktik.',
                style: TextStyle(fontSize: 16, color: AppColors.teksRedup),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _kunci,
                isExpanded: true,
                decoration: _dekor('Vaksin & dosis', Icons.vaccines_outlined),
                items: [
                  for (final e in widget.opsi)
                    DropdownMenuItem(
                      value: e.jadwal.kunci,
                      child: Text('${e.jadwal.namaDosis} (${e.jadwal.labelUsia})', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _kunci = v),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pilihTanggal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _garis, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 22, color: _aksen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _tanggal == null ? 'Pilih tanggal pemberian' : 'Tanggal pemberian: ${formatTanggal(_tanggal!)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _teksGelap),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (lahir != null && _tanggal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text('Usia anak saat itu: ${usiaDariLahir(lahir, _tanggal!)}',
                      style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _tempat,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: _dekor('Tempat pemberian', Icons.location_on_outlined, hint: 'Mis. Puskesmas Balige'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _batch, maxLength: 50, decoration: _dekor('Nomor batch (opsional)', Icons.qr_code_2)),
              const SizedBox(height: 10),
              TextField(
                controller: _pemberi,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: _dekor('Nama petugas pemberi (opsional)', Icons.person_outline),
              ),
              const SizedBox(height: 10),
              TextField(controller: _catatan, maxLines: 2, decoration: _dekor('Catatan (opsional)', Icons.notes_outlined)),
              if (_gagal != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.merahMuda, borderRadius: BorderRadius.circular(10)),
                  child: Text(_gagal!, style: const TextStyle(fontSize: 16, color: AppColors.merah)),
                ),
              ],
              const SizedBox(height: 16),
              _tombolHijau(
                _kirim ? 'Menyimpan...' : 'Simpan',
                ikon: Icons.save_outlined,
                onPressed: _kirim ? null : _simpan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}