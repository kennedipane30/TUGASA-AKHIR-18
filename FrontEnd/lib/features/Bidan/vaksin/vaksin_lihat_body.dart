import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../service/vaksin_service.dart';

/// Isi halaman vaksin anak (dipakai bidan, kader, sekretaris, dan orang tua).
/// Tab: Jadwal (dengan status) · Riwayat Vaksin · Suplemen.
/// [bisaKelola] = true untuk bidan: dapat mencatat vaksin susulan dan menghapusnya.
class VaksinLihatBody extends StatefulWidget {
  final String anakId;
  final bool bisaKelola;

  const VaksinLihatBody({super.key, required this.anakId, this.bisaKelola = false});

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

_GayaStatus _gaya(String status) {
  switch (status) {
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
              Text(_gagal ?? 'Data vaksin tidak dapat dimuat', textAlign: TextAlign.center),
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
          const SizedBox(height: 12),
          _pilihTab(k),
          const SizedBox(height: 12),
          if (widget.bisaKelola && _tab != 2) ...[
            SizedBox(
              width: double.infinity,
              child: AppButton(
                'Catat Vaksin dari Luar Posyandu',
                icon: Icons.add_circle_outline,
                filled: false,
                onPressed: () => _formSusulan(k),
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
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.hijau)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${r.sudah} dari ${r.totalDosis} dosis imunisasi rutin sudah diberikan',
                    style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
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
                child: StatBox(
                    nilai: '${r.terlambat}', label: 'Terlambat', bg: AppColors.merahMuda, fg: AppColors.merah),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: StatBox(nilai: '${k.riwayat.length}', label: 'Riwayat\nVaksin', bg: AppColors.hijauMuda, fg: AppColors.hijau),
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
              if (r.terlewat > 0)
                Pill('${r.terlewat} dosis lewat batas usia', bg: _abuMuda, fg: _abu),
            ],
          ),
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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
            Text(teks, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.teksRedup)),
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

  Widget _barisJadwal(JadwalVaksinAnak e) {
    final g = _gaya(e.status);
    final r = e.riwayat;
    final sub = r != null
        ? 'Diberikan ${r.tanggal == null ? '-' : formatTanggal(r.tanggal!)} · usia ${r.usiaTeks}'
        : e.tanggalJadwal == null
            ? e.labelStatus
            : 'Jadwal: ${formatTanggal(e.tanggalJadwal!)}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _detailJadwal(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: g.bg, shape: BoxShape.circle),
              child: Icon(g.ikon, size: 20, color: g.fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.jadwal.namaDosis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
                  if (e.opsional || e.jadwal.lanjutan) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 4, children: [
                      if (e.jadwal.lanjutan) const Pill('Lanjutan', bg: AppColors.biruMuda, fg: AppColors.biru),
                      if (e.opsional) const Pill('Khusus daerah endemis', bg: _abuMuda, fg: _abu),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Pill(e.labelStatus, bg: g.bg, fg: g.fg),
          ],
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
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
          ),
          Expanded(child: Text(nilai, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _detailJadwal(JadwalVaksinAnak e) {
    final j = e.jadwal;
    final r = e.riwayat;
    final g = _gaya(e.status);
    final bisaCatat = widget.bisaKelola && !e.sudah && e.status != StatusVaksin.terlewat;
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
                  Expanded(
                    child: Text(j.namaDosis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
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
              if (j.jarakMinimalHari != null)
                _info('Jarak minimal', '${j.jarakMinimalHari} hari dari dosis sebelumnya'),
              if (e.tanggalJadwal != null && r == null) _info('Perkiraan tanggal', formatTanggal(e.tanggalJadwal!)),
              _info('Keterangan', j.keterangan),
              if (r != null) ...[
                const Divider(height: 24),
                const Text('Riwayat Pemberian', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _info('Tanggal', r.tanggal == null ? '-' : formatTanggal(r.tanggal!)),
                _info('Usia saat diberikan', r.usiaTeks),
                _info('Tempat', r.tempat),
                _info('Diberikan oleh', r.namaPemberi),
                _info('Kondisi anak', r.kondisiAnak),
                _info('Catatan', r.catatan),
              ],
              if (bisaCatat) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: AppButton('Catat Vaksin dari Luar Posyandu', icon: Icons.edit_note, onPressed: () {
                    Navigator.pop(ctx);
                    _formSusulan(_kartu!, pilihan: e);
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================== riwayat

  List<Widget> _isiRiwayat(KartuVaksin k) {
    if (k.riwayat.isEmpty) return [_kosong(Icons.vaccines_outlined, 'Belum ada riwayat vaksin')];
    return [for (final r in k.riwayat) _kartuRiwayat(r)];
  }

  Widget _kartuRiwayat(RiwayatVaksin r) {
    final nama = r.jenis.nama + (r.dosisKe > 0 ? ' · Dosis ${r.dosisKe}' : '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
                    Text(nama, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(r.tanggal == null ? '-' : formatTanggal(r.tanggal!),
                        style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              if (widget.bisaKelola && !r.dariPosyandu)
                IconButton(
                  tooltip: 'Hapus riwayat',
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
              Pill(r.tempat.isEmpty ? (r.dariPosyandu ? 'Posyandu' : 'Di luar posyandu') : r.tempat,
                  bg: r.dariPosyandu ? AppColors.hijauMuda : AppColors.kuningMuda,
                  fg: r.dariPosyandu ? AppColors.hijau : AppColors.kuning),
            ],
          ),
          if (r.namaPemberi.isNotEmpty || r.kondisiAnak.isNotEmpty || r.catatan.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (r.namaPemberi.isNotEmpty)
              Text('Dicatat oleh: ${r.namaPemberi}', style: const TextStyle(fontSize: 12)),
            if (r.kondisiAnak.isNotEmpty) Text('Kondisi anak: ${r.kondisiAnak}', style: const TextStyle(fontSize: 12)),
            if (r.catatan.isNotEmpty) Text('Catatan: ${r.catatan}', style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Future<void> _hapus(RiwayatVaksin r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus riwayat vaksin?'),
        content: Text('${r.jenis.nama} dosis ${r.dosisKe} '
            '(${r.tanggal == null ? '-' : formatTanggal(r.tanggal!)}) akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
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
      _snack('Riwayat vaksin dihapus');
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
                    Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      '${s.tanggal == null ? '-' : formatTanggal(s.tanggal!)} · usia ${s.usiaTeks}',
                      style: const TextStyle(fontSize: 12, color: AppColors.teksRedup),
                    ),
                    if (s.ringkasDosis.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Pill(s.ringkasDosis, bg: AppColors.kuningMuda, fg: AppColors.kuning),
                    ],
                    if (s.catatan.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Catatan: ${s.catatan}', style: const TextStyle(fontSize: 12)),
                    ],
                    if (s.namaPemberi.isNotEmpty)
                      Text('Diberikan oleh: ${s.namaPemberi}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  // ============================================================ vaksin susulan

  Future<void> _formSusulan(KartuVaksin k, {JadwalVaksinAnak? pilihan}) async {
    final opsi = k.jadwal.where((e) => !e.sudah && e.status != StatusVaksin.terlewat).toList();
    if (opsi.isEmpty) {
      _snack('Semua dosis sudah tercatat');
      return;
    }
    final tersimpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormSusulan(
        anakId: k.anak.id,
        lahir: k.anak.tanggalLahir,
        opsi: opsi,
        awal: pilihan,
        svc: _svc,
      ),
    );
    if (tersimpan == true) {
      _snack('Riwayat vaksin tersimpan');
      await _muat();
    }
  }
}

class _FormSusulan extends StatefulWidget {
  final String anakId;
  final DateTime? lahir;
  final List<JadwalVaksinAnak> opsi;
  final JadwalVaksinAnak? awal;
  final VaksinService svc;

  const _FormSusulan({
    required this.anakId,
    required this.lahir,
    required this.opsi,
    required this.awal,
    required this.svc,
  });

  @override
  State<_FormSusulan> createState() => _FormSusulanState();
}

class _FormSusulanState extends State<_FormSusulan> {
  String? _kunci;
  DateTime _tanggal = DateTime.now();
  final _tempat = TextEditingController();
  final _kondisi = TextEditingController();
  final _catatan = TextEditingController();
  bool _kirim = false;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _kunci = widget.awal?.jadwal.kunci;
  }

  @override
  void dispose() {
    _tempat.dispose();
    _kondisi.dispose();
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
        fillColor: AppColors.latar,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  Future<void> _pilihTanggal() async {
    final n = DateTime.now();
    final awal = widget.lahir ?? DateTime(n.year - 6);
    final t = await showDatePicker(
      context: context,
      initialDate: _tanggal.isBefore(awal) ? awal : _tanggal,
      firstDate: awal,
      lastDate: DateTime(n.year, n.month, n.day),
    );
    if (t != null) setState(() => _tanggal = t);
  }

  Future<void> _simpan() async {
    final d = _dipilih;
    if (d == null) {
      setState(() => _gagal = 'Pilih vaksin dan dosis');
      return;
    }
    setState(() {
      _kirim = true;
      _gagal = null;
    });
    try {
      await widget.svc.catatRiwayat(
        anakId: widget.anakId,
        jenisVaksinId: d.jadwal.jenis.id,
        dosisKe: d.jadwal.dosisKe,
        tanggal: _tanggal,
        tempat: _tempat.text.trim(),
        kondisiAnak: _kondisi.text.trim(),
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
              const Text('Catat Vaksin dari Luar Posyandu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                'Untuk vaksin yang diberikan di puskesmas, rumah sakit, atau bidan praktik (sesuai buku KIA).',
                style: TextStyle(fontSize: 12, color: AppColors.teksRedup),
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
                        child: Text('Tanggal pemberian: ${formatTanggal(_tanggal)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              if (lahir != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text('Usia anak saat itu: ${usiaDariLahir(lahir, _tanggal)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _tempat,
                decoration: _dekor('Tempat pemberian', hint: 'Mis. Puskesmas Balige'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _kondisi, decoration: _dekor('Kondisi anak (opsional)')),
              const SizedBox(height: 10),
              TextField(controller: _catatan, maxLines: 2, decoration: _dekor('Catatan (opsional)')),
              if (_gagal != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.merahMuda, borderRadius: BorderRadius.circular(10)),
                  child: Text(_gagal!, style: const TextStyle(fontSize: 12, color: AppColors.merah)),
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
