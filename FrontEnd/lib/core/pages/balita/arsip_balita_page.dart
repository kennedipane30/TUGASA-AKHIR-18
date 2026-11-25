import 'package:flutter/material.dart';

import '../../../features/Kader/keluarga/keluarga.dart';

// ============================================================================
// ARSIP BALITA (kader, dari Semua Balita -> Lihat detail)
//  - Form arsip (bottom sheet): alasan pindah / meninggal / lainnya + tanggal.
//  - Konfirmasi sebelum diarsipkan / diaktifkan kembali.
// Anak berusia 60 bulan diarsipkan otomatis oleh sistem (lulus balita).
// Gaya form mengikuti form data anak kader (features/Kader/keluarga).
// ============================================================================

/// Isian arsip. [alasan]: pindah | meninggal | lainnya. [tanggal]: dd/mm/yyyy.
class IsianArsip {
  final String alasan, tanggal, keterangan;
  const IsianArsip({required this.alasan, required this.tanggal, this.keterangan = ''});

  /// Tanggal untuk API: YYYY-MM-DD.
  String get tanggalApi => kkKeApi(tanggal);

  String get alasanTeks => switch (alasan) {
        'pindah' => 'Pindah domisili',
        'meninggal' => 'Meninggal',
        _ => 'Lainnya',
      };
}

/// Membuka form arsip untuk anak [nama] (lahir [lahir]). Mengembalikan isian,
/// atau null bila dibatalkan.
Future<IsianArsip?> bukaFormArsip(BuildContext context, {required String nama, DateTime? lahir}) {
  return showModalBottomSheet<IsianArsip>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FormArsip(nama: nama, lahir: lahir),
  );
}

/// Konfirmasi terakhir sebelum data anak diarsipkan.
Future<bool> konfirmasiArsip(BuildContext context, String nama, IsianArsip isian) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Arsipkan data anak?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kkTeksGelap)),
      content: Text(
        '$nama (${isian.alasanTeks}, ${isian.tanggal}) tidak akan muncul lagi '
        'di pendaftaran, pendataan, dan rekap posyandu.\n\n'
        'Riwayat penimbangan dan imunisasi tetap tersimpan. '
        'Data dapat dilihat di Semua Balita > Diarsipkan dan diaktifkan kembali bila salah arsip.',
        style: const TextStyle(fontSize: 15, height: 1.4, color: kkTeksGelap),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal', style: TextStyle(color: kkTeksAbu, fontSize: 15.5)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Arsipkan',
              style: TextStyle(color: kkMerah, fontSize: 15.5, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Konfirmasi sebelum anak arsip diaktifkan kembali.
Future<bool> konfirmasiAktifkan(BuildContext context, String nama) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Aktifkan kembali?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kkTeksGelap)),
      content: Text(
        '$nama akan kembali muncul di pendaftaran, pendataan, dan rekap posyandu.',
        style: const TextStyle(fontSize: 15, height: 1.4, color: kkTeksGelap),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal', style: TextStyle(color: kkTeksAbu, fontSize: 15.5)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Aktifkan',
              style: TextStyle(color: kkHijau, fontSize: 15.5, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok == true;
}

// ---------------------------------------------------------------------------
// FORM ARSIP (bottom sheet)
// ---------------------------------------------------------------------------
class _FormArsip extends StatefulWidget {
  final String nama;
  final DateTime? lahir;
  const _FormArsip({required this.nama, this.lahir});

  @override
  State<_FormArsip> createState() => _FormArsipState();
}

class _FormArsipState extends State<_FormArsip> {
  final _key = GlobalKey<FormState>();
  final _tgl = TextEditingController(text: kkFmtTgl(DateTime.now()));
  final _ket = TextEditingController();
  String _alasan = '';
  bool _alasanSalah = false;

  static const _pilihan = [
    ('pindah', 'Pindah domisili', Icons.local_shipping_outlined),
    ('meninggal', 'Meninggal', Icons.sentiment_dissatisfied_outlined),
    ('lainnya', 'Lainnya', Icons.more_horiz),
  ];

  @override
  void dispose() {
    _tgl.dispose();
    _ket.dispose();
    super.dispose();
  }

  void _simpan() {
    final ok = _key.currentState!.validate();
    setState(() => _alasanSalah = _alasan.isEmpty);
    if (!ok || _alasan.isEmpty) return;
    Navigator.pop(
      context,
      IsianArsip(alasan: _alasan, tanggal: _tgl.text, keterangan: _ket.text.trim()),
    );
  }

  Widget _opsi((String, String, IconData) p) {
    final aktif = _alasan == p.$1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _alasan = p.$1;
          _alasanSalah = false;
        }),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: aktif ? kkHijauMuda : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: aktif ? kkHijau : (_alasanSalah ? kkMerah : kkGarisInput),
              width: aktif ? 1.6 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(p.$3, size: 21, color: aktif ? kkHijau : kkAksen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(p.$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                      color: kkTeksGelap,
                    )),
              ),
              Icon(aktif ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20, color: aktif ? kkHijau : kkGaris),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hariIni = DateTime(now.year, now.month, now.day);
    final lahir = widget.lahir ?? DateTime(now.year - 5, now.month, now.day);
    final lainnya = _alasan == 'lainnya';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration:
                        BoxDecoration(color: kkGaris, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('ARSIPKAN DATA ANAK',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: kkTeksGelap)),
                const SizedBox(height: 8),
                Container(height: 3, color: kkAksen),
                const SizedBox(height: 14),
                Text(widget.nama.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: kkTeksGelap)),
                if (widget.lahir != null) ...[
                  const SizedBox(height: 2),
                  Text('Lahir ${kkFmtTgl(widget.lahir!)} · ${kkUsiaTeks(kkFmtTgl(widget.lahir!))}',
                      style: const TextStyle(fontSize: 14.5, color: kkTeksAbu)),
                ],
                const SizedBox(height: 16),
                kkLabel('Alasan', wajib: true),
                for (final p in _pilihan) _opsi(p),
                if (_alasanSalah)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('Pilih alasan arsip',
                        style: TextStyle(color: kkMerah, fontSize: 12.5)),
                  ),
                kkJarak(),
                kkLabel('Tanggal', wajib: true),
                FieldTanggal(
                  c: _tgl,
                  hint: 'dd/mm/yyyy',
                  awal: lahir.isAfter(hariIni) ? hariIni : lahir,
                  akhir: hariIni,
                  validator: (v) => (v ?? '').isEmpty ? 'Tanggal wajib diisi' : null,
                ),
                kkJarak(),
                kkLabel('Keterangan', wajib: lainnya, opsional: !lainnya),
                TextFormField(
                  controller: _ket,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: kkDekor(
                    _alasan == 'pindah' ? 'Mis. pindah ke Kota Medan' : 'Keterangan singkat',
                    ikon: Icons.notes_outlined,
                  ),
                  validator: (v) => lainnya && (v ?? '').trim().isEmpty
                      ? 'Keterangan wajib diisi untuk alasan lainnya'
                      : null,
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Text(
                    'Anak yang diarsipkan tidak muncul lagi di pendaftaran, pendataan, dan '
                    'rekap. Riwayat penimbangan dan imunisasi tetap tersimpan.',
                    style: TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF9A3412)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: kkTombolGaris('Batal',
                          warna: kkMerah, onPressed: () => Navigator.pop(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: kkTombolHijau('Arsipkan', onPressed: _simpan)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}