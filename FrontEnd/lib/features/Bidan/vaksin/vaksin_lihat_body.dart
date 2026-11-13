import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../service/vaksin_service.dart';

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
            const Text('Foto Bukti Vaksin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
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
            SizedBox(
              width: double.infinity,
              child: AppButton('Tutup', filled: false, onPressed: () => Navigator.pop(ctx)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Isi halaman vaksin anak (dipakai bidan, kader, sekretaris, dan orang tua).
/// Tab: Jadwal (dengan status) · Riwayat Vaksin · Suplemen.
/// [bisaKelola] = true untuk bidan: mencatat vaksin dari luar posyandu, membatalkan
/// catatan dari luar, dan menindaklanjuti reaksi setelah imunisasi (KIPI).
/// [bisaLaporKipi] = true untuk orang tua: melaporkan reaksi setelah imunisasi.
class VaksinLihatBody extends StatefulWidget {
  final String anakId;
  final bool bisaKelola;
  final bool bisaLaporKipi;

  const VaksinLihatBody({
    super.key,
    required this.anakId,
    this.bisaKelola = false,
    this.bisaLaporKipi = false,
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
              const Icon(Icons.cloud_off, size: 40, color: AppColors.teksRedup),
              const SizedBox(height: 10),
              Text(_gagal ?? 'Data vaksin tidak dapat dimuat',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 16.5)),
              const SizedBox(height: 12),
              AppButton('Coba Lagi', icon: Icons.refresh, onPressed: () {
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
          _ringkasan(k),
          if (!k.anak.riwayatDikonfirmasi) ...[
            const SizedBox(height: 4),
            _infoRiwayatAwal(k),
          ],
          const SizedBox(height: 12),
          _pilihTab(k),
          const SizedBox(height: 12),
          if (widget.bisaKelola && _tab == 1) ...[
            SizedBox(
              width: double.infinity,
              child: AppButton(
                'Catat Vaksin dari Luar Posyandu',
                icon: Icons.add_circle_outline,
                filled: false,
                onPressed: () => _formLuar(k),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_tab == 0) ..._isiJadwal(k),
          if (_tab == 1) ..._isiRiwayat(k),
          if (_tab == 2) ..._isiSuplemen(k),
        ],
      ),
    );
  }

  // ================================================================= ringkasan

  Widget _ringkasan(KartuVaksin k) {
    final r = k.ringkasan;
    return SectionCard(
      title: 'Status Imunisasi',
      icon: Icons.verified_user_outlined,
      trailing: Pill('Usia ${k.anak.usiaTeks}', bg: AppColors.biruMuda, fg: AppColors.biru),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${r.persen}%',
                  style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, color: AppColors.hijau)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${r.sudah} dari ${r.totalDosis} dosis imunisasi rutin sudah diberikan',
                    style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: r.totalDosis == 0 ? 0 : r.sudah / r.totalDosis,
              minHeight: 9,
              backgroundColor: AppColors.latar,
              color: AppColors.hijau,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatBox(
                    nilai: '${r.jatuhTempo}', label: 'Saatnya\nDiberikan', bg: AppColors.biruMuda, fg: AppColors.biru),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: StatBox(nilai: '${r.terlambat}', label: 'Susulan', bg: AppColors.merahMuda, fg: AppColors.merah),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: StatBox(
                    nilai: '${k.riwayat.length}', label: 'Riwayat\nVaksin', bg: AppColors.hijauMuda, fg: AppColors.hijau),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              r.dasarLengkap
                  ? const Pill('Imunisasi dasar lengkap', bg: AppColors.hijauMuda, fg: AppColors.hijau)
                  : const Pill('Imunisasi dasar belum lengkap', bg: AppColors.kuningMuda, fg: AppColors.kuning),
              if (r.lanjutanLengkap)
                const Pill('Imunisasi lanjutan lengkap', bg: AppColors.hijauMuda, fg: AppColors.hijau),
              if (r.terlewat > 0) Pill('${r.terlewat} dosis lewat batas usia', bg: _abuMuda, fg: _abu),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRiwayatAwal(KartuVaksin k) {
    final pesan = widget.bisaKelola
        ? 'Riwayat vaksin anak belum dikonfirmasi. Konfirmasi dilakukan di halaman Catatan Bidan saat posyandu.'
        : 'Riwayat vaksin: ${StatusRiwayatVaksin.label(k.anak.statusRiwayatVaksin)}.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.kuningMuda, borderRadius: BorderRadius.circular(12)),
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
    final label = ['Jadwal', 'Riwayat (${k.riwayat.length})', 'Suplemen (${k.suplemen.length})'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < label.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == i ? AppColors.hijau : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _tab == i ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kosong(IconData ikon, String teks) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(ikon, size: 40, color: AppColors.teksRedup),
            const SizedBox(height: 8),
            Text(teks, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
          ],
        ),
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
        SectionCard(
          title: g.key == '< 24 jam' ? 'Baru lahir (< 24 jam)' : 'Usia ${g.key}',
          icon: Icons.event_note_outlined,
          trailing: Pill(
            '${g.value.where((e) => e.sudah).length}/${g.value.length}',
            bg: g.value.every((e) => e.sudah || e.opsional) ? AppColors.hijauMuda : AppColors.latar,
            fg: g.value.every((e) => e.sudah || e.opsional) ? AppColors.hijau : Colors.black87,
          ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _detailJadwal(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.jadwal.namaDosis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              const SizedBox(height: 2),
              Text(_subJadwal(e), style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (e.jadwal.lanjutan) const Pill('Lanjutan', bg: AppColors.biruMuda, fg: AppColors.biru),
                  if (e.opsional) const Pill('Khusus daerah endemis', bg: _abuMuda, fg: _abu),
                  Pill(_labelPil(e), bg: g.bg, fg: g.fg),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String nilai) {
    if (nilai.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
          ),
          Expanded(child: Text(nilai, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
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
                  decoration: BoxDecoration(color: _abuMuda, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(g.ikon, color: g.fg),
                  const SizedBox(width: 8),
                  Expanded(child: Text(j.namaDosis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 6),
              Pill(e.labelStatus, bg: g.bg, fg: g.fg),
              const SizedBox(height: 14),
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
                const Divider(height: 24),
                const Text('Riwayat Pemberian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
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
    if (k.riwayat.isEmpty) return [_kosong(Icons.vaccines_outlined, 'Belum ada riwayat vaksin')];
    return [for (final r in k.riwayat) _kartuRiwayat(r)];
  }

  bool _dalam30Hari(RiwayatVaksin r) {
    final t = r.tanggal;
    if (t == null) return false;
    return DateTime.now().difference(t).inDays <= 30;
  }

  Widget _kartuRiwayat(RiwayatVaksin r) {
    final adaReaksi = r.reaksiKipi.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: r.menungguKonfirmasi ? AppColors.kuning : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: AppColors.hijauMuda, shape: BoxShape.circle),
                child: const Icon(Icons.vaccines, size: 20, color: AppColors.hijau),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.namaDosis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(r.tanggal == null ? '-' : formatTanggal(r.tanggal!),
                        style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              if (widget.bisaKelola && r.dariLuar)
                IconButton(
                  tooltip: 'Batalkan catatan',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _hapus(r),
                  icon: const Icon(Icons.delete_outline, color: AppColors.merah),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill('Usia ${r.usiaTeks}', bg: AppColors.biruMuda, fg: AppColors.biru),
              Pill(r.tempat.isEmpty ? r.labelSumber : r.tempat,
                  bg: r.dariPosyandu ? AppColors.hijauMuda : AppColors.kuningMuda,
                  fg: r.dariPosyandu ? AppColors.hijau : AppColors.kuning),
              if (r.menungguKonfirmasi)
                const Pill('Menunggu konfirmasi bidan', bg: AppColors.kuningMuda, fg: AppColors.kuning),
            ],
          ),
          const SizedBox(height: 8),
          if (r.namaPemberi.isNotEmpty)
            Text('${r.dariPosyandu ? 'Diberikan oleh' : 'Petugas'}: ${r.namaPemberi}', style: const TextStyle(fontSize: 16)),
          if (r.nomorBatch.isNotEmpty) Text('Nomor batch: ${r.nomorBatch}', style: const TextStyle(fontSize: 16)),
          if (r.kondisiAnak.isNotEmpty)
            Text('Kondisi anak: ${KondisiImunisasi.label(r.kondisiAnak)}', style: const TextStyle(fontSize: 16)),
          if (r.catatan.isNotEmpty) Text('Catatan: ${r.catatan}', style: const TextStyle(fontSize: 16)),
          if (r.fotoBukti.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => tampilkanBuktiVaksin(context, r.fotoBukti),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Lihat foto bukti'),
              ),
            ),
          if (adaReaksi) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.merahMuda, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reaksi setelah imunisasi',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.merah)),
                  const SizedBox(height: 2),
                  Text(r.reaksiKipi, style: const TextStyle(fontSize: 16, height: 1.35)),
                  const SizedBox(height: 6),
                  Text(
                    r.kipiTindakLanjut.isEmpty ? 'Menunggu tindak lanjut bidan' : 'Tindak lanjut bidan: ${r.kipiTindakLanjut}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: r.kipiTindakLanjut.isEmpty ? AppColors.kuning : AppColors.hijau,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.bisaLaporKipi && !adaReaksi && _dalam30Hari(r)) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _laporKipi(r),
                icon: const Icon(Icons.report_problem_outlined, size: 18, color: AppColors.merah),
                label: const Text('Laporkan reaksi setelah imunisasi', style: TextStyle(color: AppColors.merah)),
              ),
            ),
          ],
          if (widget.bisaKelola && (adaReaksi || _dalam30Hari(r))) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _tindakLanjut(r),
                icon: const Icon(Icons.healing_outlined, size: 18),
                label: Text(adaReaksi ? 'Isi tindak lanjut reaksi' : 'Catat reaksi setelah imunisasi'),
              ),
            ),
          ],
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
            Text(judul, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(keterangan, style: const TextStyle(fontSize: 16, color: AppColors.teksRedup, height: 1.35)),
            const SizedBox(height: 12),
            if (label2 != null) ...[
              TextField(
                controller: c2,
                maxLines: 2,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: label2,
                  filled: true,
                  fillColor: AppColors.latar,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: c1,
              maxLines: 3,
              maxLength: 500,
              autofocus: true,
              decoration: InputDecoration(
                labelText: label,
                filled: true,
                fillColor: AppColors.latar,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: AppButton('Kirim', icon: Icons.send_outlined, onPressed: () {
                if (c1.text.trim().isEmpty) return;
                simpanKedua?.call(c2.text.trim());
                Navigator.pop(ctx, c1.text.trim());
              }),
            ),
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
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: AppColors.kuningMuda, shape: BoxShape.circle),
                child: const Icon(Icons.medication, size: 20, color: AppColors.kuning),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(
                      '${s.tanggal == null ? '-' : formatTanggal(s.tanggal!)} · usia ${s.usiaTeks}',
                      style: const TextStyle(fontSize: 16, color: AppColors.teksRedup),
                    ),
                    if (s.ringkasDosis.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Pill(s.ringkasDosis, bg: AppColors.kuningMuda, fg: AppColors.kuning),
                    ],
                    if (s.catatan.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Catatan: ${s.catatan}', style: const TextStyle(fontSize: 16)),
                    ],
                    if (s.namaPemberi.isNotEmpty)
                      Text('Diberikan oleh: ${s.namaPemberi}',
                          style: const TextStyle(fontSize: 16, color: AppColors.teksRedup)),
                  ],
                ),
              ),
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

  InputDecoration _dekor(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        counterText: '',
        fillColor: AppColors.latar,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

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
              const Text('Catat Vaksin dari Luar Posyandu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Isi sesuai keterangan orang tua untuk vaksin yang diberikan di rumah sakit, puskesmas, klinik, atau bidan praktik.',
                style: TextStyle(fontSize: 16, color: AppColors.teksRedup),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _kunci,
                isExpanded: true,
                decoration: _dekor('Vaksin & dosis'),
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
                  decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 20, color: AppColors.hijau),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _tanggal == null ? 'Pilih tanggal pemberian' : 'Tanggal pemberian: ${formatTanggal(_tanggal!)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
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
                decoration: _dekor('Tempat pemberian', hint: 'Mis. Puskesmas Balige'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _batch, maxLength: 50, decoration: _dekor('Nomor batch (opsional)')),
              const SizedBox(height: 10),
              TextField(
                controller: _pemberi,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: _dekor('Nama petugas pemberi (opsional)'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _catatan, maxLines: 2, decoration: _dekor('Catatan (opsional)')),
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
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  _kirim ? 'Menyimpan...' : 'Simpan',
                  icon: Icons.save_outlined,
                  onPressed: _kirim ? () {} : _simpan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}