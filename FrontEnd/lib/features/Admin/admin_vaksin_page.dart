import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/common_widgets.dart';
import '../../service/vaksin_service.dart';
import 'admin_vaksin_model.dart';

/// Admin: jumlah vaksin yang sudah diberikan dan jenis-jenis vaksin.
class AdminVaksinPage extends StatefulWidget {
  const AdminVaksinPage({super.key});

  @override
  State<AdminVaksinPage> createState() => _AdminVaksinPageState();
}

class _AdminVaksinPageState extends State<AdminVaksinPage> {
  final _svc = VaksinService();

  VaksinStatistik? _data;
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
      final data = await _svc.statistikAdmin();
      if (!mounted) return;
      setState(() {
        _data = data;
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
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Data Vaksin', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _muat,
        child: _loading
            ? ListView(children: const [
                SizedBox(height: 200),
                Center(child: CircularProgressIndicator()),
              ])
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(child: AppButton('Coba Lagi', icon: Icons.refresh, onPressed: _muat)),
                    ],
                  )
                : _isi(_data!),
      ),
    );
  }

  Widget _isi(VaksinStatistik d) {
    final maks = d.jenis.fold<int>(0, (m, e) => e.jumlahDiberikan > m ? e.jumlahDiberikan : m);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Ringkasan Vaksin',
          icon: Icons.vaccines_outlined,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatBox(
                        nilai: '${d.totalDiberikan}',
                        label: 'Vaksin\nDiberikan',
                        bg: AppColors.hijauMuda,
                        fg: AppColors.hijau),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatBox(
                        nilai: '${d.totalAnakDivaksin}',
                        label: 'Anak\nDivaksin',
                        bg: AppColors.biruMuda,
                        fg: AppColors.biru),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatBox(
                        nilai: '${d.jumlahJenis}',
                        label: 'Jenis\nVaksin',
                        bg: AppColors.isiField,
                        fg: Colors.black87),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatBox(
                        nilai: '${d.rencanaAktif}',
                        label: 'Rencana\nAktif',
                        bg: AppColors.kuningMuda,
                        fg: AppColors.kuning),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Jenis & Jumlah Pemberian',
          icon: Icons.list_alt_outlined,
          trailing: Pill('${d.jenis.length} jenis', bg: AppColors.biruMuda, fg: AppColors.biru),
          child: d.jenis.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('Belum ada data jenis vaksin',
                        style: TextStyle(color: AppColors.teksRedup)),
                  ),
                )
              : Column(children: [for (final e in d.jenis) _barisJenis(e, maks)]),
        ),
      ],
    );
  }

  Widget _barisJenis(VaksinStatistikItem e, int maks) {
    final nilai = maks == 0 ? 0.0 : e.jumlahDiberikan / maks;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.latar, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.vaksin.nama,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              ),
              Pill('${e.jumlahDiberikan} dosis',
                  bg: AppColors.hijauMuda, fg: AppColors.hijau),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: nilai,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppColors.hijau,
            ),
          ),
          const SizedBox(height: 6),
          Text('${e.jumlahAnak} anak sudah menerima',
              style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
        ],
      ),
    );
  }
}