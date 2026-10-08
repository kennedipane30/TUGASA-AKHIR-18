import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import 'vaksin_model.dart';
import '../../../service/vaksin_service.dart';

/// Isi halaman vaksin (hanya lihat): rencana vaksin dan riwayat vaksin satu anak.
class VaksinLihatBody extends StatefulWidget {
  final String anakId;
  const VaksinLihatBody({super.key, required this.anakId});

  @override
  State<VaksinLihatBody> createState() => _VaksinLihatBodyState();
}

class _VaksinLihatBodyState extends State<VaksinLihatBody> {
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _muat,
      child: _loading
          ? ListView(children: const [
              SizedBox(height: 160),
              Center(child: CircularProgressIndicator()),
            ])
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 100),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Center(child: AppButton('Coba Lagi', icon: Icons.refresh, onPressed: _muat)),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SectionCard(
                      title: 'Rencana Vaksin',
                      icon: Icons.event_available_outlined,
                      trailing: Pill('${_rencana.length}',
                          bg: AppColors.biruMuda, fg: AppColors.biru),
                      child: _rencana.isEmpty
                          ? _kosong('Belum ada rencana vaksin')
                          : Column(children: [for (final r in _rencana) _kartuRencana(r)]),
                    ),
                    SectionCard(
                      title: 'Riwayat Vaksin',
                      icon: Icons.history,
                      trailing: Pill('${_riwayat.length}',
                          bg: AppColors.hijauMuda, fg: AppColors.hijau),
                      child: _riwayat.isEmpty
                          ? _kosong('Belum ada riwayat vaksin')
                          : Column(children: [for (final r in _riwayat) _kartuRiwayat(r)]),
                    ),
                  ],
                ),
    );
  }

  Widget _kosong(String teks) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text(teks, style: const TextStyle(color: AppColors.teksRedup))),
      );

  Widget _kartuRencana(VaksinRencana r) {
    final telat = r.terlambat;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(14)),
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
          Row(
            children: [
              const Icon(Icons.event, size: 14, color: AppColors.hijau),
              const SizedBox(width: 4),
              Text(formatTanggalTampil(r.perkiraanTanggal),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(' · usia ideal ${r.usiaIdealBulan} bln',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
            ],
          ),
          if (r.alasan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Catatan bidan: ${r.alasan}', style: const TextStyle(fontSize: 11.5)),
          ],
        ],
      ),
    );
  }

  Widget _kartuRiwayat(VaksinRiwayat r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(14)),
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