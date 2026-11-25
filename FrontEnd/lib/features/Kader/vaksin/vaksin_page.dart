import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/posyandu.dart';
import '../../../service/vaksin_service.dart';
import '../../auth/auth_provider.dart';
import 'vaksin_anak_lihat_page.dart';

const _hijauHeader = Color(0xFF065F46);
const _teksGelap = Color(0xFF1F2937);

/// Garis tepi kolom cari: hitam lembut.
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

/// Kepala kartu: judul kapital tebal, lalu garis aksen di bawahnya.
Widget _kepala(String judul) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Tautan "Lihat detail" (hijau lembut bergaris bawah).
const _tautanDetail = Text(
  'Lihat detail',
  style: TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: _aksen,
    decoration: TextDecoration.underline,
    decorationColor: _aksen,
  ),
);

/// Kader: cari anak (hanya posyandu kader sendiri)
/// lalu lihat jadwal imunisasi, riwayat vaksin, dan suplemennya.
class KaderVaksinPage extends StatefulWidget {
  const KaderVaksinPage({super.key});

  @override
  State<KaderVaksinPage> createState() => _KaderVaksinPageState();
}

class _KaderVaksinPageState extends State<KaderVaksinPage> {
  final _svc = VaksinService();
  final _cari = TextEditingController();

  List<AnakRingkas> _hasil = [];
  bool _loading = false;
  bool _sudahCari = false;
  String? _error;

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    final kata = _cari.text.trim();

    if (kata.length < 2) {
      setState(() {
        _error = 'Ketik minimal 2 karakter nama atau NIK anak';
        _hasil = [];
        _sudahCari = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _svc.cariAnak(kata);
      if (!mounted) return;

      setState(() {
        _hasil = data;
        _sudahCari = true;
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

  void _buka(AnakRingkas a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VaksinAnakLihatPage(
          anakId: a.id,
          namaAnak: a.nama,
          usia: a.usia,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // HEADER (polos, judul di tengah, tombol kembali di kiri)
  // -------------------------------------------------------------------------
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal('Vaksin & Imunisasi'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
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

  /// Kolom cari: putih, garis tepi hitam lembut.
  Widget _kotakCari() {
    OutlineInputBorder garis(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: TextField(
        controller: _cari,
        style: const TextStyle(fontSize: 16.5),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _muat(),
        decoration: InputDecoration(
          hintText: 'Cari nama anak atau NIK anak',
          hintStyle: const TextStyle(fontSize: 16),
          prefixIcon: const Icon(Icons.search, color: Colors.black54),
          suffixIcon: IconButton(
            tooltip: 'Cari',
            icon: const Icon(Icons.arrow_forward, color: _hijauHeader),
            onPressed: _muat,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: garis(_garis, 1.2),
          enabledBorder: garis(_garis, 1.2),
          focusedBorder: garis(Colors.black54, 1.4),
        ),
      ),
    );
  }

  /// Pesan (kosong / gagal) di dalam kartu.
  Widget _pesan(String teks) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: _dekorKartu(),
          child: Text(
            teks,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.45, color: AppColors.teksRedup),
          ),
        ),
      ],
    );
  }

  /// Kartu anak: nama di kepala, usia lanjut ke samping, "Lihat detail" di kanan bawah.
  Widget _kartuAnak(AnakRingkas a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: _dekorKartu(),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _buka(a),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kepala(a.nama),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Usia : ',
                                style: TextStyle(fontWeight: FontWeight.w700, color: _teksGelap),
                              ),
                              TextSpan(
                                text: a.usia.isEmpty ? '-' : a.usia,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.35),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _tautanDetail,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();

    final labelPos =
        pos.isEmpty ? 'Posyandu belum ditetapkan' : 'Posyandu ${labelPosyandu(pos)}';

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
            _kotakCari(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  labelPos,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: _teksGelap,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _pesan(_error!)
                      : !_sudahCari
                          ? _pesan('Ketik nama atau NIK anak untuk mencari di posyandu Anda.')
                          : _hasil.isEmpty
                              ? _pesan('Anak tidak ditemukan di posyandu Anda.')
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  children: [
                                    for (final a in _hasil) _kartuAnak(a),
                                  ],
                                ),
            ),
          ],
        ),
      ),
    );
  }
}