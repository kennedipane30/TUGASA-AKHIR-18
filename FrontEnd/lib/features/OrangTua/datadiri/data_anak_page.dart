import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import 'keluarga_common.dart';

/// Membuka form tambah / ubah anak (bottom sheet). Mengembalikan data anak
/// yang sudah tersimpan di server, atau null jika dibatalkan.
Future<DataAnak?> tampilFormAnak(BuildContext context, {DataAnak? awal}) {
  return showModalBottomSheet<DataAnak>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FormAnak(awal: awal),
  );
}

// ---------------------------------------------------------------------------
// HALAMAN DATA ANAK (terpisah): daftar, tambah, ubah, hapus
// ---------------------------------------------------------------------------
class DataAnakPage extends StatefulWidget {
  const DataAnakPage({super.key});

  @override
  State<DataAnakPage> createState() => _DataAnakPageState();
}

class _DataAnakPageState extends State<DataAnakPage> {
  List<DataAnak> _anak = [];
  bool _memuat = true;
  String? _gagal;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final data = await KeluargaApi.ambil();
      final m = KeluargaApi.keModel(data);
      if (!mounted) return;
      setState(() {
        _anak = m.anak;
        _gagal = null;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gagal = pesanError(e);
        _memuat = false;
      });
    }
  }

  Future<void> _tambahAtauUbah({DataAnak? awal}) async {
    final hasil = await tampilFormAnak(context, awal: awal);
    if (hasil == null) return;
    if (!mounted) return;
    snackDi(context, awal == null ? 'Data anak ditambahkan' : 'Data anak diperbarui');
    _muat();
  }

  Future<void> _hapus(DataAnak a) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data anak?'),
        content: Text('Data ${a.nama} akan dihapus dari daftar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.merah, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;

    try {
      if (a.id != null) {
        await ApiClient.dio.delete('/keluarga/anak/${a.id}', options: opsiApi);
      }
      if (!mounted) return;
      snackDi(context, 'Data anak dihapus');
      _muat();
    } catch (e) {
      if (!mounted) return;
      snackDi(context, pesanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Data Anak',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.hijau,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _tambahAtauUbah(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Anak',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : _gagal != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_gagal!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _memuat = true);
                            _muat();
                          },
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (_anak.isEmpty)
                      const SectionCard(
                        title: 'Belum ada data anak',
                        icon: Icons.child_care,
                        child: Text(
                          'Tambahkan data anak balita Anda. Boleh dilengkapi nanti jika Buku KIA sedang tidak di dekat Anda.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.teksRedup),
                        ),
                      ),
                    for (final a in _anak)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.hijauMuda,
                              child: Icon(a.jk == 'P' ? Icons.female : Icons.male,
                                  color: AppColors.hijau),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.nama,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800, fontSize: 13.5)),
                                  Text(
                                    '${a.jk == 'P' ? 'Perempuan' : 'Laki-laki'} · ${usiaAnak(a.tglLahir)} · lahir ${a.tglLahir}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.teksRedup),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ubah',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _tambahAtauUbah(awal: a),
                            ),
                            IconButton(
                              tooltip: 'Hapus',
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: AppColors.merah),
                              onPressed: () => _hapus(a),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORM TAMBAH / UBAH ANAK (bottom sheet) - langsung menyimpan ke server
// ---------------------------------------------------------------------------
class _FormAnak extends StatefulWidget {
  final DataAnak? awal;
  const _FormAnak({this.awal});

  @override
  State<_FormAnak> createState() => _FormAnakState();
}

