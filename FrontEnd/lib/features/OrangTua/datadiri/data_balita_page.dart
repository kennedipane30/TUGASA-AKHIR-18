// data_balita_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../service/imunisasi_service.dart';
import 'data_orang_tua_page.dart';

const _hijauTua = kHijauHeader;
const _garisInput = kGarisInput;

InputDecoration _dekor(
  String hint, {
  IconData? icon,
  String? suffix,
}) {
  OutlineInputBorder border(Color color, [double w = 1.2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: w),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 15.5, color: Colors.black38),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 22, color: kAksen),
    suffixText: suffix,
    suffixStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      color: kTeksGelap,
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
    focusedBorder: border(_hijauTua, 1.6),
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
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
                color: kTeksGelap,
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
  if (lahir == null) return usiaBalita(tglLahir);
  return usiaDariLahir(lahir, DateTime.now());
}

Future<DataBalita?> tampilFormBalita(
  BuildContext context, {
  DataBalita? awal,
}) =>
    showModalBottomSheet<DataBalita>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormBalita(awal: awal),
    );

class DataBalitaPage extends StatefulWidget {
  const DataBalitaPage({super.key});

  @override
  State<DataBalitaPage> createState() => _DataBalitaPageState();
}

class _DataBalitaPageState extends State<DataBalitaPage> {
  List<DataBalita> _balita = [];
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
        _balita = model.balita;
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

  Future<void> _tambahAtauUbah({DataBalita? awal}) async {
    final hasil = await tampilFormBalita(context, awal: awal);
    if (hasil == null || !mounted) return;
    snackDi(
      context,
      awal == null ? 'Data balita ditambahkan' : 'Data balita diperbarui',
    );
    // Balita baru: riwayat imunisasi dicatat bidan saat kunjungan pertama.
    if (awal == null) await _infoBukuKia(hasil.nama);
    _muat();
  }

  /// Info untuk orang tua: riwayat imunisasi balita dicatat bidan, bukan diisi sendiri.
  Future<void> _infoBukuKia(String nama) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Riwayat Imunisasi Balita'),
          content: Text(
            'Bawa Buku KIA atau kartu imunisasi $nama saat pertama kali ke posyandu. '
            'Bidan akan mencatat imunisasi yang sudah pernah diterima balita.',
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti')),
          ],
        ),
      );

  Future<void> _hapus(DataBalita balita) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data balita?'),
        content: Text('Data ${balita.nama} akan dihapus dari daftar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.merah,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ya != true) return;
    try {
      if (balita.id != null) {
        await ApiClient.dio.delete(
          '/keluarga/balita/${balita.id}',
          options: opsiApi,
        );
      }
      if (!mounted) return;
      snackDi(context, 'Data balita dihapus');
      _muat();
    } catch (error) {
      if (mounted) snackDi(context, pesanError(error));
    }
  }

  /// Tombol hanya garis tepi (tanpa isi warna).
  Widget _tombolGaris(String label, Color warna, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: warna,
          backgroundColor: Colors.white,
          side: BorderSide(color: warna, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _kartuBalita(DataBalita balita) {
    final belumDicatat = balita.statusRiwayatImunisasi != StatusRiwayatImunisasi.dikonfirmasi;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: dekorKartuKeluarga(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kepalaKeluarga(balita.nama,
              kanan: balita.diarsipkan ? 'Tidak aktif' : 'Aktif',
              warnaKanan: balita.diarsipkan ? AppColors.teksRedup : kHijauHeader),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoKeluarga('Jenis Kelamin', balita.jk == 'P' ? 'Perempuan' : 'Laki-laki', lebar: 130),
                infoKeluarga('Umur', _usiaDetail(balita.tglLahir), lebar: 130),
                infoKeluarga('Tanggal Lahir', balita.tglLahir, lebar: 130),
                if (balita.diarsipkan) ...[
                  infoKeluarga('Keterangan', balita.alasanArsip.isEmpty ? '-' : balita.alasanArsip,
                      lebar: 130),
                  infoKeluarga('Sejak', balita.tglArsip.isEmpty ? '-' : balita.tglArsip, lebar: 130),
                ],
                const Divider(height: 18, color: Color(0xFFE5E7EB)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 130,
                      child: Text('Riwayat Imunisasi',
                          style: TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600, color: kTeksGelap)),
                    ),
                    const Text(': ',
                        style: TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600, color: kTeksGelap)),
                    Expanded(
                      child: Text(
                        StatusRiwayatImunisasi.label(balita.statusRiwayatImunisasi),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: belumDicatat ? AppColors.kuning : kHijauHeader,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (balita.diarsipkan)
                  // Balita arsip hanya dapat dilihat; riwayat tetap ada di menu Riwayat.
                  const Text(
                    'Data balita ini sudah tidak aktif di posyandu. '
                    'Riwayat penimbangan dan imunisasi tetap dapat dilihat.',
                    style: TextStyle(fontSize: 14.5, height: 1.4, color: AppColors.teksRedup),
                  )
                else
                  // Tombol bergaris: Hapus di kiri, Ubah di kanan.
                  Row(
                    children: [
                      Expanded(child: _tombolGaris('Hapus', AppColors.merah, () => _hapus(balita))),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              _tombolGaris('Ubah', kHijauHeader, () => _tambahAtauUbah(awal: balita))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
              Text(_gagal!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: kTeksGelap)),
              const SizedBox(height: 16),
              tombolHijauKeluarga('Coba Lagi', ikon: Icons.refresh, onPressed: () {
                setState(() => _memuat = true);
                _muat();
              }),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: _balita.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                      decoration: dekorKartuKeluarga(),
                      child: const Text(
                        'Belum ada data balita. Tekan tombol hijau di bawah '
                        'untuk menambah data balita balita.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15.5, height: 1.4, color: AppColors.teksRedup),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    // balita aktif lebih dulu, balita tidak aktif di bawah
                    for (final balita in _balita.where((a) => !a.diarsipkan)) _kartuBalita(balita),
                    for (final balita in _balita.where((a) => a.diarsipkan)) _kartuBalita(balita),
                  ],
                ),
        ),
        if (_balita.isNotEmpty)
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
        // Tombol berdiri sendiri, tanpa latar footer.
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: tombolHijauKeluarga('Tambah Balita',
                ikon: Icons.add, onPressed: () => _tambahAtauUbah()),
          ),
        ),
        body: Column(
          children: [
            const HeaderKeluarga(judul: 'Data Balita'),
            Expanded(child: _isi()),
          ],
        ),
      );
}

