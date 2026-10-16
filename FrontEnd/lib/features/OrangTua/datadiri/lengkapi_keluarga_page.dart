import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';
import '../../auth/auth_provider.dart';
import 'data_anak_page.dart';
import 'keluarga_common.dart';

export 'keluarga_common.dart' show DataAnak, DataKeluarga, KeluargaApi;

const _hijauTua = Color(0xFF0B4D3A);
const _garis = Color(0xFFD7E6DD);

Widget _pillSinkron() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F4EA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF2EAD6A)),
          SizedBox(width: 6),
          Text('Tersinkron',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: _hijauTua)),
        ],
      ),
    );

InputDecoration _dekor(String hint,
    {IconData? icon, String? counter, bool terkunci = false}) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: Colors.black45),
    counterText: counter ?? '',
    filled: true,
    fillColor: terkunci ? const Color(0xFFF1F5F3) : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(_garis),
    enabledBorder: b(terkunci ? Colors.transparent : _garis),
    focusedBorder: b(_hijauTua),
    errorBorder: b(AppColors.merah),
    focusedErrorBorder: b(AppColors.merah),
  );
}

Widget _label(String teks, {String? ket}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        if (ket != null)
          TextSpan(
              text: ' $ket',
              style: const TextStyle(fontSize: 11, color: AppColors.teksRedup)),
      ])),
    );

Widget _gap() => const SizedBox(height: 14);

class _Kartu extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;
  final Widget child;
  const _Kartu({this.title, this.icon, this.trailing, this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.hijauMuda,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: _hijauTua),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

Widget _pillStatus(bool lengkap) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: lengkap ? AppColors.hijauMuda : AppColors.kuningMuda,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(lengkap ? 'Lengkap' : 'Belum lengkap',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: lengkap ? _hijauTua : AppColors.kuning)),
    );

// ---------------------------------------------------------------------------
// HALAMAN LENGKAPI DATA KELUARGA
// ---------------------------------------------------------------------------
class LengkapiKeluargaPage extends StatefulWidget {
  const LengkapiKeluargaPage({super.key});

  @override
  State<LengkapiKeluargaPage> createState() => _LengkapiKeluargaPageState();
}

class _LengkapiKeluargaPageState extends State<LengkapiKeluargaPage> {
  final _key = GlobalKey<FormState>();
  bool _memuat = true;
  bool _menyimpan = false;
  String? _gagal;

  bool _tanpaIbu = false;
  final _namaIbu = TextEditingController();
  final _nikIbu = TextEditingController();
  final _tglIbu = TextEditingController();
  final _hpIbu = TextEditingController();
  final _kerjaIbu = TextEditingController();
  final _alamat = TextEditingController();
  final _rt = TextEditingController();
  final _rw = TextEditingController();

  bool _tanpaAyah = false;
  final _namaAyah = TextEditingController();
  final _nikAyah = TextEditingController();
  final _tglAyah = TextEditingController();
  final _hpAyah = TextEditingController();
  final _kerjaAyah = TextEditingController();

