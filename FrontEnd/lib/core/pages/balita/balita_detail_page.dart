import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../../service/balita_service.dart';
import '../../../service/imunisasi_service.dart' show namaSuplemen;
import '../../../features/Bidan/imunisasi/imunisasi_lihat_body.dart';
import '../rekap/rekap_posyandu_page.dart';
import 'arsip_balita_page.dart';
import 'semua_balita_page.dart' show labelTimbang;

/// Detail satu balita: profil & keluarga, riwayat penimbangan (beserta catatan
/// kader, catatan bidan, imunisasi, dan suplemen tiap kunjungan), dan imunisasi.
/// [tabAwal] 0 = Profil, 1 = Penimbangan (kunjungan terbaru langsung terbuka), 2 = Imunisasi.
const _biru = Color(0xFF2563EB);
const _biruMuda = Color(0xFFE3F2FD);
const _biruGaris = Color(0xFFBFDFF7);
const _hijauTua = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi tab & kartu halaman detail: hitam lembut (tidak mencolok).
const _garis = Color(0xFFB8BEC6);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

BoxDecoration _dekorKartu() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Kepala kartu: judul tebal kapital di kiri, keterangan di kanan, garis aksen di bawah.
Widget _kepala(String judul, {String? kanan}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                judul.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _teksGelap,
                ),
              ),
            ),
            if (kanan != null && kanan.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(kanan,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Tautan kecil hijau lembut bergaris bawah.
Widget _tautan(String teks) => Text(
      teks,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: _aksen,
        decoration: TextDecoration.underline,
        decorationColor: _aksen,
      ),
    );

class BalitaDetailPage extends StatefulWidget {
  final String prefix;
  final String anakId;
  final String nama;
  final bool bisaKelolaImunisasi;
  final int tabAwal;

  const BalitaDetailPage({
    super.key,
    required this.prefix,
    required this.anakId,
    required this.nama,
    this.bisaKelolaImunisasi = false,
    this.tabAwal = 0,
  });

  @override
  State<BalitaDetailPage> createState() => _BalitaDetailPageState();
}

class _BalitaDetailPageState extends State<BalitaDetailPage> {
  late final BalitaService _svc = BalitaService(widget.prefix);
  DetailBalita? _data;
  bool _loading = true;
  String? _error;
  late int _tab = (widget.tabAwal < 0 || widget.tabAwal > 2) ? 0 : widget.tabAwal;
  late final Set<int> _terbuka = {if (widget.tabAwal == 1) 0};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final d = await _svc.detail(widget.anakId);
      if (!mounted) return;
      setState(() {
        _data = d;
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

  bool get _kader => widget.prefix == '/kader';

  void _snack(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  /// Kader: arsipkan anak (pindah / meninggal / lainnya).
  Future<void> _arsipkan(BalitaItem r) async {
    final isian = await bukaFormArsip(context, nama: r.nama, lahir: r.tanggalLahir);
    if (isian == null || !mounted) return;
    if (!await konfirmasiArsip(context, r.nama, isian) || !mounted) return;
    try {
      await _svc.arsipkan(widget.anakId,
          alasan: isian.alasan, tanggal: isian.tanggalApi, keterangan: isian.keterangan);
      if (!mounted) return;
      _snack('Data ${r.nama} diarsipkan');
      await _muat();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Kader: aktifkan kembali anak arsip.
  Future<void> _aktifkan(BalitaItem r) async {
    if (!await konfirmasiAktifkan(context, r.nama) || !mounted) return;
    try {
      await _svc.aktifkan(widget.anakId);
      if (!mounted) return;
      _snack('Data ${r.nama} aktif kembali');
      await _muat();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Kartu status data anak (hanya kader): tombol Arsipkan / Aktifkan kembali.
  Widget _kartuStatus(BalitaItem r) {
    final lulus = r.alasanArsip.startsWith('Lulus balita');
    final Widget isi;
    if (!r.diarsipkan) {
      isi = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Arsipkan bila anak pindah domisili atau meninggal. Riwayat penimbangan '
            'dan imunisasi tetap tersimpan.',
            style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.teksRedup),
          ),
          const SizedBox(height: 12),
          _tombolGaris('Arsipkan Anak', Icons.archive_outlined, AppColors.merah, () => _arsipkan(r)),
        ],
      );
    } else if (lulus) {
      isi = const Text(
        'Anak sudah berusia 5 tahun dan diarsipkan otomatis oleh sistem (lulus balita).',
        style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.teksRedup),
      );
    } else {
      isi = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktifkan kembali bila salah arsip atau anak kembali ke desa.',
            style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.teksRedup),
          ),
          const SizedBox(height: 12),
          _tombolGaris('Aktifkan Kembali', Icons.unarchive_outlined, AppColors.hijau, () => _aktifkan(r)),
        ],
      );
    }
    return _kartu(judul: 'Status Data Anak', child: isi);
  }

  Widget _tombolGaris(String label, IconData ikon, Color warna, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(ikon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: warna,
          backgroundColor: Colors.white,
          side: BorderSide(color: warna, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const label = ['Profil', 'Penimbangan', 'Imunisasi'];
    return Scaffold(
      backgroundColor: AppColors.latar,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            headerRekap(context, widget.nama),
            // Tab dibuat kartu terpisah dengan sedikit celah.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  for (var i = 0; i < label.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _tombolTab(label[i], i)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _tab == 2
                  ? ImunisasiLihatBody(anakId: widget.anakId, bisaKelola: widget.bisaKelolaImunisasi)
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_error!, textAlign: TextAlign.center),
                                    const SizedBox(height: 12),
                                    AppButton('Coba Lagi', onPressed: _muat),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _muat,
                              child: _tab == 0 ? _profil(_data!) : _penimbangan(_data!),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombolTab(String teks, int i) {
    final dipilih = _tab == i;
    return Material(
      color: dipilih ? _hijauTua : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: dipilih ? _hijauTua : _garis, width: 1.2),
          ),
          child: Text(
            teks,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: dipilih ? Colors.white : _teksGelap,
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu putih berbayangan: kepala (judul + keterangan kanan + garis aksen), lalu isi.
  Widget _kartu({required String judul, String? kanan, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: _dekorKartu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kepala(judul, kanan: kanan),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  /// Usia detail saat penimbangan [t]; bila tanggal lahir tidak ada, pakai teks dari server.
  String _usiaUkur(DateTime? lahir, TimbangRingkas t) =>
      (lahir == null || t.tanggal == null) ? t.usiaTeks : usiaDetail(lahir, t.tanggal);

  // ===================================================================== profil

  String _t(dynamic v) => v?.toString().trim() ?? '';

  String _tglTeks(dynamic v) {
    final s = _t(v);
    if (s.length < 10) return '';
    final d = DateTime.tryParse(s.substring(0, 10));
    return d == null ? '' : formatTanggal(d);
  }

  Widget _baris(String l, String v) {
    if (v.isEmpty) return const SizedBox.shrink();
    const gaya = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.3, color: _teksGelap);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(l, style: gaya)),
          const Text(': ', style: gaya),
          Expanded(child: Text(v, style: gaya)),
        ],
      ),
    );
  }

  static const _lewatiKeluarga = {
    'id', 'created_at', 'updated_at', 'deleted_at', 'version', 'perangkat_asal', 'posyandu',
  };

  String _labelKunci(String k) {
    final kata = k.split('_').where((e) => e.isNotEmpty).map((e) {
      final u = e.toUpperCase();
      if (u == 'NIK' || u == 'KK' || u == 'RT' || u == 'RW' || u == 'HP') return u;
      return e[0].toUpperCase() + e.substring(1);
    });
    return kata.join(' ');
  }

  Widget _profil(DetailBalita d) {
    final a = d.anak;
    final r = d.ringkas;
    final num? beratLahir = num.tryParse(_t(a['berat_lahir_kg']));
    final num? panjangLahir = num.tryParse(_t(a['panjang_lahir_cm']));
    final keluarga = <MapEntry<String, String>>[];
    d.keluarga.forEach((k, v) {
      if (_lewatiKeluarga.contains(k) || k.endsWith('_id') || v is Map || v is List || v is bool) return;
      final s = _t(v);
      if (s.isEmpty) return;
      keluarga.add(MapEntry(_labelKunci(k), k.contains('tanggal') ? _tglTeks(v) : s));
    });
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _kartu(
          judul: r.nama,
          kanan: r.diarsipkan ? 'Tidak aktif' : 'Aktif',
          child: Column(
            children: [
              if (r.diarsipkan) ...[
                _baris('Keterangan', r.alasanArsip),
                _baris('Diarsipkan', r.tanggalArsip == null ? '' : formatTanggal(r.tanggalArsip!)),
              ],
              _baris('Jenis kelamin', r.jkTeks),
              _baris('Tanggal lahir', r.tanggalLahir == null ? '' : formatTanggal(r.tanggalLahir!)),
              _baris('Usia', usiaDetail(r.tanggalLahir)),
              _baris('NIK', _t(a['nik'])),
              _baris('Berat lahir', beratLahir == null ? '' : '$beratLahir kg'),
              _baris('Panjang lahir', panjangLahir == null ? '' : '$panjangLahir cm'),
              _baris('Anak ke', _t(a['anak_ke'])),
              _baris('Jumlah penimbangan', '${r.jumlahTimbang} kali'),
            ],
          ),
        ),
        _kartu(
          judul: 'Kondisi Terakhir',
          child: r.terakhir == null
              ? const Text('Belum pernah ditimbang di posyandu.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup))
              : _ringkasTimbang(r.terakhir!, r.tanggalLahir),
        ),
        _kartu(
          judul: 'Imunisasi',
          kanan: '${r.imunisasi.persen}%',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: r.imunisasi.totalDosis == 0 ? 0 : r.imunisasi.sudah / r.imunisasi.totalDosis,
                  minHeight: 8,
                  backgroundColor: AppColors.latar,
                  color: AppColors.hijau,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${r.imunisasi.sudah} dari ${r.imunisasi.totalDosis} dosis · '
                '${r.imunisasi.jatuhTempo} saatnya diberikan · ${r.imunisasi.terlambat} terlambat',
                style: const TextStyle(fontSize: 15.5),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => setState(() => _tab = 2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _tautan('Lihat jadwal & riwayat imunisasi'),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (keluarga.isNotEmpty)
          _kartu(
            judul: 'Data Keluarga',
            child: Column(children: [for (final e in keluarga) _baris(e.key, e.value)]),
          ),
        if (_kader) _kartuStatus(r),
      ],
    );
  }

  Widget _ringkasTimbang(TimbangRingkas t, DateTime? lahir) {
    String z(double? v) => v == null ? '-' : v.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kotak('${t.bbKg}', 'Berat Badan (kg)', const Color(0xFFE3F2FD), const Color(0xFFBFDFF7),
                  const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              _kotak('${t.tbCm}', 'Tinggi/Panjang (cm)', const Color(0xFFE6F8EF), const Color(0xFFBDEBD3),
                  const Color(0xFF059669)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kotak(t.lkCm == null ? '-' : '${t.lkCm}', 'Lingkar Kepala (cm)', const Color(0xFFFFF4DC),
                  const Color(0xFFF9E0A8), const Color(0xFFD97706)),
              const SizedBox(width: 10),
              _kotak(t.lilaCm == null ? '-' : '${t.lilaCm}', 'LiLA (cm)', const Color(0xFFFDEAF1),
                  const Color(0xFFF6C9D9), const Color(0xFFE11D48)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${t.tanggal == null ? '-' : formatTanggal(t.tanggal!)} · usia ${_usiaUkur(lahir, t)}',
          style: const TextStyle(fontSize: 15.5, color: AppColors.teksRedup),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _pill(t)),
        const SizedBox(height: 8),
        _baris('BB/U', t.kategoriBbu.isEmpty ? '' : '${t.kategoriBbu} (z ${z(t.zBbu)})'),
        _baris('TB/U', t.kategoriTbu.isEmpty ? '' : '${t.kategoriTbu} (z ${z(t.zTbu)})'),
        _baris('BB/TB', t.kategoriBbtb.isEmpty ? '' : '${t.kategoriBbtb} (z ${z(t.zBbtb)})'),
      ],
    );
  }

  Widget _kotak(String nilai, String label, Color bg, Color border, Color fg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              Text(nilai, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      );

  List<Widget> _pill(TimbangRingkas t) {
    final s = t.statusTimbang;
    return [
      if (s.isNotEmpty)
        Pill(
          labelTimbang(s),
          bg: s == 'N' ? AppColors.hijauMuda : (s == 'T' ? AppColors.merahMuda : AppColors.biruMuda),
          fg: s == 'N' ? AppColors.hijau : (s == 'T' ? AppColors.merah : AppColors.biru),
        ),
      if (t.kenaikanGram != null)
        Pill(
          '${t.kenaikanGram! > 0 ? '+' : ''}${t.kenaikanGram} g${t.kbmGram == null ? '' : ' (KBM ${t.kbmGram} g)'}',
          bg: AppColors.latar,
          fg: Colors.black87,
        ),
      if (t.duaT) const Pill('2T', bg: AppColors.merahMuda, fg: AppColors.merah),
      if (t.bgm) const Pill('BGM', bg: AppColors.merahMuda, fg: AppColors.merah),
      if (t.masalah.isEmpty && t.tingkat.isNotEmpty)
        const Pill('Gizi normal', bg: AppColors.hijauMuda, fg: AppColors.hijau),
      for (final m in t.masalah) Pill(m, bg: AppColors.kuningMuda, fg: AppColors.kuning),
    ];
  }

  // ================================================================ penimbangan

  Widget _penimbangan(DetailBalita d) {
    if (d.riwayat.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Belum ada riwayat penimbangan', style: TextStyle(color: AppColors.teksRedup))),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < d.riwayat.length; i++) _kartuTimbang(i, d.riwayat[i], d.ringkas.tanggalLahir),
      ],
    );
  }

  Widget _kartuTimbang(int i, TimbangRingkas t, DateTime? lahir) {
    final buka = _terbuka.contains(i);
    final k = t.kunjungan;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: _dekorKartu(),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: k == null
              ? null
              : () => setState(() {
                    if (buka) {
                      _terbuka.remove(i);
                    } else {
                      _terbuka.add(i);
                    }
                  }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kepala(t.tanggal == null ? '-' : formatTanggal(t.tanggal!),
                  kanan: 'usia ${_usiaUkur(lahir, t)}'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BB ${t.bbKg} kg · TB ${t.tbCm} cm'
                      '${t.lkCm == null ? '' : ' · LK ${t.lkCm} cm'}'
                      '${t.lilaCm == null ? '' : ' · LiLA ${t.lilaCm} cm'}',
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      ..._pill(t),
                      if (k?.catatanBidan != null)
                        const Pill('Catatan bidan', bg: AppColors.biruMuda, fg: AppColors.biru),
                      if (k != null && k.imunisasi.isNotEmpty)
                        Pill('${k.imunisasi.length} imunisasi',
                            bg: AppColors.biruMuda, fg: AppColors.biru),
                      if (k != null && k.suplemen.isNotEmpty)
                        Pill('${k.suplemen.length} suplemen',
                            bg: AppColors.kuningMuda, fg: AppColors.kuning),
                    ]),
                    if (k != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _tautan(buka ? 'Tutup detail' : 'Lihat detail'),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topCenter,
                        child: buka ? _detailKunjungan(t, k) : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subjudul(String teks) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _teksGelap)),
      );

  Widget _blok(String judul, String isi, {Color bg = AppColors.latar, Color? garis, Color? warnaJudul}) {
    if (isi.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: garis == null ? null : Border.all(color: garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: warnaJudul)),
          const SizedBox(height: 2),
          Text(isi, style: const TextStyle(fontSize: 15.5, height: 1.35)),
        ],
      ),
    );
  }

  Widget _detailKunjungan(TimbangRingkas t, KunjunganRingkas k) {
    final c = k.catatanBidan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20, color: Color(0xFFE5EDE8)),

        // ------------------------------------------------ pengukuran kader
        _subjudul('Pengukuran Kader'),
        _baris('Cara ukur', t.caraUkur),
        _baris('ASI eksklusif', k.asiEksklusif ? 'Ya' : 'Tidak'),
        _baris('Sedang sakit', k.sedangSakit ? 'Ya' : 'Tidak'),
        _blok('Keluhan', k.keluhanKader),
        _blok('Catatan kader', k.catatanKader),
        _blok('Peringatan validasi', k.peringatanValidasi, bg: AppColors.merahMuda),

        // ------------------------------------------------ catatan bidan
        _subjudul('Catatan Bidan'),
        if (c == null)
          const Text('Catatan bidan belum diisi.',
              style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup))
        else ...[
          _blok('Keluhan', c.keluhan, bg: _biruMuda, garis: _biruGaris, warnaJudul: _biru),
          _blok('Hasil pemeriksaan', c.catatanEvaluasi, bg: _biruMuda, garis: _biruGaris, warnaJudul: _biru),
          _blok('Catatan untuk orang tua', c.saranGizi, bg: _biruMuda, garis: _biruGaris, warnaJudul: _biru),
          _baris('Kunjungan ulang', c.kunjunganUlang == null ? '' : formatTanggal(c.kunjunganUlang!)),
          if (c.keluhan.isEmpty &&
              c.catatanEvaluasi.isEmpty &&
              c.saranGizi.isEmpty &&
              c.kunjunganUlang == null)
            const Text('Tidak ada keluhan atau catatan khusus.',
                style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup)),
        ],

        // ------------------------------------------------ diberikan
        _subjudul('Diberikan Saat Kunjungan'),
        if (k.imunisasi.isEmpty && k.suplemen.isEmpty)
          const Text('Tidak ada imunisasi atau suplemen.',
              style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in k.imunisasi)
                Pill(
                  [v.nama, if (v.keterangan.isNotEmpty) v.keterangan].join(' · '),
                  bg: AppColors.biruMuda,
                  fg: AppColors.biru,
                ),
              for (final x in k.suplemen)
                Pill(
                  [namaSuplemen(x.nama), if (x.keterangan.isNotEmpty) x.keterangan].join(' · '),
                  bg: AppColors.kuningMuda,
                  fg: AppColors.kuning,
                ),
            ],
          ),
      ],
    );
  }
}