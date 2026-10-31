import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../core/posyandu.dart';
import '../../../service/vaksin_service.dart';
import '../../auth/auth_provider.dart';
import 'vaksin_anak_lihat_page.dart';

const _hijauHeader = Color(0xFF065F46);

/// Judul header ekstra tebal (sama seperti halaman Akun).
/// Lapis bawah: garis tepi putih agar huruf lebih gemuk; lapis atas: isi putih.
Widget _judulTebal(String teks) {
  const ukuran = 20.0;
  const jarak = 1.2; // jarak antar huruf

  return Stack(
    children: [
      // Lapis bawah: garis tepi untuk menebalkan huruf
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        ),
      ),
      // Lapis atas: isi huruf
      Text(
        teks,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: ukuran,
          fontWeight: FontWeight.w900,
          letterSpacing: jarak,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Color(0x40000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Kader: cari anak (hanya posyandu kader sendiri)
/// lalu lihat rencana dan riwayat vaksinnya.
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
  // HEADER (sama seperti halaman Vaksin Anak orang tua: polos, judul di tengah)
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
              // Judul di tengah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: _judulTebal('Vaksin Anak'),
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
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final pos =
        (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();

    final labelPos = pos.isEmpty
        ? 'Posyandu belum ditetapkan'
        : 'Posyandu ${labelPosyandu(pos)}';

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _cari,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _muat(),
                decoration: InputDecoration(
                  hintText: 'Cari nama anak atau NIK anak',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _muat,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Pill(
                  labelPos,
                  bg: AppColors.biruMuda,
                  fg: AppColors.biru,
                  icon: Icons.place_outlined,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.teksRedup,
                              ),
                            ),
                          ),
                        )
                      : !_sudahCari
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Ketik nama atau NIK anak untuk mencari di posyandu Anda.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.teksRedup,
                                  ),
                                ),
                              ),
                            )
                          : _hasil.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Anak tidak ditemukan di posyandu Anda',
                                    style: TextStyle(
                                      color: AppColors.teksRedup,
                                    ),
                                  ),
                                )
                              : ListView(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  children: [
                                    for (final a in _hasil)
                                      SectionCard(
                                        child: InkWell(
                                          onTap: () => _buka(a),
                                          child: Row(
                                            children: [
                                              const CircleAvatar(
                                                backgroundColor:
                                                    AppColors.hijauMuda,
                                                child: Icon(
                                                  Icons.child_care,
                                                  color: AppColors.hijau,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      a.nama,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 13.5,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Usia ${a.usia}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.teksRedup,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                Icons.chevron_right,
                                                color: AppColors.teksRedup,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
            ),
          ],
        ),
      ),
    );
  }
}