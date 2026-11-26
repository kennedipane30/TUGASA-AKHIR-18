import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keluarga.dart';

// ============================================================================
// FORM DATA BALITA (bottom sheet) + baris balita.
// Aturan sama dengan halaman Data Balita orang tua; usia dibatasi balita (0-59 bln).
// ============================================================================

// ---------------------------------------------------------------------------
// FORM DATA BALITA (bottom sheet)
// ---------------------------------------------------------------------------
/// Membuka form data balita. Mengembalikan isian baru, atau null bila dibatalkan.
Future<IsianBalita?> bukaFormBalita(BuildContext context, {IsianBalita? awal}) {
  return showModalBottomSheet<IsianBalita>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FormIsianBalita(awal: awal),
  );
}

class _FormIsianBalita extends StatefulWidget {
  final IsianBalita? awal;
  const _FormIsianBalita({this.awal});

  @override
  State<_FormIsianBalita> createState() => _FormIsianBalitaState();
}

class _FormIsianBalitaState extends State<_FormIsianBalita> {
  final _key = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.awal?.nama ?? '');
  late final _nik = TextEditingController(text: widget.awal?.nik ?? '');
  late final _tgl = TextEditingController(text: widget.awal?.tglLahir ?? '');
  late final _berat = TextEditingController(text: widget.awal?.beratLahir ?? '');
  late final _panjang = TextEditingController(text: widget.awal?.panjangLahir ?? '');
  late String _jk = widget.awal?.jk ?? '';
  bool _jkSalah = false;

  @override
  void dispose() {
    for (final c in [_nama, _nik, _tgl, _berat, _panjang]) {
      c.dispose();
    }
    super.dispose();
  }

  void _simpan() {
    final ok = _key.currentState!.validate();
    setState(() => _jkSalah = _jk.isEmpty);
    if (!ok || _jk.isEmpty) return;
    Navigator.pop(
      context,
      IsianBalita(
        id: widget.awal?.id,
        nama: _nama.text.trim(),
        nik: _nik.text.trim(),
        tglLahir: _tgl.text,
        jk: _jk,
        beratLahir: _berat.text.trim(),
        panjangLahir: _panjang.text.trim(),
      ),
    );
  }

  Widget _pilihJk(String kode, String teks) {
    final aktif = _jk == kode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _jk = kode;
          _jkSalah = false;
        }),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aktif ? kkHijau : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: aktif ? kkHijau : (_jkSalah ? kkMerah : kkGarisInput),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(kode == 'L' ? Icons.male : Icons.female,
                  size: 20, color: aktif ? Colors.white : kkAksen),
              const SizedBox(width: 6),
              Text(teks,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    color: aktif ? Colors.white : kkTeksGelap,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  String? _cekDesimal(String? v, double min, double maks, String satuan) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = kkDouble(t);
    if (n == null) return 'Harus angka';
    if (n < min || n > maks) return 'Tidak wajar ($min-$maks $satuan)';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // balita: 0-59 bulan
    final awal = DateTime(now.year - 5, now.month, now.day).add(const Duration(days: 1));
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
                    decoration: BoxDecoration(
                        color: kkGaris, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Text((widget.awal == null ? 'Tambah Data Balita' : 'Ubah Data Balita').toUpperCase(),
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: kkTeksGelap)),
                const SizedBox(height: 8),
                Container(height: 3, color: kkAksen),
                const SizedBox(height: 16),
                kkLabel('Nama balita', wajib: true),
                TextFormField(
                  controller: _nama,
                  textCapitalization: TextCapitalization.words,
                  decoration: kkDekor('Nama lengkap balita', ikon: Icons.person_outline),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Nama balita wajib diisi' : null,
                ),
                kkJarak(),
                kkLabel('NIK balita', opsional: true),
                TextFormField(
                  controller: _nik,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: kkDekor('16 digit, bila sudah ada', ikon: Icons.badge_outlined),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isNotEmpty && t.length != 16) return 'NIK harus 16 digit';
                    return null;
                  },
                ),
                kkJarak(),
                kkLabel('Tanggal lahir', wajib: true),
                FieldTanggal(
                  c: _tgl,
                  hint: 'dd/mm/yyyy',
                  awal: awal,
                  akhir: now,
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Tanggal lahir wajib diisi' : null,
                ),
                kkJarak(),
                kkLabel('Jenis kelamin', wajib: true),
                Row(children: [
                  _pilihJk('L', 'Laki-laki'),
                  const SizedBox(width: 10),
                  _pilihJk('P', 'Perempuan'),
                ]),
                if (_jkSalah)
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Text('Pilih jenis kelamin',
                        style: TextStyle(color: kkMerah, fontSize: 12.5)),
                  ),
                kkJarak(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          kkLabel('Berat lahir (kg)', opsional: true),
                          TextFormField(
                            controller: _berat,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: kkDekor('3.1', ikon: Icons.monitor_weight_outlined),
                            validator: (v) => _cekDesimal(v, 0.5, 7, 'kg'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          kkLabel('Panjang lahir (cm)', opsional: true),
                          TextFormField(
                            controller: _panjang,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: kkDekor('49', ikon: Icons.straighten),
                            validator: (v) => _cekDesimal(v, 30, 65, 'cm'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: kkTombolGaris('Batal',
                          warna: kkMerah, onPressed: () => Navigator.pop(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: kkTombolHijau('Simpan', onPressed: _simpan)),
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

/// Satu baris balita di daftar (nama, tgl lahir, JK, usia) + tautan ubah/hapus.
class BarisBalita extends StatelessWidget {
  final IsianBalita balita;
  final VoidCallback? onUbah;
  final VoidCallback? onHapus;

  const BarisBalita({super.key, required this.balita, this.onUbah, this.onHapus});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kkGaris, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(balita.nama.toUpperCase(),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: kkTeksGelap)),
          const SizedBox(height: 8),
          kkInfo('Tanggal Lahir', balita.tglLahir, lebar: 120),
          kkInfo('Jenis Kelamin', balita.jkTeks, lebar: 120),
          kkInfo('Usia', kkUsiaTeks(balita.tglLahir), lebar: 120),
          if (onUbah != null || onHapus != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onHapus != null)
                  InkWell(
                    onTap: onHapus,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: kkTautan('Hapus', warna: kkMerah),
                    ),
                  ),
                if (onHapus != null && onUbah != null) const SizedBox(width: 10),
                if (onUbah != null)
                  InkWell(
                    onTap: onUbah,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: kkTautan('Ubah'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}