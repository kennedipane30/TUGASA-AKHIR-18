import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keluarga.dart';

// ============================================================================
// FORM DATA ANAK (bottom sheet) + baris anak.
// Aturan sama dengan halaman Data Anak orang tua; usia dibatasi balita (0-59 bln).
// ============================================================================

// ---------------------------------------------------------------------------
// FORM DATA ANAK (bottom sheet)
// ---------------------------------------------------------------------------
/// Membuka form data anak. Mengembalikan isian baru, atau null bila dibatalkan.
Future<IsianAnak?> bukaFormAnak(BuildContext context, {IsianAnak? awal}) {
  return showModalBottomSheet<IsianAnak>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FormIsianAnak(awal: awal),
  );
}

class _FormIsianAnak extends StatefulWidget {
  final IsianAnak? awal;
  const _FormIsianAnak({this.awal});

  @override
  State<_FormIsianAnak> createState() => _FormIsianAnakState();
}

class _FormIsianAnakState extends State<_FormIsianAnak> {
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
      IsianAnak(
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
            color: aktif ? kkHijauMuda : kkIsi,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: aktif ? kkHijau : (_jkSalah ? kkMerah : kkGarisInput),
              width: aktif ? 1.6 : 1,
            ),
          ),
          child: Text(teks,
              style: TextStyle(
                fontSize: 15,
                fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                color: aktif ? kkHijau : kkTeksGelap,
              )),
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
                Text(widget.awal == null ? 'Tambah Data Anak' : 'Ubah Data Anak',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700, color: kkTeksGelap)),
                const SizedBox(height: 16),
                kkLabel('Nama anak', wajib: true),
                TextFormField(
                  controller: _nama,
                  textCapitalization: TextCapitalization.words,
                  decoration: kkDekor('Nama lengkap anak'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Nama anak wajib diisi' : null,
                ),
                kkJarak(),
                kkLabel('NIK anak', opsional: true),
                TextFormField(
                  controller: _nik,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: kkDekor('16 digit, bila sudah ada'),
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
                            decoration: kkDekor('3.1'),
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
                            decoration: kkDekor('49'),
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
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kkHijau,
                          side: const BorderSide(color: kkHijau),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Batal',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _simpan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kkHijau,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
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

/// Satu baris anak di daftar (nama, tgl lahir, JK, usia) + tombol ubah/hapus.
class BarisAnak extends StatelessWidget {
  final IsianAnak anak;
  final VoidCallback? onUbah;
  final VoidCallback? onHapus;

  const BarisAnak({super.key, required this.anak, this.onUbah, this.onHapus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: kkIsi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kkGarisInput),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(anak.nama,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: kkTeksGelap)),
                const SizedBox(height: 4),
                Text('${anak.tglLahir} · ${anak.jkTeks} · ${kkUsiaTeks(anak.tglLahir)}',
                    style: const TextStyle(fontSize: 13.5, color: kkTeksAbu)),
              ],
            ),
          ),
          if (onUbah != null)
            TextButton(
              onPressed: onUbah,
              style: TextButton.styleFrom(foregroundColor: kkHijau),
              child: const Text('Ubah', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (onHapus != null)
            TextButton(
              onPressed: onHapus,
              style: TextButton.styleFrom(foregroundColor: kkMerah),
              child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}