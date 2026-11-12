import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'common_widgets.dart';
import '../service/balita_service.dart';
import '../service/vaksin_service.dart' show namaSuplemen;
import '../features/Bidan/vaksin/vaksin_lihat_body.dart';
import '../features/Sekretaris/rekap/admin_rekap_page.dart';

/// Detail satu balita: profil & keluarga, riwayat penimbangan (beserta catatan
/// kader, catatan bidan, imunisasi, dan suplemen tiap kunjungan), dan vaksin.
/// [tabAwal] 0 = Profil, 1 = Penimbangan (kunjungan terbaru langsung terbuka), 2 = Vaksin.
class BalitaDetailPage extends StatefulWidget {
  final String prefix;
  final String anakId;
  final String nama;
  final bool bisaKelolaVaksin;
  final int tabAwal;

  const BalitaDetailPage({
    super.key,
    required this.prefix,
    required this.anakId,
    required this.nama,
    this.bisaKelolaVaksin = false,
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

  @override
  Widget build(BuildContext context) {
    const label = ['Profil', 'Penimbangan', 'Vaksin'];
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    for (var i = 0; i < label.length; i++)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: _tab == i ? AppColors.hijau : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              label[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: _tab == i ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _tab == 2
                  ? VaksinLihatBody(anakId: widget.anakId, bisaKelola: widget.bisaKelolaVaksin)
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
                                    AppButton('Coba Lagi', icon: Icons.refresh, onPressed: _muat),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(l, style: const TextStyle(fontSize: 15.5, color: AppColors.teksRedup))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500))),
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
        SectionCard(
          title: r.nama,
          icon: Icons.child_care,
          trailing: Pill(
            r.status == 'aktif' ? 'Aktif' : (r.status.isEmpty ? '-' : r.status),
            bg: r.status == 'aktif' ? AppColors.hijauMuda : AppColors.kuningMuda,
            fg: r.status == 'aktif' ? AppColors.hijau : AppColors.kuning,
          ),
          child: Column(
            children: [
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
        SectionCard(
          title: 'Kondisi Terakhir',
          icon: Icons.monitor_weight_outlined,
          child: r.terakhir == null
              ? const Text('Belum pernah ditimbang di posyandu.',
                  style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup))
              : _ringkasTimbang(r.terakhir!, r.tanggalLahir),
        ),
        SectionCard(
          title: 'Imunisasi',
          icon: Icons.vaccines_outlined,
          trailing: Pill('${r.vaksin.persen}%', bg: AppColors.hijauMuda, fg: AppColors.hijau),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: r.vaksin.totalDosis == 0 ? 0 : r.vaksin.sudah / r.vaksin.totalDosis,
                  minHeight: 8,
                  backgroundColor: AppColors.latar,
                  color: AppColors.hijau,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${r.vaksin.sudah} dari ${r.vaksin.totalDosis} dosis · '
                '${r.vaksin.jatuhTempo} saatnya diberikan · ${r.vaksin.terlambat} terlambat',
                style: const TextStyle(fontSize: 15.5),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _tab = 2),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Lihat jadwal & riwayat vaksin'),
                ),
              ),
            ],
          ),
        ),
        if (keluarga.isNotEmpty)
          SectionCard(
            title: 'Data Keluarga',
            icon: Icons.family_restroom,
            child: Column(children: [for (final e in keluarga) _baris(e.key, e.value)]),
          ),
      ],
    );
  }

  Widget _ringkasTimbang(TimbangRingkas t, DateTime? lahir) {
    String z(double? v) => v == null ? '-' : v.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: StatBox(nilai: '${t.bbKg}', label: 'BB (kg)')),
            const SizedBox(width: 6),
            Expanded(child: StatBox(nilai: '${t.tbCm}', label: 'TB (cm)')),
            const SizedBox(width: 6),
            Expanded(child: StatBox(nilai: t.lkCm == null ? '-' : '${t.lkCm}', label: 'LK (cm)')),
            const SizedBox(width: 6),
            Expanded(child: StatBox(nilai: t.lilaCm == null ? '-' : '${t.lilaCm}', label: 'LiLA (cm)')),
          ],
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

  List<Widget> _pill(TimbangRingkas t) {
    final s = t.statusTimbang;
    return [
      if (s.isNotEmpty)
        Pill(
          {'N': 'N · Naik', 'T': 'T · Tidak naik', 'O': 'O · Bulan lalu tidak ditimbang', 'B': 'B · Baru'}[s] ?? s,
          bg: s == 'N' ? AppColors.hijauMuda : (s == 'T' ? AppColors.merahMuda : AppColors.biruMuda),
          fg: s == 'N' ? AppColors.hijau : (s == 'T' ? AppColors.merah : AppColors.biru),
        ),
      if (t.kenaikanGram != null)
        Pill(
          '${t.kenaikanGram! > 0 ? '+' : ''}${t.kenaikanGram} g${t.kbmGram == null ? '' : ' (KBM ${t.kbmGram} g)'}',
          bg: AppColors.latar,
          fg: Colors.black87,
        ),
      if (t.duaT) const Pill('2T', bg: AppColors.merahMuda, fg: AppColors.merah, icon: Icons.warning_amber_rounded),
      if (t.bgm) const Pill('BGM', bg: AppColors.merahMuda, fg: AppColors.merah, icon: Icons.warning_amber_rounded),
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
          Icon(Icons.scale_outlined, size: 40, color: AppColors.teksRedup),
          SizedBox(height: 8),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: k == null
              ? null
              : () => setState(() {
                    if (buka) {
                      _terbuka.remove(i);
                    } else {
                      _terbuka.add(i);
                    }
                  }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note, size: 18, color: AppColors.hijau),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.tanggal == null ? '-' : formatTanggal(t.tanggal!),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                    Text('usia ${_usiaUkur(lahir, t)}', style: const TextStyle(fontSize: 15.5, color: AppColors.teksRedup)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'BB ${t.bbKg} kg · TB ${t.tbCm} cm'
                  '${t.lkCm == null ? '' : ' · LK ${t.lkCm} cm'}'
                  '${t.lilaCm == null ? '' : ' · LiLA ${t.lilaCm} cm'}',
                  style: const TextStyle(fontSize: 15.5),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ..._pill(t),
                  if (k?.catatanBidan != null)
                    const Pill('Catatan bidan', bg: AppColors.biruMuda, fg: AppColors.biru, icon: Icons.check),
                  if (k != null && k.imunisasi.isNotEmpty)
                    Pill('${k.imunisasi.length} imunisasi',
                        bg: AppColors.biruMuda, fg: AppColors.biru, icon: Icons.vaccines),
                  if (k != null && k.suplemen.isNotEmpty)
                    Pill('${k.suplemen.length} suplemen',
                        bg: AppColors.kuningMuda, fg: AppColors.kuning, icon: Icons.medication),
                ]),
                if (k != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        buka ? 'Tutup detail kunjungan' : 'Lihat detail kunjungan',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w500, color: AppColors.hijau),
                      ),
                      Icon(buka ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.hijau),
                    ],
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
        ),
      ),
    );
  }

  Widget _subjudul(String teks, IconData ikon) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Row(
          children: [
            Icon(ikon, size: 16, color: AppColors.hijau),
            const SizedBox(width: 6),
            Text(teks, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
          ],
        ),
      );

  Widget _blok(String judul, String isi, {Color bg = AppColors.latar}) {
    if (isi.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
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
        const Divider(height: 20),

        // ------------------------------------------------ pengukuran kader
        _subjudul('Pengukuran Kader', Icons.straighten),
        _baris('Cara ukur', t.caraUkur),
        _baris('ASI eksklusif', k.asiEksklusif ? 'Ya' : 'Tidak'),
        _baris('Sedang sakit', k.sedangSakit ? 'Ya' : 'Tidak'),
        _blok('Keluhan', k.keluhanKader),
        _blok('Catatan kader', k.catatanKader),
        _blok('Peringatan validasi', k.peringatanValidasi, bg: AppColors.merahMuda),

        // ------------------------------------------------ catatan bidan
        _subjudul('Catatan Bidan', Icons.medical_information_outlined),
        if (c == null)
          const Text('Catatan bidan belum diisi.',
              style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup))
        else ...[
          _blok('Keluhan', c.keluhan, bg: AppColors.hijauMuda),
          _blok('Catatan untuk orang tua', c.catatanEvaluasi, bg: AppColors.hijauMuda),
          _blok('Saran gizi', c.saranGizi, bg: AppColors.hijauMuda),
          _baris('Kunjungan ulang', c.kunjunganUlang == null ? '' : formatTanggal(c.kunjunganUlang!)),
          if (c.keluhan.isEmpty &&
              c.catatanEvaluasi.isEmpty &&
              c.saranGizi.isEmpty &&
              c.kunjunganUlang == null)
            const Text('Tidak ada keluhan atau catatan khusus.',
                style: TextStyle(fontSize: 15.5, color: AppColors.teksRedup)),
        ],

        // ------------------------------------------------ diberikan
        _subjudul('Diberikan Saat Kunjungan', Icons.vaccines_outlined),
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
                  icon: Icons.vaccines,
                ),
              for (final x in k.suplemen)
                Pill(
                  [namaSuplemen(x.nama), if (x.keterangan.isNotEmpty) x.keterangan].join(' · '),
                  bg: AppColors.kuningMuda,
                  fg: AppColors.kuning,
                  icon: Icons.medication,
                ),
            ],
          ),
      ],
    );
  }
}