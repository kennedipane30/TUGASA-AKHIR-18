import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../../core/posyandu.dart';
import 'admin_vaksin_model.dart';

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

  // -------------------------------------------------------------------------
  // HEADER (sama seperti halaman Vaksin Anak: polos, judul di tengah)
  // Tombol kembali hanya muncul bila ada halaman sebelumnya.
  // -------------------------------------------------------------------------
  Widget _header() {
    final bisaKembali = Navigator.canPop(context);

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
                child: _judulTebal('Data Vaksin'),
              ),
              // Tombol kembali di kiri
              if (bisaKembali)
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
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
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
                              Center(
                                  child: AppButton('Coba Lagi',
                                      icon: Icons.refresh, onPressed: _muat)),
                            ],
                          )
                        : _isi(_data!),
              ),
            ),
          ],
        ),
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