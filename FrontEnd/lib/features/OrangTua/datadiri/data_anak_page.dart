// data_anak_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../service/vaksin_service.dart';
import 'data_orang_tua_page.dart';

const _hijauTua = Color(0xFF0B3D2E);
const _garis = Color(0xFFE6ECE8);
const _garisInput = Color(0xFFD7E6DD);

InputDecoration _dekor(
  String hint, {
  IconData? icon,
  String? suffix,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 15.5, color: Colors.black38),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 20, color: AppColors.hijau),
    suffixText: suffix,
    suffixStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      color: AppColors.hijau,
    ),
    filled: true,
    fillColor: Colors.white,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
    border: border(_garisInput),
    enabledBorder: border(_garisInput),
    focusedBorder: border(_hijauTua),
    errorBorder: border(AppColors.merah),
    focusedErrorBorder: border(AppColors.merah),
  );
}

Widget _label(String teks, {bool wajib = false, String? ket}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: teks,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            if (ket != null)
              TextSpan(
                text: ' $ket',
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.teksRedup,
                ),
              ),
            if (wajib)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AppColors.merah,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );

/// Usia detail: "27 hari", "1 bulan 3 hari", "1 tahun 2 bulan".
String _usiaDetail(String tglLahir) {
  final lahir = parseTgl(tglLahir);
  if (lahir == null) return usiaAnak(tglLahir);
  return usiaDariLahir(lahir, DateTime.now());
}

