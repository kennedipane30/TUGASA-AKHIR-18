import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';

// ---------------------------------------------------------------------------
// DATA CONTOH. Ganti dengan data dari API / database lokal perangkat bidan.
// ---------------------------------------------------------------------------
class _Review {
  final String nama;
  final String usia;
  final String nik;
  final double bb, tb, lk, lla;
  final String keterangan;
  final Gizi tingkat;
  const _Review({
    required this.nama,
    required this.usia,
    required this.nik,
    required this.bb,
    required this.tb,
    required this.lk,
    required this.lla,
    required this.keterangan,
    required this.tingkat,
  });
}

class _Risiko {
  final String judul;
  final String detail;
  final int jumlah;
  final Gizi tingkat;
  const _Risiko(this.judul, this.detail, this.jumlah, this.tingkat);
}

class BidanHome extends StatefulWidget {
  const BidanHome({super.key});

  @override
  State<BidanHome> createState() => _BidanHomeState();
}

class _BidanHomeState extends State<BidanHome> {
  // Jumlah data menunggu verifikasi (BD-02 poin 1).
  int _menunggu = 12;

  final List<_Review> _review = [
    const _Review(
      nama: 'Alvino Pratama',
      usia: '18 bln',
      nik: '3201••••••4421 · RW 03',
      bb: 9.1,
      tb: 78.0,
      lk: 46.0,
      lla: 13.5,
      keterangan: 'BB turun 2 kali berturut-turut',
      tingkat: Gizi.risiko,
    ),
    const _Review(
      nama: 'Maya Safitri',
      usia: '6 bln',
      nik: '3201••••••8812 · RW 01',
      bb: 7.2,
      tb: 65.0,
      lk: 42.5,
      lla: 13.8,
      keterangan: 'Tumbuh baik, naik 0.3 kg',
      tingkat: Gizi.baik,
    ),
  ];

  static const _risiko = <_Risiko>[
    _Risiko('Gizi Buruk', 'BB/TB < -3 SD', 1, Gizi.risiko),
    _Risiko('Stunting', 'TB/U < -2 SD', 2, Gizi.risiko),
    _Risiko('BB Tidak Naik', '2T berturut-turut', 3, Gizi.waspada),
    _Risiko('Gizi Kurang', 'BB/TB -3 s.d. -2 SD', 4, Gizi.waspada),
  ];

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  // BD-02 poin 2: setujui, data terverifikasi dan dikunci.
  void _validasi(_Review r) {
    setState(() {
      _review.remove(r);
      if (_menunggu > 0) _menunggu--;
    });
    _pesan('Data ${r.nama} divalidasi dan dikunci');
  }

