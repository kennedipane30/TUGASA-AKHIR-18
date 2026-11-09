import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'jadwal/admin_jadwal_page.dart';
import 'riwayat/admin_riwayat_page.dart';
import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../core/qr_checkin_page.dart';
import '../auth/auth_provider.dart';
import 'akun/admin_kelola_akun_page.dart';
import '../../core/semua_balita_page.dart';
import '../../core/skdn_page.dart';
import '../../service/skdn_service.dart';
import 'rekap/admin_rekap_page.dart';
import 'vaksin/admin_vaksin_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  // Status sinkronisasi (AD-03 poin 5). Ganti dengan data dari service sinkron.
  bool _sinkronBerjalan = false;
  int _tertunda = 3;
  String _sinkronTerakhir = '10 menit lalu';

  // Tugas tertunda (AD-02 reset sandi, AD-06 koreksi data).
  final List<(String, String, String)> _tugas = [
    ('Reset sandi', 'Ibu Rahmawati (orang tua) meminta reset kata sandi', 'Setujui'),
    ('Koreksi NIK', 'Aisyah Putri: pengajuan koreksi NIK dari orang tua', 'Periksa'),
  ];

  // Ringkasan penimbangan (SKDN) bulan berjalan.
  SkdnData? _skdn;
  bool _skdnMemuat = true;

  @override
  void initState() {
    super.initState();
    _muatSkdn();
  }

  Future<void> _muatSkdn() async {
    try {
      final d = await const SkdnService('/sekretaris').hitung();
      if (!mounted) return;
      setState(() {
        _skdn = d;
        _skdnMemuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _skdnMemuat = false);
    }
  }

  Future<void> _bukaSkdn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SkdnPage(prefix: '/sekretaris')),
    );
    _muatSkdn();
  }

  Future<void> _sinkronkan() async {
    setState(() => _sinkronBerjalan = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _sinkronBerjalan = false;
      _tertunda = 0;
      _sinkronTerakhir = 'baru saja';
    });
  }

  void _selesaikanTugas(int i) {
    final judul = _tugas[i].$1;
    // Ganti dengan pemanggilan API (reset sandi / tinjau koreksi).
    setState(() => _tugas.removeAt(i));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$judul diproses (contoh tampilan)')));
  }

  void _bukaVaksin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminVaksinPage()),
    );
  }

  void _bukaRekap([int tab = 0]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminRekapPage(tabAwal: tab)),
    );
  }

  void _bukaBalita() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SemuaBalitaPage(prefix: '/sekretaris')),
    );
  }

  void _bukaJadwal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminJadwalPage()),
    );
  }

  void _bukaRiwayat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminRiwayatPage()),
    );
  }

  void _bukaAkun() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const AdminKelolaAkunPage(denganTombolKembali: true)),
    );
  }

  void _bukaQr() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrCheckinPage(role: 'sekretaris')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final nama = (user?['nama'] ?? 'Sekretaris').toString();
    final desa = (user?['posyandu_nama'] ?? '').toString();
    final labelDesa = desa.isEmpty ? 'Posyandu' : 'Posyandu $desa';

    return HomeShell(
      peran: 'Sekretaris',
      lokasi: labelDesa,
      notif: _tugas.length,
      children: [
        // Sapaan
        SectionCard(
          color: AppColors.hijauMuda,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pill(desa.isEmpty ? 'Sekretaris Posyandu' : 'Sekretaris $desa',
                  bg: Colors.white, fg: AppColors.hijau),
              const SizedBox(height: 8),
              Text('Selamat bertugas, $nama',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text(
                  'Kelola akun kader dan bidan, jadwal, data vaksin, dan laporan untuk desa Anda.',
                  style: TextStyle(fontSize: 14, color: AppColors.teksRedup)),
            ],
          ),
        ),

        // Status sinkronisasi (AD-03 poin 5, AD-10 poin 3)
        SyncStrip(
          online: true,
          tertunda: _tertunda,
          sinkronTerakhir: _sinkronTerakhir,
          sedangSinkron: _sinkronBerjalan,
          onSinkron: _sinkronkan,
        ),

        // Aksi cepat (ikon dari assets)
        _gridAset('Layanan Sekretaris', 'Kelola data, jadwal, dan laporan posyandu', [
          _itemAset('kelola_akun.png', Icons.manage_accounts, AppColors.hijau,
              'Kelola\nAkun', _bukaAkun),
          _itemAset('jadwal.png', Icons.calendar_month, AppColors.hijau,
              'Jadwal &\nAgenda', _bukaJadwal),
          _itemAset('riwatar_pemeriksaan.png', Icons.history, AppColors.hijau,
              'Riwayat\nPemeriksaan', _bukaRiwayat),
          _itemAset('qr_chekin.png', Icons.qr_code_2, AppColors.hijau,
              'QR\nCheck-in', _bukaQr),
          _itemAset('vaksin_anak.png', Icons.vaccines_outlined, AppColors.hijau,
              'Data\nVaksin', _bukaVaksin),
          _itemAset('pengumuman.png', Icons.campaign_outlined, AppColors.hijau,
              'Pengumuman', () => soon(context, 'Pengumuman')),
          _itemAset('semua_balita.png', Icons.child_care, AppColors.hijau,
              'Semua\nBalita', _bukaBalita),
          _itemAset('data_master.png', Icons.dataset_outlined, AppColors.hijau,
              'Data\nMaster', () => soon(context, 'Data master')),
          _itemAset('rekap_posyandu.png', Icons.summarize_outlined, AppColors.hijau,
              'Rekap\nPosyandu', () => _bukaRekap(0)),
          _itemAset('rekap_skdn.png', Icons.analytics_outlined, AppColors.hijau,
              'Ringkasan\nPenimbangan', _bukaSkdn),
        ]),

        // AD-03: sasaran balita
        SectionCard(
          title: 'Sasaran Balita',
          icon: Icons.groups_outlined,
          trailing: const Pill('+12 bulan ini', bg: AppColors.hijauMuda, fg: AppColors.hijau),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('348',
                      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800)),
                  SizedBox(width: 8),
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Jiwa terdaftar di wilayah',
                        style: TextStyle(fontSize: 15, color: AppColors.teksRedup)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Expanded(child: StatBox(nilai: '96', label: '0-11 bln')),
                  SizedBox(width: 8),
                  Expanded(child: StatBox(nilai: '126', label: '12-23 bln')),
                  SizedBox(width: 8),
                  Expanded(child: StatBox(nilai: '126', label: '24-59 bln')),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Laki-laki 178 (51%)  ·  Perempuan 170 (49%)',
                  style: TextStyle(fontSize: 14, color: AppColors.teksRedup)),
            ],
          ),
        ),

        // Data vaksin: jumlah vaksin diberikan dan jenis vaksin
        SectionCard(
          title: 'Data Vaksin',
          icon: Icons.vaccines_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lihat jumlah vaksin yang sudah diberikan dan jenis-jenis vaksin.',
                style: TextStyle(fontSize: 14, color: AppColors.teksRedup),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppButton('Lihat Data Vaksin',
                    icon: Icons.bar_chart, onPressed: _bukaVaksin),
              ),
            ],
          ),
        ),

        // AD-03 poin 2: tren kehadiran
        SectionCard(
          title: 'Tren Kehadiran per Pelaksanaan',
          icon: Icons.bar_chart,
          child: const MiniBars(
            nilai: [286, 301, 295, 318, 305, 322],
            label: ['Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt'],
          ),
        ),

        // AD-03 poin 3: status gizi dan stunting
        SectionCard(
          title: 'Status Gizi & Stunting',
          icon: Icons.pie_chart_outline,
          child: Column(
            children: [
              _barisGizi('Gizi Baik / Normal', 312, 89.7, Gizi.baik),
              _barisGizi('Gizi Kurang / Defisit BB', 24, 6.9, Gizi.waspada),
              _barisGizi('Berisiko Stunting (pendek/sangat pendek)', 12, 3.4, Gizi.risiko),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _bukaRekap(0),
                  child: const Text('Lihat Rekap Status Gizi'),
                ),
              ),
            ],
          ),
        ),

        // Ringkasan penimbangan (SKDN) bulan berjalan
        _kartuSkdn(),

        // AD-04: jadwal posyandu desa
        SectionCard(
          title: 'Jadwal $labelDesa',
          icon: Icons.event,
          trailing: const Pill('Jadwal Desa', bg: AppColors.hijauMuda, fg: AppColors.hijau),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buat, ubah, atau batalkan jadwal posyandu di desa Anda. Orang tua di desa lain tidak melihat jadwal ini.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text('Pendaftaran dibuka sejak jadwal dibuat, check-in 1 jam sebelumnya.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.teksRedup)),
              const SizedBox(height: 10),
              AppButton('Kelola Jadwal',
                  icon: Icons.edit_calendar, filled: false, onPressed: _bukaJadwal),
            ],
          ),
        ),

        // AD-02 poin 3 dan AD-06 poin 3: verifikasi dan tugas tertunda
        SectionCard(
          title: 'Verifikasi & Tugas Tertunda',
          icon: Icons.pending_actions,
          trailing: Pill('${_tugas.length} tindakan',
              bg: AppColors.kuningMuda, fg: AppColors.kuning),
          child: _tugas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text('Tidak ada tugas tertunda',
                        style: TextStyle(fontSize: 15, color: AppColors.teksRedup)),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < _tugas.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_tugas[i].$1,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        subtitle: Text(_tugas[i].$2, style: const TextStyle(fontSize: 13.5)),
                        trailing: SizedBox(
                          width: 84,
                          child: AppButton(_tugas[i].$3, onPressed: () => _selesaikanTugas(i)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String _persen(double v) =>
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}%';

  Widget _kartuSkdn() {
    final d = _skdn;
    final b = d?.bulan;
    return SectionCard(
      title: 'Ringkasan Penimbangan',
      icon: Icons.analytics_outlined,
      trailing: IconButton(
        tooltip: 'Penjelasan',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.info_outline, color: AppColors.biru),
        onPressed: () => tampilkanPenjelasanSkdn(context),
      ),
      child: _skdnMemuat
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          : b == null
              ? Column(
                  children: [
                    const Text('Ringkasan penimbangan belum dapat dimuat.',
                        style: TextStyle(fontSize: 14, color: AppColors.teksRedup)),
                    TextButton(
                      onPressed: () {
                        setState(() => _skdnMemuat = true);
                        _muatSkdn();
                      },
                      child: const Text('Coba lagi'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.label,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.teksRedup)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: StatBox(nilai: '${b.s}', label: 'Seluruh\nbalita')),
                        const SizedBox(width: 8),
                        Expanded(child: StatBox(nilai: '${b.k}', label: 'Punya\nBuku KIA')),
                        const SizedBox(width: 8),
                        Expanded(
                            child: StatBox(
                                nilai: '${b.d}',
                                label: 'Datang\nditimbang',
                                bg: AppColors.hijauMuda,
                                fg: AppColors.hijau)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: StatBox(
                                nilai: '${b.n}',
                                label: 'Berat\nbadan naik',
                                bg: AppColors.biruMuda,
                                fg: AppColors.biru)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Pill('Kehadiran ${_persen(b.persenDS)}',
                            bg: d!.capaiTarget ? AppColors.hijauMuda : AppColors.merahMuda,
                            fg: d.capaiTarget ? AppColors.hijau : AppColors.merah),
                        Pill('Tumbuh baik ${_persen(b.persenND)}',
                            bg: AppColors.biruMuda, fg: AppColors.biru),
                        if (b.duaT + b.bgm > 0)
                          Pill('${d.perluRujuk.length} perlu dirujuk',
                              bg: AppColors.merahMuda,
                              fg: AppColors.merah,
                              icon: Icons.warning_amber_rounded),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Target kehadiran minimal ${_persen(d.targetDS)}',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.teksRedup)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _bukaSkdn,
                        child: const Text('Lihat Ringkasan Lengkap'),
                      ),
                    ),
                  ],
                ),
    );
  }

  // -------------------------------------------------------------------------
  // Ikon menu dari assets (gaya sama dengan beranda orang tua)
  // -------------------------------------------------------------------------
  Widget _itemAset(String aset, IconData cadangan, Color warna, String judul,
      VoidCallback onTap, {int? badge, Color badgeWarna = const Color(0xFFE11D48)}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      aset,
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Icon(cadangan, color: warna, size: 38),
                    ),
                  ),
                  if (badge != null && badge > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeWarna,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                judul,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: Color(0xFF0F2547),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridAset(String judul, String sub, List<Widget> item) {
    final baris = <Widget>[];
    for (var i = 0; i < item.length; i += 4) {
      final potong = item.sublist(i, i + 4 > item.length ? item.length : i + 4);
      baris.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...potong,
              for (var k = potong.length; k < 4; k++) const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    judul,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.2,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Layanan Utama',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teksRedup,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 14),
            child: Text(
              sub,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.teksRedup,
              ),
            ),
          ),
          ...baris,
        ],
      ),
    );
  }

  Widget _barisGizi(String label, int jumlah, double persen, Gizi g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
              Text('$jumlah ($persen%)',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: giziFg(g))),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: persen / 100,
              minHeight: 8,
              backgroundColor: giziBg(g),
              color: giziFg(g),
            ),
          ),
        ],
      ),
    );
  }
}