class _FormBalita extends StatefulWidget {
  final DataBalita? awal;

  const _FormBalita({this.awal});

  @override
  State<_FormBalita> createState() => _FormBalitaState();
}

class _FormBalitaState extends State<_FormBalita> {
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
    final balita = widget.awal;
    _nama = TextEditingController(text: balita?.nama ?? '');
    _nik = TextEditingController(text: balita?.nik ?? '');
    _tgl = TextEditingController(text: balita?.tglLahir ?? '');
    _berat = TextEditingController(text: balita?.beratLahir ?? '');
    _panjang = TextEditingController(text: balita?.panjangLahir ?? '');
    _jk = balita?.jk ?? '';
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
              '/keluarga/balita',
              data: body,
              options: opsiApi,
            )
          : await ApiClient.dio.put(
              '/keluarga/balita/$id',
              data: body,
              options: opsiApi,
            );
      final hasil = DataBalita.fromApi(
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
              color: aktif ? _hijauTua : (_jkError ? AppColors.merah : _garisInput),
              width: 1.2,
            ),
            foregroundColor: aktif ? Colors.white : kTeksGelap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
          32 +
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).viewPadding.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                judulLembarKeluarga(
                  widget.awal == null ? 'Tambah Data Balita' : 'Ubah Data Balita',
                  sub: 'Lengkapi biodata balita',
                ),
                const SizedBox(height: 18),
                _label('Nama Lengkap Balita', wajib: true),
                TextFormField(
                  controller: _nama,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dekor(
                    'Contoh: Muhammad Sara',
                    icon: Icons.person_outline,
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
                    icon: Icons.calendar_month_outlined,
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
                _label('NIK Balita', ket: '(opsional)'),
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
                            decoration: _dekor('Berat',
                                icon: Icons.monitor_weight_outlined, suffix: 'kg'),
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
                            decoration: _dekor('Panjang',
                                icon: Icons.straighten, suffix: 'cm'),
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
                      child: tombolGarisKeluarga('Batal',
                          warna: AppColors.merah, onPressed: () => Navigator.pop(context)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: tombolHijauKeluarga(
                        _menyimpan ? 'Menyimpan...' : 'Simpan Data',
                        onPressed: _menyimpan ? null : _simpan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}