import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../core/posyandu.dart';
import '../auth/auth_provider.dart';

const _hijauTua = Color(0xFF0F3D2E);
const _merah = Color(0xFFDC2626);
const _merahTua = Color(0xFFB91C1C);
const _oranye = Color(0xFFF97316);
const _persik = Color(0xFFFFE4DC);
const _pink = Color(0xFFFFF0F0);
const _abu = Color(0xFFE9ECEF);

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
  final Color bg;
  final Color fg;
  const _Risiko(this.judul, this.detail, this.jumlah, this.bg, this.fg);
}

class BidanHome extends StatefulWidget {
  const BidanHome({super.key});

  @override
  State<BidanHome> createState() => _BidanHomeState();
}

class _BidanHomeState extends State<BidanHome> {
  int _menunggu = 12;
  int _filter = 0;

  static const _filterLabel = ['Semua', 'Perlu Tindakan (10)', 'Gizi Kurang', 'Stunting'];

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
    _Risiko('Gizi Buruk', 'BB/TB < -3 SD', 1, _persik, _merah),
    _Risiko('Stunting', 'TB/U < -2 SD', 2, _persik, Color(0xFFEA580C)),
    _Risiko('BB Tdk Naik', '2T berturut-turut', 3, _persik, Color(0xFFEA580C)),
    _Risiko('Gizi Kurang', 'BB/TB -3 s.d. -2 SD', 4, _abu, Color(0xFF374151)),
  ];

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  void _validasi(_Review r) {
    setState(() {
      _review.remove(r);
      if (_menunggu > 0) _menunggu--;
    });
    _pesan('Data ${r.nama} divalidasi dan dikunci');
  }

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
    final user = context.watch<AuthProvider>().user;
    final pos = (user?['posyandu'] ?? '').toString();
    final lokasi = pos.isEmpty
        ? 'Posyandu belum ditetapkan, hubungi admin'
        : 'Wilayah kerja Posyandu ${labelPosyandu(pos)}';

    return HomeShell(
      peran: 'Bidan',
      lokasi: lokasi,
      notif: 4,
      children: [
        // Pencarian + filter
        _pencarian(),

        // Tugas utama
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hijauTua,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('TUGAS UTAMA BIDAN',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$_menunggu Balita',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Verifikasi & Kunci Data\nAntropometri',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  '$_menunggu data pengukuran kader butuh konfirmasi klinis sebelum dikunci ke database nasional.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.white,
                    foregroundColor: _hijauTua,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => soon(context, 'Daftar verifikasi per sesi'),
                  icon: const Icon(Icons.fact_check_outlined, size: 20),
                  label: Text('Mulai Verifikasi Data ($_menunggu)',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),

        // Deteksi dini
        SectionCard(
          title: 'Deteksi Dini & Risiko',
          icon: Icons.shield_outlined,
          trailing: TextButton(
            onPressed: () => soon(context, 'Daftar prioritas anak berisiko'),
            child: const Text('Lihat Semua',
                style: TextStyle(color: _oranye, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${_risiko.fold<int>(0, (s, r) => s + r.jumlah)} balita butuh intervensi klinis segera',
                  style: const TextStyle(fontSize: 12, color: AppColors.teksRedup)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [for (final r in _risiko) _kotakRisiko(r)],
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => soon(context, 'Surat rujukan'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _pink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_hospital_outlined, color: _merah, size: 18),
                      SizedBox(width: 8),
                      Text('Buat Surat Rujukan Puskesmas',
                          style: TextStyle(
                              color: _merah, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Review antropometri
        SectionCard(
          title: 'Review Antropometri Cepat',
          icon: Icons.check_circle_outline,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Prioritas',
                style: TextStyle(
                    color: Color(0xFFEA580C), fontSize: 11, fontWeight: FontWeight.w800)),
          ),
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

        // Imunisasi
        SectionCard(
          title: 'Imunisasi & Suplemen',
          icon: Icons.vaccines_outlined,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.biruMuda,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('8 Terjadwal',
                style: TextStyle(
                    color: AppColors.biru, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
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
                    child: _tombol('Catat Vaksin', Icons.vaccines,
                        bg: _merahTua,
                        fg: Colors.white,
                        onTap: () => soon(context, 'Pencatatan imunisasi')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tombol('Vit A / Obat Cacing', Icons.medication_outlined,
                        bg: AppColors.latar,
                        fg: Colors.black87,
                        border: true,
                        onTap: () => soon(context, 'Pencatatan suplemen')),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Laporan SKDN
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
                          nilai: '308',
                          label: 'D\nDitimbang',
                          bg: AppColors.hijauMuda,
                          fg: AppColors.hijau)),
                  SizedBox(width: 8),
                  Expanded(
                      child: StatBox(
                          nilai: '274',
                          label: 'N\nNaik BB',
                          bg: AppColors.biruMuda,
                          fg: AppColors.biru)),
                ],
              ),
              const SizedBox(height: 10),
              _tombol('Ekspor Laporan PDF / Excel', Icons.download,
                  bg: AppColors.latar,
                  fg: Colors.black87,
                  border: true,
                  onTap: () => soon(context, 'Ekspor laporan bulanan')),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  Widget _pencarian() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.isiField),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.teksRedup),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => soon(context, 'Pencarian anak'),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama anak, NIK atau nama ibu...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.teksRedup),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.isiField,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _filterLabel.length; i++) ...[
                _chip(i),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(int i) {
    final aktif = _filter == i;
    final warna = i == 1 ? _merah : (i == 2 ? _oranye : AppColors.teksRedup);
    final bg = i == 1 ? _pink : (i == 2 ? const Color(0xFFFFEDD5) : AppColors.isiField);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? _hijauTua : bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(_filterLabel[i],
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: aktif ? Colors.white : warna)),
      ),
    );
  }

  Widget _tombol(String label, IconData ikon,
      {required Color bg,
      required Color fg,
      required VoidCallback onTap,
      bool border = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border ? Border.all(color: Colors.black12) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kotakRisiko(_Risiko r) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: r.bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${r.jumlah}',
                  style: TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: r.fg)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(r.judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: r.fg)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.detail,
              style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
        ],
      ),
    );
  }

  Widget _bulat(String nilai, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Text(nilai,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
      ],
    );
  }

  Widget _kartuReview(_Review r) {
    final naik = r.tingkat == Gizi.baik;
    final warna = naik ? AppColors.hijau : _merah;
    final bg = naik ? AppColors.hijauMuda : _pink;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.isiField),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: bg,
                child: Text(r.nama.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                        color: warna, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.nama} (${r.usia})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text('NIK: ${r.nik}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.teksRedup)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(naik ? Icons.trending_up : Icons.trending_down, size: 14, color: warna),
                const SizedBox(width: 6),
                Text(r.keterangan,
                    style: TextStyle(
                        color: warna, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.latar,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _bulat('${r.bb}', 'BB (kg)'),
                _bulat('${r.tb}', 'TB (cm)'),
                _bulat('${r.lk}', 'LK (cm)'),
                _bulat('${r.lla}', 'LiLA (cm)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tombol('Kembalikan', Icons.undo,
                    bg: AppColors.latar,
                    fg: Colors.black87,
                    border: true,
                    onTap: () => _kembalikan(r)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tombol('Validasi & Catat', Icons.verified_outlined,
                    bg: _hijauTua, fg: Colors.white, onTap: () => _validasi(r)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cakupan(String nama, double nilai) {
    final warna = nilai >= 0.8 ? _hijauTua : (nilai >= 0.65 ? _oranye : _merah);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(nama,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
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
          SizedBox(
            width: 34,
            child: Text('${(nilai * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: warna)),
          ),
        ],
      ),
    );
  }
}