  // BD-02 poin 2: kembalikan ke kader beserta alasan.
  Future<void> _kembalikan(_Review r) async {
    final alasan = TextEditingController();
    final hasil = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kembalikan data ${r.nama}'),
        content: TextField(
          controller: alasan,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tulis alasan agar kader dapat mengoreksi',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, alasan.text.trim()),
            child: const Text('Kembalikan'),
          ),
        ],
      ),
    );
    alasan.dispose();
    if (hasil == null) return;
    if (hasil.isEmpty) {
      _pesan('Alasan wajib diisi');
      return;
    }
    setState(() => _review.remove(r));
    _pesan('Data ${r.nama} dikembalikan ke kader');
  }

  @override
  Widget build(BuildContext context) {
    return HomeShell(
      peran: 'Bidan',
      lokasi: 'Wilayah kerja Posyandu Melati',
      notif: 4,
      children: [
        // BD-02: verifikasi dan kunci data
        SectionCard(
          color: AppColors.hijau,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Tugas Utama',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  Pill('$_menunggu Balita', bg: Colors.white, fg: AppColors.hijau),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Verifikasi & Kunci Data Antropometri',
                  style: TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('$_menunggu data pengukuran kader butuh konfirmasi klinis sebelum dikunci.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.hijau,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => soon(context, 'Daftar verifikasi per sesi'),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text('Mulai Verifikasi Data ($_menunggu)',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),

        // BD-04: deteksi dini dan rujukan
        SectionCard(
          title: 'Deteksi Dini & Risiko',
          icon: Icons.health_and_safety_outlined,
          trailing: TextButton(
            onPressed: () => soon(context, 'Daftar prioritas anak berisiko'),
            child: const Text('Lihat Semua'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_risiko.fold<int>(0, (s, r) => s + r.jumlah)} balita butuh intervensi klinis segera',
                  style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
                children: [for (final r in _risiko) _kotakRisiko(r)],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppButton('Buat Surat Rujukan Puskesmas',
                    icon: Icons.local_hospital_outlined,
                    filled: false,
                    color: AppColors.merah,
                    onPressed: () => soon(context, 'Surat rujukan')),
              ),
            ],
          ),
        ),

        // BD-02: review antropometri cepat
        SectionCard(
          title: 'Review Antropometri Cepat',
          icon: Icons.rule_folder_outlined,
          trailing: const Pill('Prioritas Verifikasi', bg: AppColors.kuningMuda, fg: AppColors.kuning),
          child: _review.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('Semua data pada daftar ini sudah ditinjau',
                        style: TextStyle(color: AppColors.teksRedup)),
                  ),
                )
              : Column(children: [for (final r in _review) _kartuReview(r)]),
        ),

        // BD-03: imunisasi dan suplemen
        SectionCard(
          title: 'Imunisasi & Suplemen',
          icon: Icons.vaccines_outlined,
          trailing: const Pill('8 Terjadwal', bg: AppColors.biruMuda, fg: AppColors.biru),
          child: Column(
            children: [
              _cakupan('BCG', 0.92),
              _cakupan('Pentavalen', 0.85),
              _cakupan('Polio / IPV', 0.78),
              _cakupan('Campak-Rubella', 0.70),
              _cakupan('Vitamin A', 0.80),
              _cakupan('PMT Pemulihan', 0.55),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: AppButton('Catat Vaksin',
                        icon: Icons.vaccines,
                        onPressed: () => soon(context, 'Pencatatan imunisasi')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton('Vit A / Obat Cacing',
                        icon: Icons.medication_outlined,
                        filled: false,
                        onPressed: () => soon(context, 'Pencatatan suplemen')),
                  ),
                ],
              ),
            ],
          ),
        ),

        // BD-06: laporan bulanan SKDN
        SectionCard(
          title: 'Laporan Bulanan (SKDN)',
          icon: Icons.assessment_outlined,
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(child: StatBox(nilai: '348', label: 'S\nSasaran')),
                  SizedBox(width: 8),
                  Expanded(child: StatBox(nilai: '348', label: 'K\nPunya KMS')),
                  SizedBox(width: 8),
                  Expanded(
                      child: StatBox(
                          nilai: '308', label: 'D\nDitimbang', bg: AppColors.hijauMuda, fg: AppColors.hijau)),
                  SizedBox(width: 8),
                  Expanded(
                      child: StatBox(
                          nilai: '274', label: 'N\nNaik BB', bg: AppColors.biruMuda, fg: AppColors.biru)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppButton('Ekspor Laporan PDF / Excel',
                    icon: Icons.download,
                    filled: false,
                    onPressed: () => soon(context, 'Ekspor laporan bulanan')),
              ),
            ],
          ),
        ),

        // BD-05: pemantauan
        SectionCard(
          title: 'Pemantauan Anak',
          icon: Icons.search,
          child: Column(
            children: [
              TextField(
                readOnly: true,
                onTap: () => soon(context, 'Pencarian anak'),
                decoration: InputDecoration(
                  hintText: 'Cari nama anak, NIK anak, atau NIK orang tua',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.isiField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kotakRisiko(_Risiko r) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: giziBg(r.tingkat),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('${r.jumlah}',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: giziFg(r.tingkat))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.judul,
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: giziFg(r.tingkat))),
                Text(r.detail,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuReview(_Review r) {
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
              CircleAvatar(
                backgroundColor: giziBg(r.tingkat),
                child: Text(r.nama.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                        color: giziFg(r.tingkat), fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.nama} (${r.usia})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text('NIK: ${r.nik}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Pill(r.keterangan, bg: giziBg(r.tingkat), fg: giziFg(r.tingkat)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StatBox(nilai: '${r.bb}', label: 'BB (kg)', bg: Colors.white)),
              const SizedBox(width: 6),
              Expanded(child: StatBox(nilai: '${r.tb}', label: 'TB (cm)', bg: Colors.white)),
              const SizedBox(width: 6),
              Expanded(child: StatBox(nilai: '${r.lk}', label: 'LK (cm)', bg: Colors.white)),
              const SizedBox(width: 6),
              Expanded(child: StatBox(nilai: '${r.lla}', label: 'LiLA (cm)', bg: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton('Kembalikan',
                    icon: Icons.undo,
                    filled: false,
                    color: AppColors.kuning,
                    onPressed: () => _kembalikan(r)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton('Validasi & Catat',
                    icon: Icons.verified_outlined, onPressed: () => _validasi(r)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cakupan(String nama, double nilai) {
    final warna = nilai >= 0.8 ? AppColors.hijau : (nilai >= 0.65 ? AppColors.kuning : AppColors.merah);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(nama, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: nilai,
                minHeight: 8,
                backgroundColor: AppColors.isiField,
                color: warna,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(nilai * 100).round()}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: warna)),
        ],
      ),
    );
  }
}
