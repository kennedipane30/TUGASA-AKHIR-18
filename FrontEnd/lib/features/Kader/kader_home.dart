import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import 'pendaftaran/kader_scan_page.dart';
import 'vaksin/kader_vaksin_page.dart';

/// Penanda status data pengukuran (KD-04 poin 7).
enum StatusData { draft, lokal, sinkron, terverifikasi }

extension on StatusData {
  (String, Color, Color) get tampil => switch (this) {
        StatusData.draft => ('Draft', AppColors.isiField, AppColors.teksRedup),
        StatusData.lokal =>
          ('Tersimpan di perangkat', AppColors.kuningMuda, AppColors.kuning),
        StatusData.sinkron => ('Tersinkron', AppColors.biruMuda, AppColors.biru),
        StatusData.terverifikasi =>
          ('Terverifikasi', AppColors.hijauMuda, AppColors.hijau),
      };
}

// ---------------------------------------------------------------------------
// DATA CONTOH. Ganti dengan data dari database lokal perangkat kader.
// ---------------------------------------------------------------------------
class _Antrean {
  final String nama;
  final String detail;
  final String meja;
  final StatusData status;
  const _Antrean(this.nama, this.detail, this.meja, this.status);
}

const _antrean = <_Antrean>[
  _Antrean('Rayyan Al-Fatih', '1 th 6 bln · Laki-laki', 'Meja 2 · Timbang', StatusData.draft),
  _Antrean('Annisa Zahra', '2 th 0 bln · Perempuan', 'Meja 3 · Ukur TB', StatusData.lokal),
  _Antrean('Dimas Pratama', '2 th 4 bln · Laki-laki', 'Meja 3 · Lingkar kepala', StatusData.sinkron),
];

class KaderHome extends StatefulWidget {
  const KaderHome({super.key});

  @override
  State<KaderHome> createState() => _KaderHomeState();
}

class _KaderHomeState extends State<KaderHome> {
  // Ringkasan sesi berjalan (KD-02 poin 4).
  static const _target = 42;
  static const _checkin = 35;
  static const _walkin = 3;

  bool _sinkronBerjalan = false;
  int _tertunda = 3;
  String _sinkronTerakhir = '10 menit lalu';

