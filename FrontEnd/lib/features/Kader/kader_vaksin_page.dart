import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../service/vaksin_service.dart';
import 'vaksin_anak_lihat_page.dart';

/// Kader: cari anak lalu lihat rencana dan riwayat vaksinnya.
class KaderVaksinPage extends StatefulWidget {
  const KaderVaksinPage({super.key});

  @override
  State<KaderVaksinPage> createState() => _KaderVaksinPageState();
}

class _KaderVaksinPageState extends State<KaderVaksinPage> {
final _svc = VaksinService();
  final _cari = TextEditingController();

  List<AnakRingkas> _hasil = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.cariAnak(_cari.text.trim());
      if (!mounted) return;
      setState(() {
        _hasil = data;
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
        builder: (_) => VaksinAnakLihatPage(anakId: a.id, namaAnak: a.nama, usia: a.usia),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Vaksin Anak', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _cari,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _muat(),
              decoration: InputDecoration(
                hintText: 'Cari nama anak atau NIK anak',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _muat),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
                    : _hasil.isEmpty
                        ? const Center(
                            child: Text('Anak tidak ditemukan',
                                style: TextStyle(color: AppColors.teksRedup)),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              for (final a in _hasil)
                                SectionCard(
                                  child: InkWell(
                                    onTap: () => _buka(a),
                                    child: Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: AppColors.hijauMuda,
                                          child: Icon(Icons.child_care, color: AppColors.hijau),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(a.nama,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13.5)),
                                              Text('Usia ${a.usia}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.teksRedup)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right,
                                            color: AppColors.teksRedup),
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