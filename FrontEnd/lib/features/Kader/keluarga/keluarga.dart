import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';

// ============================================================================
// BAGIAN BERSAMA FITUR "DATA KELUARGA"
// Dipakai oleh: keluarga_page, tambah_keluarga_page, edit_keluarga_page.
// Aturan isian sama dengan halaman Data Orang Tua & Data Anak milik orang tua,
// dan divalidasi ulang oleh backend (/kader/keluarga).
// ============================================================================

const kkHijau = Color(0xFF065F46);
const kkHijauMuda = Color(0xFFE7F5EF);
const kkTeksGelap = Color(0xFF0F172A);
const kkTeksAbu = Color(0xFF64748B);
const kkGaris = Color(0xFFE6ECE8);
const kkGarisInput = Color(0xFFD7E6DD);
const kkIsi = Color(0xFFF7FAF8);
const kkMerah = Color(0xFFDC2626);
const kkLatar = Color(0xFFF4F7F5);

final Options _opsi = Options(receiveTimeout: const Duration(seconds: 15));

// ---------------------------------------------------------------------------
// HELPER
// ---------------------------------------------------------------------------
String kkPesanError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) return d['error'].toString();
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server tidak merespons. Periksa koneksi.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server.';
      default:
        return 'Terjadi kesalahan (kode ${e.response?.statusCode ?? '-'}).';
    }
  }
  return 'Terjadi kesalahan: $e';
}

