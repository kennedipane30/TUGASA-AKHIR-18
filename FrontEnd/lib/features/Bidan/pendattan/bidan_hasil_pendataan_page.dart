import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../vaksin/bidan_vaksin_anak_page.dart';

class _Hasil {
  final String anakId;
  final String nama;
  final String usia;
  final String kader;
  final String tanggal;
  final String status;
  final Gizi tingkat;
  const _Hasil(this.anakId, this.nama, this.usia, this.kader, this.tanggal, this.status, this.tingkat);
}

class BidanHasilPendataanPage extends StatefulWidget {
  const BidanHasilPendataanPage({super.key});

  @override
  State<BidanHasilPendataanPage> createState() => _BidanHasilPendataanPageState();
}

class _BidanHasilPendataanPageState extends State<BidanHasilPendataanPage> {
  static const _filter = ['Semua', 'Menunggu', 'Terverifikasi', 'Dikembalikan'];
  String _aktif = 'Semua';

  // DATA CONTOH. Ganti dengan data dari API.
  // anakId harus berisi UUID anak yang sebenarnya dari API.
  static const _data = <_Hasil>[
    _Hasil('00000000-0000-0000-0000-000000000001', 'Alvino Pratama', '18 bln', 'Kader Siti', '3 Okt 2026', 'Menunggu', Gizi.risiko),
    _Hasil('00000000-0000-0000-0000-000000000002', 'Maya Safitri', '6 bln', 'Kader Dewi', '3 Okt 2026', 'Menunggu', Gizi.baik),
    _Hasil('00000000-0000-0000-0000-000000000003', 'Rian Pratama', '2 th 3 bln', 'Kader Siti', '2 Okt 2026', 'Terverifikasi', Gizi.baik),
    _Hasil('00000000-0000-0000-0000-000000000004', 'Sasa Putri', '22 bln', 'Kader Dewi', '2 Okt 2026', 'Dikembalikan', Gizi.waspada),
  ];

  void _bukaVaksin(_Hasil d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BidanVaksinAnakPage(
          anakId: d.anakId,
          namaAnak: d.nama,
          usia: d.usia,
        ),
      ),
    );
  }

  void _bukaDetail(_Hasil d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: giziBg(d.tingkat),
                  child: Text(d.nama.substring(0, 2).toUpperCase(),
                      style: TextStyle(
                          color: giziFg(d.tingkat),
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d.nama} (${d.usia})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${d.kader} · ${d.tanggal}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton('Jadwal & Riwayat Vaksin',
                  icon: Icons.vaccines_outlined,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _bukaVaksin(d);
                  }),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton('Detail Pengukuran',
                  icon: Icons.straighten,
                  filled: false,
                  onPressed: () {
                    Navigator.pop(ctx);
                    soon(context, 'Detail hasil pendataan');
                  }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daftar = _aktif == 'Semua' ? _data : _data.where((d) => d.status == _aktif).toList();

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Hasil Pendataan', style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _filter)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _aktif == f,
                      selectedColor: AppColors.hijau,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _aktif == f ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _aktif = f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (daftar.isEmpty)
            const SectionCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Tidak ada data',
                      style: TextStyle(color: AppColors.teksRedup)),
                ),
              ),
            ),
          for (final d in daftar)
            SectionCard(
              child: InkWell(
                onTap: () => _bukaDetail(d),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: giziBg(d.tingkat),
                      child: Text(d.nama.substring(0, 2).toUpperCase(),
                          style: TextStyle(
                              color: giziFg(d.tingkat),
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${d.nama} (${d.usia})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13.5)),
                          Text('${d.kader} · ${d.tanggal}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.teksRedup)),
                        ],
                      ),
                    ),
                    Pill(d.status,
                        bg: switch (d.status) {
                          'Terverifikasi' => AppColors.hijauMuda,
                          'Dikembalikan' => AppColors.merahMuda,
                          _ => AppColors.kuningMuda,
                        },
                        fg: switch (d.status) {
                          'Terverifikasi' => AppColors.hijau,
                          'Dikembalikan' => AppColors.merah,
                          _ => AppColors.kuning,
                        }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}