Future<DataAnak?> tampilFormAnak(
  BuildContext context, {
  DataAnak? awal,
}) =>
    showModalBottomSheet<DataAnak>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormAnak(awal: awal),
    );

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
      final model = KeluargaApi.keModel(data);
      if (!mounted) return;
      setState(() {
        _anak = model.anak;
        _gagal = null;
        _memuat = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _gagal = pesanError(error);
        _memuat = false;
      });
    }
  }

  Future<void> _tambahAtauUbah({DataAnak? awal}) async {
    final hasil = await tampilFormAnak(context, awal: awal);
    if (hasil == null || !mounted) return;
    snackDi(
      context,
      awal == null ? 'Data anak ditambahkan' : 'Data anak diperbarui',
    );
    // Anak baru: langsung tanyakan riwayat vaksin sebelum posyandu.
    if (awal == null && hasil.id != null) {
      await _isiRiwayatVaksin(hasil);
    }
    _muat();
  }

  Future<void> _isiRiwayatVaksin(DataAnak anak) async {
    final lahir = parseTgl(anak.tglLahir);
    if (anak.id == null || lahir == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormRiwayatVaksin(anakId: anak.id!, nama: anak.nama, lahir: lahir),
    );
    if (ok == true && mounted) {
      snackDi(context, 'Riwayat vaksin tersimpan. Bidan akan mengonfirmasi saat posyandu.');
      _muat();
    }
  }

  Future<void> _hapus(DataAnak anak) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data anak?'),
        content: Text('Data ${anak.nama} akan dihapus dari daftar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.merah,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ya != true) return;
    try {
      if (anak.id != null) {
        await ApiClient.dio.delete(
          '/keluarga/anak/${anak.id}',
          options: opsiApi,
        );
      }
      if (!mounted) return;
      snackDi(context, 'Data anak dihapus');
      _muat();
    } catch (error) {
      if (mounted) snackDi(context, pesanError(error));
    }
  }

  Widget _kartuAnak(DataAnak anak) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _garis),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
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
                  child: Icon(
                    anak.jk == 'P' ? Icons.female : Icons.male,
                    color: kHijauGelap,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              anak.nama,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: _hijauTua,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.hijauMuda,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Aktif',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: _hijauTua,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${anak.jk == 'P' ? 'Perempuan' : 'Laki-laki'} • '
                        '${_usiaDetail(anak.tglLahir)}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          color: AppColors.teksRedup,
                        ),
                      ),
                      Text(
                        'lahir ${anak.tglLahir}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          color: AppColors.teksRedup,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ubah',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _tambahAtauUbah(awal: anak),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.merah,
                  ),
                  onPressed: () => _hapus(anak),
                ),
              ],
            ),
            const Divider(height: 22, color: _garis),
            Row(
              children: [
                const Icon(
                  Icons.vaccines_outlined,
                  size: 16,
                  color: kHijauGelap,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Riwayat vaksin: ${StatusRiwayatVaksin.label(anak.statusRiwayatVaksin)}',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: anak.statusRiwayatVaksin == StatusRiwayatVaksin.belumDitanya
                          ? AppColors.kuning
                          : _hijauTua,
                    ),
                  ),
                ),
                if (anak.statusRiwayatVaksin != StatusRiwayatVaksin.dikonfirmasi)
                  InkWell(
                    onTap: () => _isiRiwayatVaksin(anak),
                    child: Row(
                      children: [
                        Text(
                          anak.statusRiwayatVaksin == StatusRiwayatVaksin.belumDitanya ? 'Isi' : 'Ubah',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: _hijauTua,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 16, color: _hijauTua),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _isi() {
    if (_memuat) {
      return const Center(child: CircularProgressIndicator());
    }
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
              const Text(
                'DAFTAR TERDAFTAR',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .5,
                  color: AppColors.teksRedup,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: const BoxDecoration(
                  color: _hijauTua,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_anak.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.check_circle_outline,
                size: 14,
                color: kHijauGelap,
              ),
              const SizedBox(width: 4),
              const Text(
                'Posyandu Mawar I',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: _hijauTua,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _anak.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Belum ada data anak. Tekan tombol hijau di bawah '
                      'untuk menambah data anak balita.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        color: AppColors.teksRedup,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (final anak in _anak) _kartuAnak(anak),
                  ],
                ),
        ),
        if (_anak.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, 14),
            child: Text(
              'Punya lebih dari 1 balita? Tekan tombol hijau di bawah '
              'untuk menambah data adik atau kakak.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                color: AppColors.teksRedup,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => _tambahAtauUbah(),
                icon: const Icon(Icons.add),
                label: const Text(
                  'Tambah Anak',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16.5,
                  ),
                ),
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
    final anak = widget.awal;
    _nama = TextEditingController(text: anak?.nama ?? '');
    _nik = TextEditingController(text: anak?.nik ?? '');
    _tgl = TextEditingController(text: anak?.tglLahir ?? '');
    _berat = TextEditingController(text: anak?.beratLahir ?? '');
    _panjang = TextEditingController(text: anak?.panjangLahir ?? '');
    _jk = anak?.jk ?? '';
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
    final tanggal = await showDatePicker(
      context: context,
      initialDate: parseTgl(_tgl.text) ?? now,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
    );
    if (tanggal != null) setState(() => _tgl.text = fmtTgl(tanggal));
  }

  String? _rentang(
    String? value,
    double min,
    double maks,
    String nama,
  ) {
    if (value == null || value.trim().isEmpty) return null;
    final angka = double.tryParse(value.replaceAll(',', '.'));
    if (angka == null || angka < min || angka > maks) {
      return '$nama tidak wajar ($min-$maks)';
    }
    return null;
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    final valid = _key.currentState!.validate();
    setState(() => _jkError = _jk.isEmpty);
    if (!valid || _jk.isEmpty) return;

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
      final response = id == null
          ? await ApiClient.dio.post(
              '/keluarga/anak',
              data: body,
              options: opsiApi,
            )
          : await ApiClient.dio.put(
              '/keluarga/anak/$id',
              data: body,
              options: opsiApi,
            );
      final hasil = DataAnak.fromApi(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
      if (mounted) Navigator.pop(context, hasil);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _error = pesanError(error);
      });
    }
  }

  Widget _pilihJk(String kode, String teks, IconData icon) {
    final aktif = _jk == kode;
    return Expanded(
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: aktif ? _hijauTua : Colors.white,
            side: BorderSide(
              color: aktif ? _hijauTua : _garisInput,
            ),
            foregroundColor: aktif ? Colors.white : Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () => setState(() {
            _jk = kode;
            _jkError = false;
          }),
          icon: Icon(icon, size: 18),
          label: Text(
            teks,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.awal == null
                                ? 'Tambah Data Anak'
                                : 'Ubah Data Anak',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              color: _hijauTua,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Lengkapi biodata balita',
                            style: TextStyle(
                              fontSize: 15.5,
                              color: AppColors.teksRedup,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Chip(
                      avatar: Icon(
                        Icons.cloud_done_outlined,
                        size: 14,
                        color: _hijauTua,
                      ),
                      label: Text('Simpan Lokal'),
                      backgroundColor: Color(0xFFD7F0E3),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _label('Nama Lengkap Anak', wajib: true),
                TextFormField(
                  controller: _nama,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dekor(
                    'Contoh: Muhammad Sara',
                    icon: Icons.sentiment_satisfied_alt_outlined,
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Nama wajib diisi'
                          : null,
                ),
                const SizedBox(height: 14),
                _label('Tanggal Lahir', wajib: true),
                TextFormField(
                  controller: _tgl,
                  readOnly: true,
                  onTap: _pilihTanggal,
                  decoration: _dekor(
                    'Pilih tanggal lahir',
                    icon: Icons.calendar_today_outlined,
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty
                          ? 'Tanggal lahir wajib diisi'
                          : null,
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
                    child: Text(
                      'Pilih jenis kelamin',
                      style: TextStyle(
                        color: AppColors.merah,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                _label('NIK Anak', ket: '(opsional)'),
                TextFormField(
                  controller: _nik,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dekor(
                    '16 digit NIK (jika ada)',
                    icon: Icons.badge_outlined,
                  ),
                  validator: (value) =>
                      value != null &&
                              value.isNotEmpty &&
                              value.length != 16
                          ? 'NIK harus 16 digit'
                          : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Berat Lahir'),
                          TextFormField(
                            controller: _berat,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dekor('Berat (kg)', suffix: 'kg'),
                            validator: (value) =>
                                _rentang(value, .5, 7, 'Berat'),
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
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _dekor('Panjang (cm)', suffix: 'cm'),
                            validator: (value) =>
                                _rentang(value, 30, 65, 'Panjang'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.merah,
                        fontSize: 15,
                      ),
                    ),
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
                            side: const BorderSide(
                              color: _hijauTua,
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.5,
                            ),
                          ),
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
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _menyimpan ? null : _simpan,
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            _menyimpan ? 'Menyimpan...' : 'Simpan Data',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.5,
                            ),
                          ),
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
                      Icon(
                        Icons.verified_user_outlined,
                        size: 20,
                        color: _hijauTua,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data tersimpan dengan aman dan dapat disinkronkan '
                          'otomatis ke sistem Posyandu.',
                          style: TextStyle(fontSize: 15.5),
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
// ---------------------------------------------------------------------------
// FORM RIWAYAT VAKSIN SEBELUM POSYANDU
// ---------------------------------------------------------------------------
class _DosisDipilih {
  DateTime? tanggal;
  final TextEditingController tempat = TextEditingController();
  String foto = '';
  bool mengunggah = false;

  void dispose() => tempat.dispose();
}

class _FormRiwayatVaksin extends StatefulWidget {
  final String anakId;
  final String nama;
  final DateTime lahir;

  const _FormRiwayatVaksin({required this.anakId, required this.nama, required this.lahir});

  @override
  State<_FormRiwayatVaksin> createState() => _FormRiwayatVaksinState();
}

class _FormRiwayatVaksinState extends State<_FormRiwayatVaksin> {
  final _svc = VaksinService();
  String _status = ''; // sudah | belum_pernah | lupa
  List<JadwalImunisasi> _master = [];
  bool _memuatMaster = false;
  final Map<String, _DosisDipilih> _dipilih = {};
  bool _menyimpan = false;
  String? _error;

  @override
  void dispose() {
    for (final d in _dipilih.values) {
      d.dispose();
    }
    super.dispose();
  }

  DateTime get _hariIni {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int get _usiaBulan {
    final n = _hariIni;
    var b = (n.year - widget.lahir.year) * 12 + n.month - widget.lahir.month;
    if (n.day < widget.lahir.day) b--;
    return b < 0 ? 0 : b;
  }

  String _api(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pilihStatus(String s) async {
    setState(() {
      _status = s;
      _error = null;
    });
    if (s == 'sudah' && _master.isEmpty) {
      setState(() => _memuatMaster = true);
      try {
        final m = await _svc.jadwalMaster();
        if (!mounted) return;
        setState(() {
          // hanya vaksin yang sudah mungkin diterima sesuai usia anak
          _master = m.where((j) => !j.jenis.khususDaerah && j.usiaMinBulan <= _usiaBulan).toList();
          _memuatMaster = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _memuatMaster = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _pilihTanggal(_DosisDipilih d) async {
    final t = await showDatePicker(
      context: context,
      initialDate: d.tanggal ?? _hariIni,
      firstDate: widget.lahir,
      lastDate: _hariIni,
    );
    if (t != null) setState(() => d.tanggal = t);
  }

  Future<void> _ambilFoto(_DosisDipilih d) async {
    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (sumber == null) return;
    final x = await ImagePicker().pickImage(source: sumber, maxWidth: 1600, imageQuality: 80);
    if (x == null) return;
    setState(() => d.mengunggah = true);
    try {
      final nama = await _svc.unggahBukti(x.path);
      if (!mounted) return;
      setState(() {
        d.foto = nama;
        d.mengunggah = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => d.mengunggah = false);
      snackDi(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _simpan() async {
    if (_status.isEmpty) {
      setState(() => _error = 'Pilih salah satu jawaban');
      return;
    }
    final items = <Map<String, dynamic>>[];
    if (_status == 'sudah') {
      if (_dipilih.isEmpty) {
        setState(() => _error = 'Centang vaksin yang sudah diterima anak');
        return;
      }
      for (final e in _dipilih.entries) {
        final d = e.value;
        if (d.tanggal == null || d.tempat.text.trim().isEmpty) {
          setState(() => _error = 'Isi tanggal dan tempat untuk setiap vaksin yang dicentang');
          return;
        }
        if (d.mengunggah) {
          setState(() => _error = 'Tunggu foto selesai diunggah');
          return;
        }
        items.add({
          'jenis_vaksin_id': e.key.split('|').first,
          'dosis_ke': int.tryParse(e.key.split('|').last) ?? 1,
          'tanggal_pemberian': _api(d.tanggal!),
          'tempat': d.tempat.text.trim(),
          'foto_bukti': d.foto,
        });
      }
    }
    setState(() {
      _menyimpan = true;
      _error = null;
    });
    try {
      await _svc.laporRiwayatAwal(anakId: widget.anakId, status: _status, items: items);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _opsi(String kode, String judul, String ket, IconData ikon) {
    final aktif = _status == kode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pilihStatus(kode),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: aktif ? const Color(0xFFE3F6EC) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: aktif ? _hijauTua : _garisInput, width: aktif ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(ikon, color: _hijauTua),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5)),
                    Text(ket, style: const TextStyle(fontSize: 15, color: AppColors.teksRedup)),
                  ],
                ),
              ),
              Icon(aktif ? Icons.radio_button_checked : Icons.radio_button_off, color: _hijauTua),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barisVaksin(JadwalImunisasi j) {
    final d = _dipilih[j.kunci];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: d != null ? const Color(0xFFF0FAF5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: d != null ? _hijauTua : _garisInput),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: d != null,
            dense: true,
            activeColor: _hijauTua,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(j.namaDosis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            subtitle: Text('Biasanya usia ${j.labelUsia}', style: const TextStyle(fontSize: 15)),
            onChanged: (v) => setState(() {
              if (v == true) {
                _dipilih[j.kunci] = _DosisDipilih();
              } else {
                _dipilih.remove(j.kunci)?.dispose();
              }
            }),
          ),
          if (d != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _pilihTanggal(d),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _garisInput),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.hijau),
                          const SizedBox(width: 8),
                          Text(
                            d.tanggal == null ? 'Tanggal diberikan *' : fmtTgl(d.tanggal!),
                            style: TextStyle(
                              fontSize: 16,
                              color: d.tanggal == null ? Colors.black45 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: d.tempat,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dekor('Tempat * (mis. RSUD Porsea, Bidan Praktik)', icon: Icons.local_hospital_outlined),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: d.mengunggah ? null : () => _ambilFoto(d),
                        icon: Icon(d.foto.isEmpty ? Icons.add_a_photo_outlined : Icons.check_circle, size: 18),
                        label: Text(d.mengunggah
                            ? 'Mengunggah...'
                            : (d.foto.isEmpty ? 'Foto bukti (opsional)' : 'Foto terunggah, ganti')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Riwayat Vaksin',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: _hijauTua),
            ),
            const SizedBox(height: 2),
            Text(
              'Apakah ${widget.nama} sudah pernah menerima vaksin sebelum ke posyandu '
              '(di rumah sakit, puskesmas, klinik, atau bidan praktik)?',
              style: const TextStyle(fontSize: 16, color: AppColors.teksRedup, height: 1.4),
            ),
            const SizedBox(height: 14),
            _opsi('belum_pernah', 'Belum pernah', 'Anak belum pernah divaksin', Icons.block_outlined),
            _opsi('sudah', 'Sudah pernah', 'Pilih vaksin yang sudah diterima', Icons.vaccines_outlined),
            _opsi('lupa', 'Lupa / tidak tahu', 'Bidan akan menanyakan saat posyandu', Icons.help_outline),
            if (_status == 'sudah') ...[
              const SizedBox(height: 6),
              if (_memuatMaster)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final j in _master) _barisVaksin(j),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(color: AppColors.merah, fontSize: 15)),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F6EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Vaksin yang Anda isi tidak akan diberikan lagi di posyandu. '
                'Bidan akan mengonfirmasi data ini saat kunjungan pertama.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _hijauTua,
                        side: const BorderSide(color: _hijauTua, width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Nanti saja', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hijauTua,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: _menyimpan ? null : _simpan,
                      child: Text(_menyimpan ? 'Menyimpan...' : 'Simpan',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}