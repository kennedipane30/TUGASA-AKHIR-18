import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../core/posyandu.dart';
import 'admin_vaksin_model.dart';

/// Admin: jumlah vaksin yang sudah diberikan dan jenis-jenis vaksin, per posyandu.
class AdminVaksinPage extends StatefulWidget {
  const AdminVaksinPage({super.key});

  @override
  State<AdminVaksinPage> createState() => _AdminVaksinPageState();
}

class _AdminVaksinPageState extends State<AdminVaksinPage> {
  VaksinStatistik? _data;
  bool _loading = true;
  String? _error;
  String _posyandu = ''; // kosong = semua posyandu

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
      final res = await ApiClient.dio.get('/admin/vaksin/statistik',
          queryParameters: {if (_posyandu.isNotEmpty) 'posyandu': _posyandu});
      final data = VaksinStatistik.fromJson(Map<String, dynamic>.from(res.data['data']));
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      String pesan = e.toString().replaceFirst('Exception: ', '');
      if (e is DioException) {
        final d = e.response?.data;
        pesan = (d is Map && d['error'] != null)
            ? d['error'].toString()
            : 'Tidak dapat terhubung ke server';
      }
      setState(() {
        _error = pesan;
        _loading = false;
      });
    }
  }

  Widget _chipPosyandu(String kode, String label) {
    final dipilih = _posyandu == kode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: dipilih,
        selectedColor: AppColors.hijau,
        backgroundColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: dipilih ? Colors.white : Colors.black87,
        ),
        onSelected: (_) {
          setState(() => _posyandu = kode);
          _muat();
        },
      ),
    );
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chipPosyandu('', 'Semua'),
              for (final p in daftarPosyandu) _chipPosyandu(p.kode, p.nama),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Ringkasan Vaksin • ${labelPosyandu(_posyandu)}',
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