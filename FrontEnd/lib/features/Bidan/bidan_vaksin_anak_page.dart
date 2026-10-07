import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import 'bidan_vaksin_form_page.dart';
import 'vaksin_model.dart';
import 'vaksin_service.dart';

/// Halaman vaksin per anak untuk bidan: rencana vaksin dan riwayat vaksin.
class BidanVaksinAnakPage extends StatefulWidget {
  final String anakId;
  final String namaAnak;
  final String usia;

  const BidanVaksinAnakPage({
    super.key,
    required this.anakId,
    required this.namaAnak,
    required this.usia,
  });

  @override
  State<BidanVaksinAnakPage> createState() => _BidanVaksinAnakPageState();
}

class _BidanVaksinAnakPageState extends State<BidanVaksinAnakPage> {
  final _svc = VaksinService();

  List<VaksinRencana> _rencana = [];
  List<VaksinRiwayat> _riwayat = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasil = await Future.wait([
        _svc.listRencana(widget.anakId),
        _svc.listRiwayat(widget.anakId),
      ]);
      if (!mounted) return;
      setState(() {
        _rencana = hasil[0] as List<VaksinRencana>;
        _riwayat = hasil[1] as List<VaksinRiwayat>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _bukaForm([VaksinRencana? rencana]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BidanVaksinFormPage(
          anakId: widget.anakId,
          namaAnak: widget.namaAnak,
          rencana: rencana,
        ),
      ),
    );
    if (ok == true) {
      _pesan(rencana == null ? 'Jadwal vaksin disimpan' : 'Jadwal vaksin diperbarui');
      _muat();
    }
  }

  Future<void> _batalkan(VaksinRencana r) async {
    final alasan = TextEditingController();
    final hasil = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batalkan ${r.vaksin.nama} dosis ${r.dosisKe}'),
        content: TextField(
          controller: alasan,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Alasan pembatalan (opsional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kembali')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, alasan.text.trim()),
            child: const Text('Batalkan Jadwal'),
          ),
        ],
      ),
    );
    alasan.dispose();
    if (hasil == null) return;
    try {
      await _svc.batalkanRencana(r.id, hasil);
      _pesan('Jadwal vaksin dibatalkan');
      _muat();
    } catch (e) {
      _pesan(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _catatDiberikan(VaksinRencana r) async {
    final kondisi = TextEditingController();
    final catatan = TextEditingController();
    DateTime tanggal = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Catat ${r.vaksin.nama} dosis ${r.dosisKe}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tanggal Pemberian',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(formatTanggalTampil(formatTanggalApi(tanggal))),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: tanggal,
                      firstDate: DateTime(2018),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setD(() => tanggal = d);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kondisi,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Kondisi anak saat vaksin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catatan,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );

    final kondisiTeks = kondisi.text.trim();
    final catatanTeks = catatan.text.trim();
    kondisi.dispose();
    catatan.dispose();
    if (ok != true) return;

    try {
      await _svc.catatRiwayat(
        anakId: widget.anakId,
        jenisVaksinId: r.vaksin.id,
        dosisKe: r.dosisKe,
        tanggal: tanggal,
        kondisiAnak: kondisiTeks,
        catatan: catatanTeks,
      );
      _pesan('Pemberian vaksin dicatat');
      _muat();
    } catch (e) {
      _pesan(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: Text('Vaksin · ${widget.namaAnak}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.hijau,
        foregroundColor: Colors.white,
        onPressed: () => _bukaForm(),
        icon: const Icon(Icons.add),
        label: const Text('Jadwalkan Vaksin'),
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: _loading
            ? ListView(children: const [
                SizedBox(height: 200),
                Center(child: CircularProgressIndicator()),
              ])
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(child: AppButton('Coba Lagi', icon: Icons.refresh, onPressed: _muat)),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      SectionCard(
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.hijauMuda,
                              child: Icon(Icons.child_care, color: AppColors.hijau),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.namaAnak,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800, fontSize: 14)),
                                  Text('Usia ${widget.usia}',
                                      style: const TextStyle(
                                          fontSize: 11.5, color: AppColors.teksRedup)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SectionCard(
                        title: 'Rencana Vaksin',
                        icon: Icons.event_available_outlined,
                        trailing: Pill('${_rencana.length}',
                            bg: AppColors.biruMuda, fg: AppColors.biru),
                        child: _rencana.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text('Belum ada rencana vaksin',
                                      style: TextStyle(color: AppColors.teksRedup)),
                                ),
                              )
                            : Column(children: [for (final r in _rencana) _kartuRencana(r)]),
                      ),
                      SectionCard(
                        title: 'Riwayat Vaksin',
                        icon: Icons.history,
                        trailing: Pill('${_riwayat.length}',
                            bg: AppColors.hijauMuda, fg: AppColors.hijau),
                        child: _riwayat.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text('Belum ada riwayat vaksin',
                                      style: TextStyle(color: AppColors.teksRedup)),
                                ),
                              )
                            : Column(children: [for (final r in _riwayat) _kartuRiwayat(r)]),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _kartuRencana(VaksinRencana r) {
    final telat = r.terlambat;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${r.vaksin.nama} · Dosis ${r.dosisKe}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ),
              Pill(telat ? 'Terlambat' : 'Direncanakan',
                  bg: telat ? AppColors.merahMuda : AppColors.biruMuda,
                  fg: telat ? AppColors.merah : AppColors.biru),
            ],
          ),
          const SizedBox(height: 4),
          Text('Tanggal: ${formatTanggalTampil(r.perkiraanTanggal)} · ideal ${r.usiaIdealBulan} bln',
              style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
          if (r.alasan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Dasar: ${r.alasan}', style: const TextStyle(fontSize: 11.5)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton('Ubah',
                    icon: Icons.edit_calendar_outlined,
                    filled: false,
                    onPressed: () => _bukaForm(r)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppButton('Batal',
                    icon: Icons.close,
                    filled: false,
                    color: AppColors.merah,
                    onPressed: () => _batalkan(r)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppButton('Diberikan',
                    icon: Icons.vaccines, onPressed: () => _catatDiberikan(r)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kartuRiwayat(VaksinRiwayat r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.hijauMuda,
            child: Icon(Icons.check, size: 18, color: AppColors.hijau),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.vaksin.nama} · Dosis ${r.dosisKe}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text(
                    '${formatTanggalTampil(r.tanggalPemberian)}${r.namaPemberi.isNotEmpty ? ' · ${r.namaPemberi}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
                if (r.kondisiAnak.isNotEmpty)
                  Text('Kondisi: ${r.kondisiAnak}', style: const TextStyle(fontSize: 11.5)),
                if (r.catatan.isNotEmpty)
                  Text('Catatan: ${r.catatan}', style: const TextStyle(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}