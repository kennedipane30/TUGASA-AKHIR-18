import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import 'pendataan_page.dart';

const _teksGelap = Color(0xFF1F2937);

/// Garis tepi field & kotak di dalam kartu: hitam lembut.
const _garis = Color(0xFFB8BEC6);

/// Warna aksen kartu: hijau lembut senada header.
const _aksen = Color(0xFF5E9C84);

/// Bayangan lembut di bawah kartu (pengganti garis tepi).
const _bayangan = AppColors.bayanganKartu;

BoxDecoration _dekorKartu({Color warna = Colors.white}) => BoxDecoration(
      color: warna,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _bayangan,
    );

/// Kepala kartu: judul kapital tebal di kiri, keterangan di kanan, garis aksen di bawah.
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
              Text(
                kanan,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: _teksGelap,
                ),
              ),
            ],
          ],
        ),
      ),
      Container(height: 3, color: _aksen),
    ],
  );
}

/// Kartu putih berbayang; [judul] opsional.
Widget _kartu({
  String? judul,
  String? kanan,
  Color warna = Colors.white,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    clipBehavior: Clip.antiAlias,
    decoration: _dekorKartu(warna: warna),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (judul != null) _kepala(judul, kanan: kanan),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ],
    ),
  );
}

/// Baris "Label : nilai" (hitam tebal, nilai lanjut ke samping).
Widget _barisInfo(String label, String nilai, {double lebar = 120}) {
  const gaya = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: _teksGelap,
  );
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: lebar, child: Text(label, style: gaya)),
        const Text(': ', style: gaya),
        Expanded(child: Text(nilai.isEmpty ? '-' : nilai, style: gaya)),
      ],
    ),
  );
}

/// Dekorasi field form: putih, garis tepi hitam lembut, ikon di depan.
InputDecoration _dekorForm(String label, IconData ikon) {
  OutlineInputBorder garis(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 15.5),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Icon(ikon, color: _aksen),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: garis(_garis, 1.2),
    enabledBorder: garis(_garis, 1.2),
    focusedBorder: garis(hijauHeaderPendataan, 1.6),
  );
}

/// Pilihan ya/tidak (Sedang sakit, ASI eksklusif) dalam kotak bergaris lembut.
Widget _pilihan(IconData ikon, String label, bool nilai, ValueChanged<bool> ubah) {
  return Container(
    margin: const EdgeInsets.only(top: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: nilai ? hijauHeaderPendataan : _garis,
        width: 1.2,
      ),
    ),
    child: SwitchListTile(
      contentPadding: const EdgeInsets.only(left: 12, right: 6),
      secondary: Icon(ikon, color: _aksen),
      activeTrackColor: hijauHeaderPendataan,
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _teksGelap,
        ),
      ),
      value: nilai,
      onChanged: ubah,
    ),
  );
}