/// "dd/mm/yyyy" -> DateTime
DateTime? kkParseTgl(String s) {
  final p = s.split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

String kkFmtTgl(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "2026-10-01T00:00:00Z" -> "01/10/2026"
String kkDariApi(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  if (s.length < 10) return '';
  final p = s.substring(0, 10).split('-');
  if (p.length != 3) return '';
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// "01/10/2026" -> "2026-10-01"
String kkKeApi(String tgl) {
  final d = kkParseTgl(tgl);
  if (d == null) return '';
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String kkAngka(dynamic v) {
  if (v == null) return '';
  final n = double.tryParse(v.toString());
  if (n == null) return '';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

double? kkDouble(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

int kkUsiaBulan(DateTime lahir) {
  final n = DateTime.now();
  var bln = (n.year - lahir.year) * 12 + (n.month - lahir.month);
  if (n.day < lahir.day) bln--;
  return bln < 0 ? 0 : bln;
}

String kkUsiaTeks(String tgl) {
  final l = kkParseTgl(tgl);
  if (l == null) return '-';
  final bln = kkUsiaBulan(l);
  return bln >= 12 ? '${bln ~/ 12} th ${bln % 12} bln' : '$bln bln';
}

void kkSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

String? _str(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------
class RingkasKeluarga {
  final String keluargaId, namaIbu, nik, noHp, alamat;
  final int jumlahAnak;
  final bool punyaAkun;

  RingkasKeluarga({
    required this.keluargaId,
    required this.namaIbu,
    required this.nik,
    required this.noHp,
    required this.alamat,
    required this.jumlahAnak,
    required this.punyaAkun,
  });

  factory RingkasKeluarga.fromJson(Map<String, dynamic> j) => RingkasKeluarga(
        keluargaId: j['keluarga_id'].toString(),
        namaIbu: (j['nama_ibu'] ?? '').toString(),
        nik: (j['nik'] ?? '').toString(),
        noHp: (j['no_hp'] ?? '').toString(),
        alamat: (j['alamat'] ?? '').toString(),
        jumlahAnak: (j['jumlah_anak'] as num?)?.toInt() ?? 0,
        punyaAkun: j['punya_akun'] == true,
      );
}

/// Isian satu anak (tanggal lahir dd/mm/yyyy).
class IsianAnak {
  String? id;
  String nama, nik, tglLahir, jk, beratLahir, panjangLahir;

  IsianAnak({
    this.id,
    this.nama = '',
    this.nik = '',
    this.tglLahir = '',
    this.jk = '',
    this.beratLahir = '',
    this.panjangLahir = '',
  });

  factory IsianAnak.fromApi(Map<String, dynamic> j) => IsianAnak(
        id: j['id']?.toString(),
        nama: (j['nama'] ?? '').toString(),
        nik: (j['nik'] ?? '').toString(),
        tglLahir: kkDariApi(j['tanggal_lahir']),
        jk: (j['jenis_kelamin'] ?? '').toString(),
        beratLahir: kkAngka(j['berat_lahir_kg']),
        panjangLahir: kkAngka(j['panjang_lahir_cm']),
      );

  Map<String, dynamic> toJson() => {
        'nama': nama.trim(),
        'nik': nik.trim(),
        'tgl_lahir': kkKeApi(tglLahir),
        'jk': jk,
        'berat_lahir': kkDouble(beratLahir),
        'panjang_lahir': kkDouble(panjangLahir),
      };

  String get jkTeks => jk == 'L' ? 'Laki-laki' : (jk == 'P' ? 'Perempuan' : '-');
}

// ---------------------------------------------------------------------------
// API  (/kader/...)
// ---------------------------------------------------------------------------
class KeluargaAkunApi {
  /// Cek langsung saat NIK / No. HP diisi. Hasil: {nik_terpakai, no_hp_terpakai}
  static Future<Map<String, dynamic>> cekAkun({String nik = '', String noHp = ''}) async {
    final r = await ApiClient.dio.get('/kader/cek-akun',
        queryParameters: {'nik': nik, 'no_hp': noHp}, options: _opsi);
    return Map<String, dynamic>.from(r.data['data'] as Map);
  }

  static Future<List<RingkasKeluarga>> cari(String kata) async {
    final r = await ApiClient.dio
        .get('/kader/keluarga', queryParameters: {'cari': kata}, options: _opsi);
    final list = (r.data['data'] as List?) ?? [];
    return list
        .map((e) => RingkasKeluarga.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<Map<String, dynamic>> tambah(Map<String, dynamic> body) async {
    final r = await ApiClient.dio.post('/kader/keluarga', data: body, options: _opsi);
    return Map<String, dynamic>.from(r.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> detail(String id) async {
    final r = await ApiClient.dio.get('/kader/keluarga/$id', options: _opsi);
    return Map<String, dynamic>.from(r.data['data'] as Map);
  }

  static Future<void> ubahProfil(String id, Map<String, dynamic> body) async {
    await ApiClient.dio.put('/kader/keluarga/$id', data: body, options: _opsi);
  }

  static Future<void> tambahAnak(String id, IsianAnak a) async {
    await ApiClient.dio.post('/kader/keluarga/$id/anak', data: a.toJson(), options: _opsi);
  }

  static Future<void> ubahAnak(String id, IsianAnak a) async {
    await ApiClient.dio
        .put('/kader/keluarga/$id/anak/${a.id}', data: a.toJson(), options: _opsi);
  }
}

// ---------------------------------------------------------------------------
// WIDGET UMUM
// ---------------------------------------------------------------------------
PreferredSizeWidget kkAppBar(String judul) => AppBar(
      backgroundColor: kkHijau,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(judul,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
    );

Widget kkLabel(String teks, {bool opsional = false, bool wajib = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(
        text: teks,
        style: const TextStyle(
            fontSize: 14.5, fontWeight: FontWeight.w600, color: kkTeksGelap),
        children: [
          if (wajib) const TextSpan(text: ' *', style: TextStyle(color: kkMerah)),
          if (opsional)
            const TextSpan(
              text: ' (opsional)',
              style: TextStyle(fontWeight: FontWeight.w400, color: kkTeksAbu),
            ),
        ],
      )),
    );

Widget kkJarak() => const SizedBox(height: 14);

InputDecoration kkDekor(String hint, {Widget? suffix, bool terkunci = false}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    counterText: '',
    isDense: true,
    filled: true,
    fillColor: terkunci ? const Color(0xFFEFF2F0) : kkIsi,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: b(kkGarisInput),
    disabledBorder: b(kkGarisInput),
    focusedBorder: b(kkHijau, 1.6),
    errorBorder: b(kkMerah),
    focusedErrorBorder: b(kkMerah, 1.6),
  );
}

/// Kartu putih berjudul untuk satu bagian form.
class KartuBagian extends StatelessWidget {
  final String judul;
  final String? sub;
  final Widget child;
  final Widget? aksi;

  const KartuBagian({super.key, required this.judul, this.sub, required this.child, this.aksi});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kkGaris),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(judul,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: kkTeksGelap)),
              ),
              if (aksi != null) aksi!,
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: const TextStyle(fontSize: 13.5, color: kkTeksAbu)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Bar tombol bawah: [kiri] [kanan].
class BarAksi extends StatelessWidget {
  final String labelKiri, labelKanan;
  final VoidCallback? onKiri, onKanan;
  final bool memuat;

  const BarAksi({
    super.key,
    required this.labelKiri,
    required this.labelKanan,
    this.onKiri,
    this.onKanan,
    this.memuat = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kkGaris)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: memuat ? null : onKiri,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kkHijau,
                  side: const BorderSide(color: kkHijau),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(labelKiri,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: memuat ? null : onKanan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kkHijau,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: memuat
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(labelKanan,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Field tanggal (dd/mm/yyyy) dengan date picker.
class FieldTanggal extends StatelessWidget {
  final TextEditingController c;
  final String hint;
  final DateTime awal, akhir;
  final DateTime? bawaan;
  final String? Function(String?)? validator;

  const FieldTanggal({
    super.key,
    required this.c,
    required this.hint,
    required this.awal,
    required this.akhir,
    this.bawaan,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: c,
      readOnly: true,
      validator: validator,
      decoration: kkDekor(hint, suffix: const Icon(Icons.calendar_today_outlined, size: 20)),
      onTap: () async {
        var awalPilih = kkParseTgl(c.text) ?? bawaan ?? akhir;
        if (awalPilih.isBefore(awal)) awalPilih = awal;
        if (awalPilih.isAfter(akhir)) awalPilih = akhir;
        final d = await showDatePicker(
          context: context,
          initialDate: awalPilih,
          firstDate: awal,
          lastDate: akhir,
        );
        if (d != null) c.text = kkFmtTgl(d);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// FORM DATA KELUARGA (ibu + alamat + suami/ayah)
// ---------------------------------------------------------------------------
class IsianKeluarga {
  final tglLahirIbu = TextEditingController();
  final pekerjaanIbu = TextEditingController();
  final alamat = TextEditingController();
  final rt = TextEditingController();
  final rw = TextEditingController();
  bool tanpaAyah = false;
  final namaAyah = TextEditingController();
  final nikAyah = TextEditingController();
  final tglLahirAyah = TextEditingController();
  final hpAyah = TextEditingController();
  final pekerjaanAyah = TextEditingController();

  List<TextEditingController> get _semua => [
        tglLahirIbu, pekerjaanIbu, alamat, rt, rw, //
        namaAyah, nikAyah, tglLahirAyah, hpAyah, pekerjaanAyah,
      ];

  void dispose() {
    for (final c in _semua) {
      c.dispose();
    }
  }

  /// Isi dari respons /kader/keluarga/:id
  void isiDari(Map<String, dynamic> data) {
    final k = data['keluarga'] is Map ? Map<String, dynamic>.from(data['keluarga']) : null;
    final ibu = data['ibu'] is Map ? Map<String, dynamic>.from(data['ibu']) : null;
    final ayah = data['ayah'] is Map ? Map<String, dynamic>.from(data['ayah']) : null;
    tglLahirIbu.text = kkDariApi(ibu?['tanggal_lahir']);
    pekerjaanIbu.text = (ibu?['pekerjaan'] ?? '').toString();
    alamat.text = (k?['alamat'] ?? '').toString();
    rt.text = (k?['rt'] ?? '').toString();
    rw.text = (k?['rw'] ?? '').toString();
    tanpaAyah = k?['tanpa_ayah'] == true;
    namaAyah.text = (ayah?['nama'] ?? '').toString();
    nikAyah.text = (ayah?['nik'] ?? '').toString();
    tglLahirAyah.text = kkDariApi(ayah?['tanggal_lahir']);
    hpAyah.text = (ayah?['no_hp'] ?? '').toString();
    pekerjaanAyah.text = (ayah?['pekerjaan'] ?? '').toString();
  }

  /// Body sesuai ProfilInput backend.
  Map<String, dynamic> toJson() => {
        'tanpa_ibu': false,
        'tgl_lahir_ibu': kkKeApi(tglLahirIbu.text),
        'pekerjaan_ibu': pekerjaanIbu.text.trim(),
        'alamat': alamat.text.trim(),
        'rt': rt.text.trim(),
        'rw': rw.text.trim(),
        'tanpa_ayah': tanpaAyah,
        'ayah': tanpaAyah || namaAyah.text.trim().isEmpty
            ? null
            : {
                'nama': namaAyah.text.trim(),
                'nik': nikAyah.text.trim(),
                'tgl_lahir': kkKeApi(tglLahirAyah.text),
                'no_hp': hpAyah.text.trim(),
                'pekerjaan': pekerjaanAyah.text.trim(),
              },
      };

  String get ringkasAlamat {
    final b = StringBuffer(alamat.text.trim());
    if (rt.text.trim().isNotEmpty) b.write(', RT ${rt.text.trim()}');
    if (rw.text.trim().isNotEmpty) b.write(' / RW ${rw.text.trim()}');
    return b.toString();
  }
}

/// Isi form data keluarga. Dibungkus Form milik halaman pemanggil.
class FormDataKeluarga extends StatefulWidget {
  final IsianKeluarga isian;
  final String? nikIbu; // agar NIK ayah tidak sama dengan NIK ibu

  const FormDataKeluarga({super.key, required this.isian, this.nikIbu});

  @override
  State<FormDataKeluarga> createState() => _FormDataKeluargaState();
}

class _FormDataKeluargaState extends State<FormDataKeluarga> {
  IsianKeluarga get i => widget.isian;

  String? _rtRw(String? v, String nama) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    if (t.length > 3 || int.tryParse(t) == null) return '$nama maks. 3 angka';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      children: [
        KartuBagian(
          judul: 'Data Ibu / Wali',
          sub: 'Lengkapi data diri dan alamat tempat tinggal.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              kkLabel('Tanggal lahir ibu', wajib: true),
              FieldTanggal(
                c: i.tglLahirIbu,
                hint: 'dd/mm/yyyy',
                awal: DateTime(now.year - 70),
                akhir: DateTime(now.year - 12, 12, 31),
                bawaan: DateTime(now.year - 25),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Tanggal lahir ibu wajib diisi' : null,
              ),
              kkJarak(),
              kkLabel('Pekerjaan', opsional: true),
              TextFormField(
                controller: i.pekerjaanIbu,
                textCapitalization: TextCapitalization.words,
                decoration: kkDekor('Contoh: Ibu rumah tangga'),
              ),
              kkJarak(),
              kkLabel('Alamat', wajib: true),
              TextFormField(
                controller: i.alamat,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: kkDekor('Nama jalan / dusun / desa'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Alamat wajib diisi' : null,
              ),
              kkJarak(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        kkLabel('RT', opsional: true),
                        TextFormField(
                          controller: i.rt,
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: kkDekor('001'),
                          validator: (v) => _rtRw(v, 'RT'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        kkLabel('RW', wajib: true),
                        TextFormField(
                          controller: i.rw,
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: kkDekor('002'),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'RW wajib diisi'
                              : _rtRw(v, 'RW'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        KartuBagian(
          judul: 'Data Suami / Ayah',
          sub: 'Semua isian bagian ini opsional.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => i.tanpaAyah = !i.tanpaAyah),
                child: Row(
                  children: [
                    Checkbox(
                      value: i.tanpaAyah,
                      activeColor: kkHijau,
                      onChanged: (v) => setState(() => i.tanpaAyah = v ?? false),
                    ),
                    const Expanded(
                      child: Text('Tidak ada data suami / ayah',
                          style: TextStyle(fontSize: 14.5, color: kkTeksGelap)),
                    ),
                  ],
                ),
              ),
              if (!i.tanpaAyah) ...[
                const SizedBox(height: 8),
                kkLabel('Nama suami / ayah', opsional: true),
                TextFormField(
                  controller: i.namaAyah,
                  textCapitalization: TextCapitalization.words,
                  decoration: kkDekor('Nama lengkap'),
                ),
                kkJarak(),
                kkLabel('NIK', opsional: true),
                TextFormField(
                  controller: i.nikAyah,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: kkDekor('16 digit'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    if (t.length != 16) return 'NIK harus 16 digit';
                    if (widget.nikIbu != null && t == widget.nikIbu) {
                      return 'NIK ayah tidak boleh sama dengan NIK ibu';
                    }
                    if (i.namaAyah.text.trim().isEmpty) return 'Isi nama suami / ayah';
                    return null;
                  },
                ),
                kkJarak(),
                kkLabel('Tanggal lahir', opsional: true),
                FieldTanggal(
                  c: i.tglLahirAyah,
                  hint: 'dd/mm/yyyy',
                  awal: DateTime(now.year - 80),
                  akhir: DateTime(now.year - 12, 12, 31),
                  bawaan: DateTime(now.year - 28),
                ),
                kkJarak(),
                kkLabel('No. HP', opsional: true),
                TextFormField(
                  controller: i.hpAyah,
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: kkDekor('08xxxxxxxxxx'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isNotEmpty && (t.length < 10 || t.length > 15)) {
                      return 'No. HP 10-15 digit';
                    }
                    return null;
                  },
                ),
                kkJarak(),
                kkLabel('Pekerjaan', opsional: true),
                TextFormField(
                  controller: i.pekerjaanAyah,
                  textCapitalization: TextCapitalization.words,
                  decoration: kkDekor('Contoh: Petani'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Baris info "Label : nilai" (read-only).
Widget kkInfo(String label, String nilai) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(fontSize: 14.5, color: kkTeksAbu)),
          ),
          const Text(': ', style: TextStyle(fontSize: 14.5, color: kkTeksAbu)),
          Expanded(
            child: Text(_str(nilai) ?? '-',
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600, color: kkTeksGelap)),
          ),
        ],
      ),
    );