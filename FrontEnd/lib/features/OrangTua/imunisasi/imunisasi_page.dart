import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../service/imunisasi_service.dart';
import '../../Bidan/imunisasi/imunisasi_lihat_body.dart';

const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi chip: hitam lembut.
const _garis = Color(0xFFB8BEC6);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

BoxDecoration _dekorKartu() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Judul header (gaya teks sama dengan halaman lain).
Widget _judulTebal(String teks) {
  return Text(
    teks,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: Colors.white,
    ),
  );
}

/// Orang tua: lihat jadwal imunisasi, riwayat imunisasi, dan suplemen balita sendiri,
/// serta melaporkan reaksi setelah imunisasi (diteruskan ke bidan).
class OrangTuaImunisasiPage extends StatefulWidget {
  const OrangTuaImunisasiPage({super.key});

  @override
  State<OrangTuaImunisasiPage> createState() => _OrangTuaImunisasiPageState();
}

class _OrangTuaImunisasiPageState extends State<OrangTuaImunisasiPage> {
  final _svc = ImunisasiService();

  List<BalitaRingkas> _balita = [];
  BalitaRingkas? _dipilih;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.balitaSaya();
      if (!mounted) return;
      setState(() {
        _balita = data;
        _dipilih = data.isNotEmpty ? data.first : null;
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

  // Header bagian atas: judul di tengah
  Widget _header() {
    return Container(
      width: double.infinity,
      color: _hijauHeader,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Judul di tengah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal('Imunisasi'),
              ),
              // Tombol kembali di kiri
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pesan (kosong / gagal) di dalam kartu.
  Widget _pesan(String teks, {Widget? aksi}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: _dekorKartu(),
          child: Text(teks,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4, color: AppColors.teksRedup)),
        ),
        if (aksi != null) ...[const SizedBox(height: 14), aksi],
      ],
    );
  }

  /// Kartu balita terpilih: nama (kapital) di kiri, usia di kanan, garis aksen di bawah.
  Widget _kartuBalita(BalitaRingkas a) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _dekorKartu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    a.nama.toUpperCase(),
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
                const SizedBox(width: 10),
                Text(a.usia.isEmpty ? '-' : a.usia,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w600, color: _teksGelap)),
              ],
            ),
          ),
          Container(height: 3, color: _aksen),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              'Jadwal imunisasi, riwayat imunisasi, dan suplemen balita.',
              style: TextStyle(fontSize: 15.5, height: 1.35, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _pesan(
        _error!,
        aksi: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _muat,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hijauHeader,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    if (_balita.isEmpty) {
      return _pesan('Belum ada data balita. Tambahkan data balita terlebih dahulu.');
    }
    final dipilih = _dipilih!;
    return Column(
      children: [
        if (_balita.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final a in _balita)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(a.nama),
                        selected: dipilih.id == a.id,
                        showCheckmark: false,
                        selectedColor: _hijauHeader,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                            color: dipilih.id == a.id ? _hijauHeader : _garis, width: 1.2),
                        labelStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: dipilih.id == a.id ? Colors.white : _teksGelap),
                        onSelected: (_) => setState(() => _dipilih = a),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _kartuBalita(dipilih),
        ),
        Expanded(
          child: ImunisasiLihatBody(
            key: ValueKey(dipilih.id),
            balitaId: dipilih.id,
            bisaLaporKipi: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
            _header(),
            Expanded(child: _isi()),
          ],
        ),
      ),
    );
  }
}