  late final List<TextEditingController> _semua = [
    _namaIbu, _nikIbu, _tglIbu, _hpIbu, _kerjaIbu, _alamat, _rt, _rw,
    _namaAyah, _nikAyah, _tglAyah, _hpAyah, _kerjaAyah,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _semua) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _muat();
  }

  @override
  void dispose() {
    for (final c in _semua) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _muat() async {
    final user = context.read<AuthProvider>().user;
    try {
      final data = await KeluargaApi.ambil();
      final m = KeluargaApi.keModel(data,
          user: user == null ? null : Map<String, dynamic>.from(user));

      if (!mounted) return;

      _namaIbu.text = m.namaIbu;
      _nikIbu.text = m.nikIbu;
      _hpIbu.text = m.noHpIbu;

      _tanpaIbu = false;
      _tglIbu.text = m.tglLahirIbu;
      _kerjaIbu.text = m.pekerjaanIbu;
      _alamat.text = m.alamat;
      _rt.text = m.rt;
      _rw.text = m.rw;

      _tanpaAyah = m.tanpaAyah;
      _namaAyah.text = m.namaAyah;
      _nikAyah.text = m.nikAyah;
      _tglAyah.text = m.tglLahirAyah;
      _hpAyah.text = m.noHpAyah;
      _kerjaAyah.text = m.pekerjaanAyah;

      setState(() {
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

  DataKeluarga _ambil() => DataKeluarga(
        tanpaIbu: _tanpaIbu,
        namaIbu: _namaIbu.text.trim(),
        nikIbu: _nikIbu.text.trim(),
        tglLahirIbu: _tglIbu.text.trim(),
        noHpIbu: _hpIbu.text.trim(),
        pekerjaanIbu: _kerjaIbu.text.trim(),
        alamat: _alamat.text.trim(),
        rt: _rt.text.trim(),
        rw: _rw.text.trim(),
        tanpaAyah: _tanpaAyah,
        namaAyah: _namaAyah.text.trim(),
        nikAyah: _nikAyah.text.trim(),
        tglLahirAyah: _tglAyah.text.trim(),
        noHpAyah: _hpAyah.text.trim(),
        pekerjaanAyah: _kerjaAyah.text.trim(),
      );

  void _snack(String msg) {
    if (!mounted) return;
    snackDi(context, msg);
  }

  Future<void> _pilihTanggal(TextEditingController c,
      {int tahunMin = 90, int tahunMaks = 15}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: parseTgl(c.text) ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - tahunMin),
      lastDate: DateTime(now.year - tahunMaks, 12, 31),
    );
    if (d != null) c.text = fmtTgl(d);
  }

  Map<String, dynamic> _bodyProfil() => {
        'tanpa_ibu': _tanpaIbu,
        'tgl_lahir_ibu': keApi(_tglIbu.text),
        'pekerjaan_ibu': _kerjaIbu.text.trim(),
        'alamat': _alamat.text.trim(),
        'rt': _rt.text.trim(),
        'rw': _rw.text.trim(),
        'tanpa_ayah': _tanpaAyah,
        'ayah': _tanpaAyah
            ? null
            : {
                'nama': _namaAyah.text.trim(),
                'nik': _nikAyah.text.trim(),
                'tgl_lahir': keApi(_tglAyah.text),
                'no_hp': _hpAyah.text.trim(),
                'pekerjaan': _kerjaAyah.text.trim(),
              },
      };

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (!_key.currentState!.validate()) return;
    setState(() => _menyimpan = true);

    try {
      await ApiClient.dio.put('/keluarga', data: _bodyProfil(), options: opsiApi);
      if (!mounted) return;
      _snack('Data keluarga berhasil disimpan');
      Navigator.pop(context, true);
    } catch (e) {
      _snack(pesanError(e));
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Lengkapi Data Keluarga',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          Center(child: _pillSinkron()),
          const SizedBox(width: 16),
        ],
      );

  Widget _bulat(String no, bool selesai) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
              color: selesai ? AppColors.hijau : Colors.grey.shade400, width: 1.6),
        ),
        child: selesai
            ? const Icon(Icons.check, size: 18, color: AppColors.hijau)
            : Text(no,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: no == '1' ? AppColors.hijau : Colors.grey)),
      );

  Widget _stepper(DataKeluarga d) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              _bulat('1', d.ibuLengkap),
              const SizedBox(height: 4),
              const Text('Data Diri',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 15, left: 8, right: 8),
                child: Divider(height: 2, thickness: 2, color: Colors.grey.shade300),
              ),
            ),
            Column(children: [
              _bulat('2', d.ayahLengkap),
              const SizedBox(height: 4),
              const Text('Suami / Ayah',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: d.langkahSelesai / 2,
            minHeight: 7,
            backgroundColor: const Color(0xFFE6EEEA),
            color: AppColors.hijau,
          ),
        ),
        const SizedBox(height: 8),
        Text('${d.langkahSelesai} dari 2 bagian lengkap. Data boleh disimpan bertahap.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
      ],
    );
  }

  Widget _centang(bool nilai, String teks, ValueChanged<bool?> onChanged) =>
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.hijau,
        value: nilai,
        title: Text(teks, style: const TextStyle(fontSize: 13)),
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    if (_memuat) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_gagal != null) {
      return Scaffold(
        backgroundColor: AppColors.latar,
        appBar: _appBar(),
        body: Center(
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
        ),
      );
    }
    final d = _ambil();

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: _appBar(),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _menyimpan ? null : _simpan,
              icon: _menyimpan
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_alt_outlined),
              label: Text(_menyimpan ? 'Menyimpan...' : 'Simpan Data Keluarga',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ),
      ),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Kartu(child: _stepper(d)),
            _Kartu(
              title: '1. Data Diri Ibu / Wali',
              icon: Icons.person_outline,
              trailing: _pillStatus(d.ibuLengkap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _centang(_tanpaIbu, 'Tidak ada data ibu',
                      (v) => setState(() => _tanpaIbu = v ?? false)),
                  if (!_tanpaIbu) ...[
                    _label('Nama lengkap', ket: '(dari akun)'),
                    TextFormField(
                      controller: _namaIbu,
                      readOnly: true,
                      decoration: _dekor('Nama', icon: Icons.person_outline, terkunci: true),
                    ),
                    _gap(),
                    _label('NIK', ket: '(dari akun)'),
                    TextFormField(
                      controller: _nikIbu,
                      readOnly: true,
                      decoration: _dekor('NIK', icon: Icons.badge_outlined, terkunci: true),
                    ),
                    _gap(),
                    _label('Tanggal Lahir'),
                    TextFormField(
                      controller: _tglIbu,
                      readOnly: true,
                      onTap: () => _pilihTanggal(_tglIbu),
                      decoration: _dekor('dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                    ),
                    _gap(),
                    _label('No. WhatsApp', ket: '(dari akun)'),
                    TextFormField(
                      controller: _hpIbu,
                      readOnly: true,
                      decoration: _dekor('No. WhatsApp', icon: Icons.phone_outlined, terkunci: true),
                    ),
                    _gap(),
                    _label('Pekerjaan', ket: '(opsional)'),
                    TextFormField(
                      controller: _kerjaIbu,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dekor('Pekerjaan (opsional)', icon: Icons.work_outline),
                    ),
                    _gap(),
                  ],
                  _label('Alamat Tempat Tinggal'),
                  TextFormField(
                    controller: _alamat,
                    maxLines: 3,
                    decoration: _dekor('Alamat tempat tinggal lengkap...', icon: Icons.home_outlined),
                  ),
                  _gap(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('RT'),
                            TextFormField(
                              controller: _rt,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              maxLength: 3,
                              decoration: _dekor('RT'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('RW'),
                            TextFormField(
                              controller: _rw,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              maxLength: 3,
                              decoration: _dekor('RW'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _Kartu(
              title: '2. Data Suami / Ayah',
              icon: Icons.man_outlined,
              trailing: _pillStatus(d.ayahLengkap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _centang(_tanpaAyah, 'Tidak ada data suami / ayah yang diisi',
                      (v) => setState(() => _tanpaAyah = v ?? false)),
                  if (!_tanpaAyah) ...[
                    _label('Nama lengkap'),
                    TextFormField(
                      controller: _namaAyah,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dekor('Nama lengkap', icon: Icons.person_outline),
                    ),
                    _gap(),
                    _label('NIK', ket: '(opsional)'),
                    TextFormField(
                      controller: _nikAyah,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dekor('16 digit NIK',
                          icon: Icons.badge_outlined,
                          counter: '${_nikAyah.text.length}/16'),
                      validator: (v) => (v != null && v.isNotEmpty && v.length != 16)
                          ? 'NIK harus 16 digit'
                          : null,
                    ),
                    _gap(),
                    _label('Tanggal Lahir'),
                    TextFormField(
                      controller: _tglAyah,
                      readOnly: true,
                      onTap: () => _pilihTanggal(_tglAyah),
                      decoration: _dekor('dd/mm/yyyy', icon: Icons.calendar_today_outlined),
                    ),
                    _gap(),
                    _label('No. HP', ket: '(opsional)'),
                    TextFormField(
                      controller: _hpAyah,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dekor('No. HP (opsional)', icon: Icons.phone_outlined),
                      validator: (v) => (v != null && v.isNotEmpty && v.length < 10)
                          ? 'No. HP tidak valid'
                          : null,
                    ),
                    _gap(),
                    _label('Pekerjaan', ket: '(opsional)'),
                    TextFormField(
                      controller: _kerjaAyah,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dekor('Pekerjaan (opsional)', icon: Icons.work_outline),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KARTU DATA KELUARGA
// ---------------------------------------------------------------------------
class KartuLengkapiKeluarga extends StatefulWidget {
  final VoidCallback? onKembali;
  const KartuLengkapiKeluarga({super.key, this.onKembali});

  @override
  State<KartuLengkapiKeluarga> createState() => _KartuLengkapiKeluargaState();
}

class _KartuLengkapiKeluargaState extends State<KartuLengkapiKeluarga> {
  int? _selesai;
  bool _lengkap = false;
  int _jumlahAnak = 0;
  bool _gagal = false;

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
        _selesai = m.langkahSelesai;
        _lengkap = m.lengkap;
        _jumlahAnak = m.anak.length;
        _gagal = false;
      });
    } catch (_) {
      if (mounted) setState(() => _gagal = true);
    }
  }

  Future<void> _bukaOrtu() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LengkapiKeluargaPage()),
    );
    _muat();
    widget.onKembali?.call();
  }

  Future<void> _bukaAnak() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DataAnakPage()),
    );
    _muat();
    widget.onKembali?.call();
  }

  Widget _status(int selesai) {
    if (_lengkap) {
      return const _Kartu(
        color: AppColors.hijauMuda,
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.hijau),
            SizedBox(width: 10),
            Expanded(
              child: Text('Data keluarga sudah lengkap',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ),
          ],
        ),
      );
    }
    return _Kartu(
      color: AppColors.kuningMuda,
      title: 'Lengkapi Data Keluarga',
      icon: Icons.assignment_ind_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Text('$selesai/2',
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.kuning)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lengkapi data diri ibu dan data suami/ayah agar jadwal, kartu digital, dan grafik pertumbuhan dapat digunakan.',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: selesai / 2,
              minHeight: 7,
              backgroundColor: Colors.white,
              color: AppColors.hijau,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tombol(
      {required String judul,
      required String sub,
      required IconData icon,
      required bool terisi,
      required VoidCallback onTap}) {
    final fg = terisi ? Colors.white : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: terisi ? _hijauTua : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hijauTua, width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: terisi ? Colors.white.withOpacity(.15) : AppColors.hijauMuda,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: terisi ? Colors.white : _hijauTua),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14, color: fg)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: terisi ? const Color(0xFFA8F0C6) : AppColors.teksRedup)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: terisi ? Colors.white.withOpacity(.15) : AppColors.hijauMuda,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right,
                  size: 18, color: terisi ? Colors.white : _hijauTua),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selesai = _selesai;

    if (selesai == null) {
      if (!_gagal) return const SizedBox.shrink();
      return _Kartu(
        color: AppColors.kuningMuda,
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: AppColors.kuning),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Gagal memuat data keluarga',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            TextButton(onPressed: _muat, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _status(selesai),
        _Kartu(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_outline, size: 22),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kelola Data Keluarga',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text('Pilih berkas profil yang ingin diperbarui',
                          style: TextStyle(fontSize: 11, color: AppColors.teksRedup)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _tombol(
                judul: 'Data Orang Tua',
                sub: 'Ibu & Ayah / Wali',
                icon: Icons.person_add_alt_1_outlined,
                terisi: true,
                onTap: _bukaOrtu,
              ),
              const SizedBox(height: 10),
              _tombol(
                judul: _jumlahAnak > 0 ? 'Data Anak ($_jumlahAnak)' : 'Data Anak',
                sub: 'Balita & Tumbuh Kembang',
                icon: Icons.sentiment_satisfied_alt_outlined,
                terisi: false,
                onTap: _bukaAnak,
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: AppColors.teksRedup),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data keluarga tersimpan aman secara terenkripsi di perangkat Anda dan otomatis disinkronkan ke server Posyandu Care saat terhubung internet.',
                  style: TextStyle(fontSize: 11, color: AppColors.teksRedup),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}