  Future<void> _sinkronkan() async {
    setState(() => _sinkronBerjalan = true);
    // Ganti dengan pemanggilan service sinkronisasi (antrean data -> REST API).
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _sinkronBerjalan = false;
      _tertunda = 0;
      _sinkronTerakhir = 'baru saja';
    });
  }

  void _bukaScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderScanPage()),
    );
  }

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderVaksinPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final belum = _target - _checkin;
    final persen = (_checkin / _target * 100).toStringAsFixed(1);

    return HomeShell(
      peran: 'Kader',
      lokasi: 'Posyandu Melati RW 04',
      notif: 3,
      children: [
        // Status online/offline + sinkron (Lintas Role F.3)
        SyncStrip(
          online: true,
          tertunda: _tertunda,
          sinkronTerakhir: _sinkronTerakhir,
          sedangSinkron: _sinkronBerjalan,
          onSinkron: _sinkronkan,
        ),

        // Sesi berjalan
        SectionCard(
          color: AppColors.hijauMuda,
          child: Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.hijau),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sesi Aktif Hari Ini',
                        style: TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                    Text('Penimbangan Rutin Oktober',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('08.00 -\n11.30',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),

        // KD-02 poin 1 dan 4: kehadiran balita
        SectionCard(
          title: 'Kehadiran Balita',
          icon: Icons.groups_2_outlined,
          trailing: Text('$persen%',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.hijau)),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                      child: StatBox(
                          nilai: '$_target', label: 'Terdaftar\n(Target)', bg: AppColors.biruMuda)),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: StatBox(
                          nilai: '$_checkin',
                          label: 'Check-in\nHadir',
                          bg: AppColors.hijauMuda,
                          fg: AppColors.hijau)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: StatBox(
                          nilai: '$belum',
                          label: 'Belum Datang',
                          bg: AppColors.kuningMuda,
                          fg: AppColors.kuning)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _checkin / _target,
                  minHeight: 8,
                  backgroundColor: AppColors.isiField,
                  color: AppColors.hijau,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_checkin dari $_target balita sudah di posyandu ($_walkin walk-in)',
                      style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                  Text('Sisa $belum balita',
                      style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                ],
              ),
            ],
          ),
        ),

        // KD-02 poin 2 dan 3, KD-03: scan QR, walk-in, tambah balita
        SectionCard(
          color: AppColors.hijau,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Scan QR / Verifikasi Check-in',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Arahkan kamera ke kartu digital anak, atau cari berdasarkan NIK/nama.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _aksiPutih(Icons.qr_code_scanner, 'Scan QR', _bukaScan),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _aksiPutih(Icons.search, 'Cari NIK/Nama',
                        () => soon(context, 'Pencarian anak')),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _aksiKecil(Icons.directions_walk, 'Check-in\nWalk-in',
                  () => soon(context, 'Check-in walk-in')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _aksiKecil(Icons.straighten, 'Ukur Data\nBB TB LK LiLA',
                  () => soon(context, 'Form pengukuran')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _aksiKecil(Icons.person_add_alt_1, 'Daftar\nBalita Baru',
                  () => soon(context, 'Pendataan balita baru')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _aksiKecil(Icons.vaccines_outlined, 'Jadwal &\nRiwayat Vaksin', _bukaVaksin),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Catatan dari bidan (KD-07 poin 2)
        SectionCard(
          color: AppColors.merahMuda,
          title: 'Catatan Dari Bidan Ratna',
          icon: Icons.assignment_return_outlined,
          trailing: const Pill('Perlu Koreksi', bg: Colors.white, fg: AppColors.merah),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Data balita Sasa Putri (22 bln): TB tercatat 76.5 cm (turun dari kunjungan lalu). Konfirmasi ulang pengukuran.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              AppButton('Perbaiki Data Sasa Sekarang',
                  icon: Icons.edit_note,
                  color: AppColors.merah,
                  onPressed: () => soon(context, 'Koreksi data')),
            ],
          ),
        ),

        // KD-04: antrean meja 2 dan 3
        SectionCard(
          title: 'Antrean Meja 2 & 3',
          icon: Icons.format_list_numbered,
          trailing: Pill('${_antrean.length} menunggu',
              bg: AppColors.hijauMuda, fg: AppColors.hijau),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Sudah check-in, siap ditimbang/diukur',
                      style: TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
                ),
              ),
              for (final a in _antrean) _barisAntrean(a),
            ],
          ),
        ),

        // Vaksin anak (hanya lihat)
        SectionCard(
          title: 'Vaksin Anak',
          icon: Icons.vaccines_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cari anak untuk melihat rencana vaksin yang ditetapkan bidan dan riwayat vaksin yang sudah diterima.',
                style: TextStyle(fontSize: 12, color: AppColors.teksRedup),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppButton('Lihat Rencana & Riwayat Vaksin',
                    icon: Icons.event_available_outlined, onPressed: _bukaVaksin),
              ),
            ],
          ),
        ),

        // KD-06: tindak lanjut lapangan
        SectionCard(
          title: 'Perhatian & Tindak Lanjut',
          icon: Icons.notifications_active_outlined,
          trailing: TextButton(
            onPressed: () => soon(context, 'Daftar tindak lanjut'),
            child: const Text('Lihat Semua'),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatBox(
                        nilai: '3',
                        label: 'Balita tidak hadir\n2x berturut-turut',
                        bg: AppColors.kuningMuda,
                        fg: AppColors.kuning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatBox(
                        nilai: '2',
                        label: 'Dirujuk bidan\n(pantau lanjutan)',
                        bg: AppColors.merahMuda,
                        fg: AppColors.merah),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    backgroundColor: AppColors.kuningMuda,
                    child: Icon(Icons.home_outlined, color: AppColors.kuning)),
                title: const Text('Kenzo (18 bln)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                subtitle: const Text('Tidak hadir 2x berturut-turut'),
              ),
              Row(
                children: [
                  Expanded(
                    child: AppButton('Kirim Pengingat',
                        icon: Icons.send,
                        filled: false,
                        onPressed: () => soon(context, 'Kirim pengingat')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton('Catat Kunjungan',
                        icon: Icons.edit_calendar,
                        onPressed: () => soon(context, 'Catatan kunjungan rumah')),
                  ),
                ],
              ),
            ],
          ),
        ),

        // KD-08: rekap kegiatan
        SectionCard(
          title: 'Rekap Kegiatan Hari Ini',
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hadir 35 · Ditimbang 31 · Gizi baik 27 · Perlu perhatian 4',
                  style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 10),
              AppButton('Cetak / Ekspor Rekap Harian',
                  icon: Icons.print_outlined,
                  filled: false,
                  onPressed: () => soon(context, 'Ekspor rekap harian')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _aksiPutih(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.hijau,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }

  Widget _aksiKecil(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.hijau, size: 26),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _barisAntrean(_Antrean a) {
    final (label, bg, fg) = a.status.tampil;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.latar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.hijauMuda,
            child: Text(a.nama[0],
                style: const TextStyle(color: AppColors.hijau, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nama,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text(a.detail,
                    style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill(a.meja, bg: AppColors.biruMuda, fg: AppColors.biru),
                    Pill(label, bg: bg, fg: fg),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: AppButton('Ukur\nSekarang', onPressed: () => soon(context, 'Form pengukuran')),
          ),
        ],
      ),
    );
  }
}