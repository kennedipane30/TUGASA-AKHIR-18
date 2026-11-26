import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../service/rujukan_service.dart';
import 'surat_rujukan_pdf.dart';
import '../../theme/app_colors.dart';
import '../../utils/posyandu.dart';
import '../../utils/no_hp.dart';
import '../rekap/rekap_posyandu_page.dart';

// ============================================================================
// KOMPONEN BERSAMA RUJUKAN (bidan & orang tua)
// ============================================================================

const teksRujukan = Color(0xFF1F2937);
const redupRujukan = Color(0xFF64748B);
const garisRujukan = Color(0xFFB8BEC6);

String _namaFile(RujukanDetail r) =>
    'Surat_Rujukan_${r.dataBalita.nama.trim().replaceAll(RegExp(r'\s+'), '_')}_${r.nomor.replaceAll('/', '-')}.pdf';

/// Unduh: membuka layar cetak HP, lalu pilih "Simpan sebagai PDF".
Future<void> unduhSuratRujukan(RujukanDetail r) async {
  final bytes = await buatPdfSuratRujukan(r);
  await Printing.layoutPdf(name: _namaFile(r), onLayout: (_) async => bytes);
}

/// Bagikan: file PDF dikirim lewat menu bagikan HP (WhatsApp, email, Drive, ...).
Future<void> bagikanSuratRujukan(BuildContext context, RujukanDetail r) async {
  final bytes = await buatPdfSuratRujukan(r);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_namaFile(r)}');
  await file.writeAsBytes(bytes, flush: true);
  if (!context.mounted) return;
  final kotak = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Surat Rujukan ${r.dataBalita.nama} - ${r.nomor}',
      subject: 'Surat Rujukan ${r.dataBalita.nama} - ${r.nomor}',
      sharePositionOrigin: kotak == null ? null : kotak.localToGlobal(Offset.zero) & kotak.size,
    ),
  );
}

/// Label status berwarna.
class ChipStatusRujukan extends StatelessWidget {
  final String status;
  const ChipStatusRujukan(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'dirujuk' => (AppColors.kuningMuda, AppColors.kuning),
      'selesai' => (AppColors.hijauMuda, AppColors.hijau),
      _ => (AppColors.merahMuda, AppColors.merah),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(labelStatusRujukan(status),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Tombol hijau (isi) / garis (hijau atau merah), tinggi 50, sudut 14.
class TombolRujukan extends StatelessWidget {
  final String label;
  final IconData ikon;
  final VoidCallback? onTap;
  final bool proses;
  final bool isi;
  final Color warna;

  const TombolRujukan({
    super.key,
    required this.label,
    required this.ikon,
    required this.onTap,
    this.proses = false,
    this.isi = true,
    this.warna = AppColors.hijau,
  });

  @override
  Widget build(BuildContext context) {
    final balita = proses
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: isi ? Colors.white : warna),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          );
    final bentuk = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return SizedBox(
      height: 50,
      child: isi
          ? ElevatedButton(
              onPressed: proses ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: warna,
                foregroundColor: Colors.white,
                disabledBackgroundColor: warna.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: bentuk,
              ),
              child: balita,
            )
          : OutlinedButton(
              onPressed: proses ? null : onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: warna,
                side: BorderSide(color: warna, width: 1.4),
                shape: bentuk,
              ),
              child: balita,
            ),
    );
  }
}

/// Baris label : nilai di dalam kartu.
Widget barisRujukan(String label, String nilai, {bool akhir = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: akhir ? null : const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 14.5, color: redupRujukan)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(nilai.trim().isEmpty ? '-' : nilai,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: teksRujukan)),
          ),
        ],
      ),
    );

List<Widget> daftarBarisRujukan(List<(String, String)> isi) => [
      for (var i = 0; i < isi.length; i++) barisRujukan(isi[i].$1, isi[i].$2, akhir: i == isi.length - 1),
    ];

/// Teks panjang dengan judul kecil (keluhan, diagnosis, ...).
Widget paragrafRujukan(String judul, String isi, {bool akhir = false}) => Padding(
      padding: EdgeInsets.only(bottom: akhir ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: redupRujukan)),
          const SizedBox(height: 4),
          Text(isi.trim().isEmpty ? '-' : isi.trim(),
              style: const TextStyle(fontSize: 15, height: 1.4, color: teksRujukan)),
        ],
      ),
    );

