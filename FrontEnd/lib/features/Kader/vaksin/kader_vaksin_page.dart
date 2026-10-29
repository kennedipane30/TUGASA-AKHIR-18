import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../core/posyandu.dart';
import '../../../service/vaksin_service.dart';
import '../../auth/auth_provider.dart';
import 'vaksin_anak_lihat_page.dart';

const _hijauHeader = Color(0xFF0B6043);

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

  @override
  Widget build(BuildContext context) {
    final pos =
        (context.watch<AuthProvider>().user?['posyandu'] ?? '').toString();

    final labelPos = pos.isEmpty
        ? 'Posyandu belum ditetapkan'
        : 'Posyandu ${labelPosyandu(pos)}';

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text(
          'Vaksin Anak',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: _hijauHeader,
        surfaceTintColor: _hijauHeader,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _hijauHeader,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Column(
        children: [
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
                                                      color: AppColors.teksRedup,
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
    );
  }
}