class _FormAnakState extends State<_FormAnak> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _nik;
  late final TextEditingController _tgl;
  late final TextEditingController _berat;
  late final TextEditingController _panjang;
  String _jk = '';
  bool _jkError = false;
  bool _menyimpan = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.awal;
    _nama = TextEditingController(text: a?.nama ?? '');
    _nik = TextEditingController(text: a?.nik ?? '');
    _tgl = TextEditingController(text: a?.tglLahir ?? '');
    _berat = TextEditingController(text: a?.beratLahir ?? '');
    _panjang = TextEditingController(text: a?.panjangLahir ?? '');
    _jk = a?.jk ?? '';
  }

  @override
  void dispose() {
    _nama.dispose();
    _nik.dispose();
    _tgl.dispose();
    _berat.dispose();
    _panjang.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: parseTgl(_tgl.text) ?? now,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
    );
    if (d != null) setState(() => _tgl.text = fmtTgl(d));
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    final ok = _key.currentState!.validate();
    setState(() => _jkError = _jk.isEmpty);
    if (!ok || _jk.isEmpty) return;

    setState(() {
      _menyimpan = true;
      _error = null;
    });

    // Body sesuai service.AnakInput
    final body = {
      'nama': _nama.text.trim(),
      'nik': _nik.text.trim(),
      'tgl_lahir': keApi(_tgl.text),
      'jk': _jk,
      'berat_lahir': keDouble(_berat.text),
      'panjang_lahir': keDouble(_panjang.text),
    };

    try {
      final id = widget.awal?.id;
      final r = id == null
          ? await ApiClient.dio.post('/keluarga/anak', data: body, options: opsiApi)
          : await ApiClient.dio.put('/keluarga/anak/$id', data: body, options: opsiApi);
      final hasil = DataAnak.fromApi(Map<String, dynamic>.from(r.data['data'] as Map));
      if (!mounted) return;
      Navigator.pop(context, hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _error = pesanError(e);
      });
    }
  }

  String? _rentang(String? v, double min, double maks, String nama) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < min || n > maks) return '$nama tidak wajar ($min-$maks)';
    return null;
  }

  Widget _pilihJk(String kode, String teks, IconData icon) {
    final aktif = _jk == kode;
    return Expanded(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: aktif ? AppColors.hijauMuda : AppColors.isiField,
          side: BorderSide(color: aktif ? AppColors.hijau : Colors.transparent),
          foregroundColor: aktif ? AppColors.hijau : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => setState(() {
          _jk = kode;
          _jkError = false;
        }),
        icon: Icon(icon, size: 18),
        label: Text(teks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.awal == null ? 'Tambah Data Anak' : 'Ubah Data Anak',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                decoration: dekorInput('Nama lengkap anak', icon: Icons.child_care),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              jarak(),
              TextFormField(
                controller: _tgl,
                readOnly: true,
                onTap: _pilihTanggal,
                decoration: dekorInput('Tanggal lahir',
                    hint: 'dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Tanggal lahir wajib diisi' : null,
              ),
              jarak(),
              const Text('Jenis kelamin', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _pilihJk('L', 'Laki-laki', Icons.male),
                  const SizedBox(width: 10),
                  _pilihJk('P', 'Perempuan', Icons.female),
                ],
              ),
              if (_jkError)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Pilih jenis kelamin',
                      style: TextStyle(color: AppColors.merah, fontSize: 12)),
                ),
              jarak(),
              TextFormField(
                controller: _nik,
                keyboardType: TextInputType.number,
                maxLength: 16,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: dekorInput('NIK anak (opsional)', icon: Icons.badge_outlined, counter: ''),
                validator: (v) => (v != null && v.isNotEmpty && v.length != 16)
                    ? 'NIK harus 16 digit'
                    : null,
              ),
              jarak(),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _berat,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: dekorInput('Berat lahir (kg)'),
                      validator: (v) => _rentang(v, 0.5, 7, 'Berat'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _panjang,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: dekorInput('Panjang lahir (cm)'),
                      validator: (v) => _rentang(v, 30, 65, 'Panjang'),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.merah, fontSize: 12.5)),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton('Batal',
                        filled: false, onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(_menyimpan ? 'Menyimpan...' : 'Simpan',
                        icon: Icons.check, onPressed: _menyimpan ? () {} : _simpan),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}