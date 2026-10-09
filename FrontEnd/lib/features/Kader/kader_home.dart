import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../OrangTua/pendaftaran/orangtua_pendaftaran_page.dart';
import 'pendataan/kader_pendataan_page.dart';
import 'vaksin/kader_vaksin_page.dart';

class KaderHome extends StatefulWidget {
  const KaderHome({super.key});

  @override
  State<KaderHome> createState() => _KaderHomeState();
}

class _KaderHomeState extends State<KaderHome> {
  JadwalTerdekatData? _jadwal;
  List<AntreanKader> _antrean = [];
  bool _memuat = true;
  String? _gagal;

  bool _sinkronBerjalan = false;
  int _tertunda = 0;
  String _sinkronTerakhir = 'baru saja';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final j = await JadwalTerdekatData.ambil();
      final list = j == null ? <AntreanKader>[] : await AntreanKader.ambil(j.id);
      if (!mounted) return;
      setState(() {
        _jadwal = j;
        _antrean = list;
        _gagal = null;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gagal = 'Gagal memuat data antrean dari server.';
        _memuat = false;
      });
    }
  }

  Future<void> _sinkronkan() async {
    setState(() => _sinkronBerjalan = true);
    await _muat();
    if (!mounted) return;
    setState(() {
      _sinkronBerjalan = false;
      _tertunda = 0;
      _sinkronTerakhir = 'baru saja';
    });
  }

  Future<void> _bukaAntrean() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderPendataanPage()),
    );
    _muat();
  }

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KaderVaksinPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = _jadwal;
    final hadir = _antrean.length;
    final diukur = _antrean.where((a) => a.sudahDiukur).length;
    final menunggu = hadir - diukur;
    final belumDiukur = _antrean.where((a) => !a.sudahDiukur).toList();

    return HomeShell(
      peran: 'Kader',
      lokasi: 'Posyandu Melati RW 04',
      notif: 3,
      children: [
        SyncStrip(
          online: _gagal == null,
          tertunda: _tertunda,
          sinkronTerakhir: _sinkronTerakhir,
          sedangSinkron: _sinkronBerjalan,
          onSinkron: _sinkronkan,
        ),

        if (_memuat)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_gagal != null)
          SectionCard(
            color: AppColors.kuningMuda,
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: AppColors.kuning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_gagal!,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
          )
        else if (j == null)
          SectionCard(
            title: 'Jadwal Posyandu',
            icon: Icons.event_busy,
            child: const Text(
              'Belum ada jadwal posyandu aktif. Antrean pendataan muncul setelah admin menerbitkan jadwal.',
              style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
            ),
          )
        else ...[
          // Sesi berjalan
          SectionCard(
            color: AppColors.hijauMuda,
            child: Row(
              children: [
                const Icon(Icons.event_available, color: AppColors.hijau),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sesi Posyandu Terdekat',
                          style: TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                      Text(formatTanggal(j.tanggal),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      if (j.lokasi.isNotEmpty)
                        Text(j.lokasi,
                            style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(j.jam.replaceAll(' - ', ' -\n'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),

          // Kehadiran (check-in oleh orang tua)
          SectionCard(
            title: 'Kehadiran Balita',
            icon: Icons.groups_2_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: StatBox(
                            nilai: '$hadir',
                            label: 'Sudah\ncheck-in',
                            bg: AppColors.biruMuda)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: StatBox(
                            nilai: '$diukur',
                            label: 'Sudah\ndiukur',
                            bg: AppColors.hijauMuda,
                            fg: AppColors.hijau)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: StatBox(
                            nilai: '$menunggu',
                            label: 'Menunggu\npengukuran',
                            bg: AppColors.kuningMuda,
                            fg: AppColors.kuning)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: hadir == 0 ? 0 : diukur / hadir,
                    minHeight: 8,
                    backgroundColor: AppColors.isiField,
                    color: AppColors.hijau,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('$diukur dari $hadir balita yang check-in sudah diukur',
                      style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                ),
              ],
            ),
          ),

          // Antrean pendataan
          SectionCard(
            color: AppColors.hijau,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Antrean Pendataan',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                    'Orang tua check-in dengan scan QR. Balita yang sudah check-in otomatis masuk antrean ini.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _aksiPutih(Icons.edit_note, 'Buka Antrean Pendataan', _bukaAntrean),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _aksiKecil(Icons.qr_code_2, 'QR Check-in\nPosyandu', _bukaAntrean),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _aksiKecil(Icons.straighten, 'Ukur Data\nBB TB LK LiLA', _bukaAntrean),
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

          // Antrean menunggu pengukuran
          SectionCard(
            title: 'Menunggu Pengukuran',
            icon: Icons.format_list_numbered,
            trailing: Pill('${belumDiukur.length} menunggu',
                bg: AppColors.hijauMuda, fg: AppColors.hijau),
            child: belumDiukur.isEmpty
                ? const Text('Tidak ada balita yang menunggu pengukuran.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup))
                : Column(children: [for (final a in belumDiukur) _barisAntrean(a)]),
          ),
        ],

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

  Widget _barisAntrean(AntreanKader a) {
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
            child: Text(a.nomor?.toString() ?? '-',
                style: const TextStyle(color: AppColors.hijau, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.nama,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text(
                    '${a.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${a.usiaBulan >= 12 ? '${a.usiaBulan ~/ 12} th ${a.usiaBulan % 12} bln' : '${a.usiaBulan} bln'}',
                    style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                const SizedBox(height: 4),
                const Pill('Sudah check-in', bg: AppColors.hijauMuda, fg: AppColors.hijau),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 92,
            child: AppButton('Ukur\nSekarang', onPressed: _bukaAntrean),
          ),
        ],
      ),
    );
  }
}