/// Tombol bawah tanpa latar footer: Batal (merah bergaris) + Simpan (hijau).
Widget _tombolBawah({
  required String labelSimpan,
  required bool kirim,
  required VoidCallback onBatal,
  required VoidCallback onSimpan,
}) {
  return SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.merah,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.merah, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: kirim ? null : onBatal,
                child: const Text(
                  'Batal',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hijauHeaderPendataan,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF7FAF9F),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: kirim ? null : onSimpan,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    kirim ? 'Menyimpan...' : labelSimpan,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// HALAMAN CATAT PENGUKURAN (halaman penuh)
// Mencatat pengukuran pertama anak pada sesi posyandu ini.
// Kembali ke halaman Pendataan dengan teks peringatan validasi (boleh kosong).
// ---------------------------------------------------------------------------
class CatatPengukuranPage extends StatefulWidget {
  final AntreanKader anak;

  const CatatPengukuranPage({super.key, required this.anak});

  @override
  State<CatatPengukuranPage> createState() => _CatatPengukuranPageState();
}

class _CatatPengukuranPageState extends State<CatatPengukuranPage> {
  final _bb = TextEditingController();
  final _tb = TextEditingController();
  final _lk = TextEditingController();
  final _lila = TextEditingController();
  final _keluhan = TextEditingController();
  final _catatan = TextEditingController();

  bool _sakit = false;
  bool _asi = false;
  bool _kirim = false;
  final bool _memuat = false;
  String? _galat;

  @override
  void dispose() {
    for (final c in [_bb, _tb, _lk, _lila, _keluhan, _catatan]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _angka(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _simpan() async {
    final bb = _angka(_bb);
    final tb = _angka(_tb);

    if (bb == null || tb == null) {
      setState(
        () => _galat =
            'Berat badan dan tinggi/panjang badan wajib diisi dengan angka.',
      );
      return;
    }

    final lk = _angka(_lk);
    final lila = _angka(_lila);

    setState(() {
      _kirim = true;
      _galat = null;
    });

    try {
      final r = await ApiClient.dio.put(
        '/kader/pendaftaran/${widget.anak.pendaftaranId}/pengukuran',
        data: {
          'bb_kg': bb,
          'tb_cm': tb,
          if (lk != null) 'lingkar_kepala_cm': lk,
          if (lila != null) 'lila_cm': lila,
          'keluhan': _keluhan.text.trim(),
          'sedang_sakit': _sakit,
          'asi_eksklusif': _asi,
          'catatan': _catatan.text.trim(),
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      dynamic d = r.data;
      if (d is Map && d.containsKey('data')) d = d['data'];

      final peringatan = d is Map
          ? d['peringatan_validasi']?.toString() ?? ''
          : '';

      if (mounted) {
        Navigator.pop(context, peringatan);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _galat = pesanErrorPendataan(e);
          _kirim = false;
        });
      }
    }
  }

  Widget _kolom(
    TextEditingController c,
    String label,
    IconData ikon, {
    bool angka = true,
    int baris = 1,
  }) {
    return TextField(
      controller: c,
      maxLines: baris,
      style: const TextStyle(fontSize: 17.5),
      keyboardType: angka
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      textCapitalization: angka ? TextCapitalization.none : TextCapitalization.sentences,
      decoration: _dekorForm(label, ikon),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      color: hijauHeaderPendataan,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: judulHeaderPendataan('Catat Pengukuran'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      bottomNavigationBar: _memuat
          ? null
          : _tombolBawah(
              labelSimpan: 'Simpan & Teruskan ke Bidan',
              kirim: _kirim,
              onBatal: () => Navigator.pop(context),
              onSimpan: _simpan,
            ),
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
              child: _memuat
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _kartu(
                          judul: widget.anak.nama,
                          kanan: 'Antrean ${widget.anak.kodeNomor}',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _barisInfo('Jenis Kelamin',
                                  widget.anak.jk == 'P' ? 'Perempuan' : 'Laki-laki'),
                              _barisInfo('Umur', widget.anak.usia),
                            ],
                          ),
                        ),
                        _kartu(
                          judul: 'Hasil Pengukuran',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _kolom(_bb, 'BB (kg)', Icons.monitor_weight_outlined),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _kolom(_tb, 'TB/PB (cm)', Icons.height),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _kolom(_lk, 'LK (cm)', Icons.face_outlined),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _kolom(_lila, 'LiLA (cm)', Icons.straighten),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _kartu(
                          judul: 'Kondisi Anak',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kolom(_keluhan, 'Keluhan', Icons.sick_outlined, angka: false),
                              const SizedBox(height: 10),
                              _kolom(_catatan, 'Catatan', Icons.notes_outlined,
                                  angka: false, baris: 2),
                              _pilihan(Icons.thermostat_outlined, 'Sedang sakit', _sakit,
                                  (v) => setState(() => _sakit = v)),
                              _pilihan(Icons.child_friendly_outlined, 'ASI eksklusif', _asi,
                                  (v) => setState(() => _asi = v)),
                            ],
                          ),
                        ),
                        if (_galat != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _galat!,
                              style: const TextStyle(color: AppColors.merah, fontSize: 16),
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