import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../datadiri/lengkapi_keluarga_page.dart';

/// Halaman terpisah: Kartu Digital Anak Posyandu.
/// Bila anak lebih dari satu, pilih salah satu untuk ditampilkan.
class KartuDigitalPage extends StatefulWidget {
  final List<DataAnak> daftar;
  final int awal;
  final String Function(DataAnak) status;
  final Object? Function(DataAnak) nomor;

  const KartuDigitalPage({
    required this.daftar,
    required this.awal,
    required this.status,
    required this.nomor,
  });

  @override
  State<KartuDigitalPage> createState() => _KartuDigitalPageState();
}

class _KartuDigitalPageState extends State<KartuDigitalPage> {
  late int _pilih = widget.awal.clamp(0, widget.daftar.length - 1);

  @override
  Widget build(BuildContext context) {
    final anak = widget.daftar[_pilih];
    final status = widget.status(anak);
    final nomor = widget.nomor(anak);
    final terdaftar = status == 'terdaftar' || status == 'sudah_checkin';
    final kode = anak.kodeQr.isEmpty ? 'PSY-${anak.id}' : anak.kodeQr;

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Kartu Digital Anak'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (widget.daftar.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < widget.daftar.length; i++)
                    ChoiceChip(
                      selected: i == _pilih,
                      selectedColor: AppColors.hijau,
                      backgroundColor: Colors.white,
                      label: Text(widget.daftar[i].nama),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: i == _pilih ? Colors.white : Colors.black87,
                      ),
                      onSelected: (_) => setState(() => _pilih = i),
                    ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.hijau,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('KARTU DIGITAL ANAK POSYANDU',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: QrImageView(
                          data: kode,
                          size: 76,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nama Lengkap Anak',
                                style: TextStyle(
                                    fontSize: 10.5, color: AppColors.teksRedup)),
                            Text(anak.nama,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Pill(
                                    terdaftar
                                        ? (nomor != null
                                            ? 'Antrean #$nomor'
                                            : 'Terdaftar')
                                        : 'Belum terdaftar',
                                    bg: terdaftar
                                        ? AppColors.hijauMuda
                                        : AppColors.isiField,
                                    fg: terdaftar
                                        ? AppColors.hijau
                                        : AppColors.teksRedup),
                                if (status == 'sudah_checkin')
                                  const Pill('Siap Check-in',
                                      bg: AppColors.hijauMuda,
                                      fg: AppColors.hijau,
                                      icon: Icons.check_circle),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                                'Perlihatkan barcode ini ke Meja 1 Pendaftaran saat tiba di balai.',
                                style: TextStyle(
                                    fontSize: 10.5, color: AppColors.teksRedup)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _tombol(Icons.zoom_out_map, 'Perbesar', () {
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(anak.nama),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                QrImageView(data: kode, size: 220),
                                const SizedBox(height: 8),
                                const Text(
                                    'Tunjukkan kode ini kepada kader di Meja 1'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Tutup')),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tombol(Icons.picture_as_pdf, 'Unduh PDF',
                          () => soon(context, 'Unduh ringkasan PDF')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tombol(Icons.share, 'Bagikan',
                          () => soon(context, 'Bagikan kartu')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tombol(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}