/// Kartu data balita, orang tua, dan pemeriksaan terakhir (dipakai di form & detail).
List<Widget> kartuDataBalitaRujukan(DataBalitaRujukan a) {
  final p = a.pemeriksaan;
  return [
    KartuRekap(
      title: 'Identitas Balita',
      child: Column(
        children: daftarBarisRujukan([
          ('Nama', a.nama),
          ('NIK', a.nik),
          ('Jenis kelamin', jkRujukan(a.jenisKelamin)),
          ('Tanggal lahir', tglRujukan(a.tanggalLahir)),
          ('Usia', a.usiaTeks),
        ]),
      ),
    ),
    KartuRekap(
      title: 'Orang Tua',
      child: Column(
        children: daftarBarisRujukan([
          if (a.namaIbu.isNotEmpty) ('Nama ibu', a.namaIbu),
          if (a.namaAyah.isNotEmpty) ('Nama ayah', a.namaAyah),
          if (a.namaWali.isNotEmpty) ('Nama wali', a.namaWali),
          ('No. HP', formatNoHp(a.noHp)),
          ('Alamat', a.alamat),
          ('Posyandu', 'Posyandu ${labelPosyandu(a.posyandu)}'),
        ]),
      ),
    ),
    KartuRekap(
      title: 'Pemeriksaan Terakhir',
      trailing: p == null ? null : teksKananRekap(tglRujukan(p.tanggalUkur)),
      child: p == null
          ? const Text('Belum ada data pengukuran.', style: TextStyle(fontSize: 14.5, color: redupRujukan))
          : Column(
              children: daftarBarisRujukan([
                ('Berat badan', angkaRujukan(p.bbKg, 'kg')),
                ('Tinggi/panjang', angkaRujukan(p.tbCm, 'cm')),
                ('LiLA', angkaRujukan(p.lilaCm, 'cm')),
                ('Lingkar kepala', angkaRujukan(p.lkCm, 'cm')),
                ('BB/U', p.statusBbu),
                ('TB/U', p.statusTbu),
                ('BB/TB', p.statusBbtb),
                ('Penimbangan', p.tandaTimbang.isEmpty ? 'Normal' : p.tandaTimbang),
              ]),
            ),
    ),
  ];
}

/// Isi lengkap detail rujukan (tanpa tombol aksi).
class RujukanDetailView extends StatelessWidget {
  final RujukanDetail r;
  const RujukanDetailView(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final b = r.balik;
    return Column(
      children: [
        KartuRekap(
          title: 'Surat Rujukan',
          trailing: ChipStatusRujukan(r.status),
          child: Column(
            children: daftarBarisRujukan([
              ('Nomor', r.nomor),
              ('Tanggal', tglRujukan(r.tanggal)),
              ('Tujuan', r.tujuan),
              ('Bidan perujuk', r.bidanNama),
            ]),
          ),
        ),
        if (r.dibatalkan)
          KartuRekap(
            title: 'Dibatalkan',
            child: paragrafRujukan('Alasan pembatalan', r.alasanBatal, akhir: true),
          ),
        KartuRekap(
          title: 'Keterangan Rujukan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              paragrafRujukan('Keluhan', r.keluhan),
              paragrafRujukan('Diagnosis', r.diagnosis),
              paragrafRujukan('Tindakan yang sudah dilakukan', r.tindakan, akhir: true),
            ],
          ),
        ),
        if (b != null)
          KartuRekap(
            title: 'Hasil Rujukan',
            trailing: teksKananRekap(tglRujukan(b.tanggalDiperiksa)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                paragrafRujukan('Hasil / diagnosis dari faskes', b.hasilDiagnosis),
                paragrafRujukan('Terapi / saran dari faskes', b.terapiSaran),
                paragrafRujukan('Tindak lanjut di posyandu', b.tindakLanjut, akhir: true),
              ],
            ),
          ),
        ...kartuDataBalitaRujukan(r.dataBalita),
      ],
    );
  }
}

/// Kartu ringkas satu rujukan pada daftar.
class KartuRingkasRujukan extends StatelessWidget {
  final RujukanRingkas r;
  final VoidCallback onTap;
  const KartuRingkasRujukan(this.r, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: dekorKartuRekap(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.namaBalita,
                          style: const TextStyle(
                              fontSize: 16.5, fontWeight: FontWeight.w700, color: teksRujukan)),
                    ),
                    ChipStatusRujukan(r.status),
                  ],
                ),
                const SizedBox(height: 3),
                Text('${jkRujukan(r.jenisKelamin)}  |  ${r.usiaTeks}',
                    style: const TextStyle(fontSize: 13.5, color: redupRujukan)),
                const SizedBox(height: 8),
                Text('Diagnosis: ${r.diagnosis}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, color: teksRujukan)),
                const SizedBox(height: 3),
                Text('Tujuan: ${r.tujuan}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, color: teksRujukan)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 16, color: redupRujukan),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(r.nomor,
                          style: const TextStyle(fontSize: 13, color: redupRujukan)),
                    ),
                    Text(tglRujukan(r.tanggal),
                        style: const TextStyle(fontSize: 13, color: redupRujukan)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}