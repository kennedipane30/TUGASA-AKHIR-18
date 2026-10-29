import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import 'keluarga_common.dart';

const _hijauTua = Color(0xFF0B3D2E);
const _garis = Color(0xFFE6ECE8);
const _garisInput = Color(0xFFD7E6DD);

InputDecoration _dekor(String hint, {IconData? icon, String? suffix}) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.hijau),
    suffixText: suffix,
    suffixStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.hijau),
    filled: true,
    fillColor: Colors.white,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(_garisInput),
    enabledBorder: b(_garisInput),
    focusedBorder: b(_hijauTua),
    errorBorder: b(AppColors.merah),
    focusedErrorBorder: b(AppColors.merah),
  );
}

Widget _label(String teks, {bool wajib = false, String? ket}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        if (ket != null)
          TextSpan(
              text: ' $ket',
              style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
        if (wajib)
          const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.merah, fontWeight: FontWeight.w700)),
      ])),
    );

Future<DataAnak?> tampilFormAnak(BuildContext context, {DataAnak? awal}) {
  return showModalBottomSheet<DataAnak>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FormAnak(awal: awal),
  );
}

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
    if (hasil == null || !mounted) return;
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

  Widget _kartuAnak(DataAnak a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _garis),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7F0E3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(a.jk == 'P' ? Icons.female : Icons.male,
                    color: kHijauGelap, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.nama,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: _hijauTua)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.hijauMuda,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Aktif',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _hijauTua)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${a.jk == 'P' ? 'Perempuan' : 'Laki-laki'} • ${usiaAnak(a.tglLahir)} •',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup),
                    ),
                    Text('lahir ${a.tglLahir}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.teksRedup)),
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
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.merah),
                onPressed: () => _hapus(a),
              ),
            ],
          ),
          const Divider(height: 22, color: _garis),
          Row(
            children: [
              const Icon(Icons.event_note_outlined, size: 16, color: kHijauGelap),
              const SizedBox(width: 6),
              const Text('Jadwal Imunisasi: ', style: TextStyle(fontSize: 11.5)),
              const Text('HB-0 Siap',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              const Spacer(),
              InkWell(
                onTap: () {},
                child: const Row(
                  children: [
                    Text('Lihat KMS',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _hijauTua)),
                    Icon(Icons.chevron_right, size: 16, color: _hijauTua),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _isi() {
    if (_memuat) return const Center(child: CircularProgressIndicator());

    if (_gagal != null) {
      return Center(
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
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              const Text('DAFTAR TERDAFTAR',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: AppColors.teksRedup)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration:
                    const BoxDecoration(color: _hijauTua, shape: BoxShape.circle),
                child: Text('${_anak.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              const Icon(Icons.check_circle_outline, size: 14, color: kHijauGelap),
              const SizedBox(width: 4),
              const Text('Posyandu Mawar I',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _hijauTua)),
            ],
          ),
        ),
        Expanded(
          child: _anak.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Belum ada data anak. Tekan tombol hijau di bawah untuk menambah data anak balita.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.teksRedup),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [for (final a in _anak) _kartuAnak(a)],
                ),
        ),
        if (_anak.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, 14),
            child: Text(
              'Punya lebih dari 1 balita? Tekan tombol hijau di bawah untuk menambah data adik atau kakak.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.teksRedup),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hijauTua,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => _tambahAtauUbah(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Anak',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const HeaderKeluarga(judul: 'Data Anak'),
          Expanded(child: _isi()),
        ],
      ),
    );
  }
}

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
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: aktif ? _hijauTua : Colors.white,
            side: BorderSide(color: aktif ? _hijauTua : _garisInput),
            foregroundColor: aktif ? Colors.white : Colors.black87,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: () => setState(() {
            _jk = kode;
            _jkError = false;
          }),
          icon: Icon(icon, size: 18),
          label: Text(teks, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          18, 18, 18, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.awal == null ? 'Tambah Data Anak' : 'Ubah Data Anak',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _hijauTua)),
                        const SizedBox(height: 2),
                        const Text('Lengkapi biodata lengkap balita',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.teksRedup)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7F0E3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done_outlined, size: 14, color: _hijauTua),
                        SizedBox(width: 5),
                        Text('Simpan Lokal',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _hijauTua)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _label('Nama Lengkap Anak', wajib: true),
              TextFormField(
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                decoration: _dekor('Contoh: Muhammad Sara',
                    icon: Icons.sentiment_satisfied_alt_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              _label('Tanggal Lahir', wajib: true),
              TextFormField(
                controller: _tgl,
                readOnly: true,
                onTap: _pilihTanggal,
                decoration: _dekor('Pilih tanggal lahir', icon: Icons.calendar_today_outlined),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Tanggal lahir wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              _label('Jenis Kelamin', wajib: true),
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
              const SizedBox(height: 14),
              _label('NIK Anak', ket: '(opsional)'),
              TextFormField(
                controller: _nik,
                keyboardType: TextInputType.number,
                maxLength: 16,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dekor('16 digit NIK (jika ada)', icon: Icons.badge_outlined),
                validator: (v) => (v != null && v.isNotEmpty && v.length != 16)
                    ? 'NIK harus 16 digit'
                    : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Berat Lahir'),
                        TextFormField(
                          controller: _berat,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dekor('Berat (kg)', suffix: 'kg'),
                          validator: (v) => _rentang(v, 0.5, 7, 'Berat'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Panjang Lahir'),
                        TextFormField(
                          controller: _panjang,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dekor('Panjang (cm)', suffix: 'cm'),
                          validator: (v) => _rentang(v, 30, 65, 'Panjang'),
                        ),
                      ],
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _hijauTua,
                          side: const BorderSide(color: _hijauTua, width: 1.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hijauTua,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: _menyimpan ? null : _simpan,
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(_menyimpan ? 'Menyimpan...' : 'Simpan Data',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F6EC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFE5D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 20, color: _hijauTua),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Data tersimpan dengan aman dan dapat disinkronkan otomatis ke sistem Posyandu.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}