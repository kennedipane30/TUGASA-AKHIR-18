import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_anak.dart';
import 'keluarga.dart';

/// "Tambahkan Akun" oleh kader (sesuai BPMN):
///   1. Akun     : nama, NIK, No. HP, PIN (NIK & No. HP dicek langsung)
///   2. Keluarga : data ibu, alamat, suami/ayah (opsional)
///   3. Anak     : satu atau lebih data anak
///   -> Simpan (satu transaksi di backend)
/// PIN disebutkan oleh orang tua dan dicatat/disampaikan manual di luar sistem.
class TambahKeluargaPage extends StatefulWidget {
  const TambahKeluargaPage({super.key});

  @override
  State<TambahKeluargaPage> createState() => _TambahKeluargaPageState();
}

class _TambahKeluargaPageState extends State<TambahKeluargaPage> {
  static const _judulLangkah = ['Akun', 'Keluarga', 'Anak'];

  int _langkah = 0;
  bool _menyimpan = false;
  bool _setuju = false;

  // langkah 1: akun
  final _keyAkun = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _nik = TextEditingController();
  final _hp = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _lihatPin = false;

  bool? _nikTerpakai; // null: belum dicek
  bool? _hpTerpakai;
  bool _cekNik = false, _cekHp = false;
  Timer? _tundaNik, _tundaHp;

  // langkah 2: keluarga
  final _keyKeluarga = GlobalKey<FormState>();
  final _keluarga = IsianKeluarga();

  // langkah 3: anak
  final List<IsianAnak> _anak = [];

  @override
  void dispose() {
    _tundaNik?.cancel();
    _tundaHp?.cancel();
    for (final c in [_nama, _nik, _hp, _pin, _pin2]) {
      c.dispose();
    }
    _keluarga.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- cek NIK & HP
  void _ubahNik(String v) {
    _tundaNik?.cancel();
    setState(() => _nikTerpakai = null);
    if (v.length == 16) {
      _tundaNik = Timer(const Duration(milliseconds: 400), _periksaNik);
    }
  }

  void _ubahHp(String v) {
    _tundaHp?.cancel();
    setState(() => _hpTerpakai = null);
    if (v.length >= 10) {
      _tundaHp = Timer(const Duration(milliseconds: 500), _periksaHp);
    }
  }

  Future<void> _periksaNik() async {
    final nik = _nik.text.trim();
    if (nik.length != 16) return;
    setState(() => _cekNik = true);
    try {
      final r = await KeluargaAkunApi.cekAkun(nik: nik);
      if (!mounted || nik != _nik.text.trim()) return;
      setState(() => _nikTerpakai = r['nik_terpakai'] == true);
    } catch (_) {
      // gagal cek: tetap divalidasi ulang oleh server saat simpan
    } finally {
      if (mounted) setState(() => _cekNik = false);
    }
  }

  Future<void> _periksaHp() async {
    final hp = _hp.text.trim();
    if (hp.length < 10) return;
    setState(() => _cekHp = true);
    try {
      final r = await KeluargaAkunApi.cekAkun(noHp: hp);
      if (!mounted || hp != _hp.text.trim()) return;
      setState(() => _hpTerpakai = r['no_hp_terpakai'] == true);
    } catch (_) {
      // divalidasi ulang oleh server saat simpan
    } finally {
      if (mounted) setState(() => _cekHp = false);
    }
  }

  Widget? _tandaCek(bool memuat, bool? terpakai) {
    if (memuat) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (terpakai == false) return const Icon(Icons.check_circle, color: kkHijau);
    if (terpakai == true) return const Icon(Icons.error, color: kkMerah);
    return null;
  }

  Widget _peringatan(String teks) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(teks,
            style: const TextStyle(
                fontSize: 13.5, color: kkMerah, fontWeight: FontWeight.w600)),
      );

  // ---------------------------------------------------------------- navigasi
  Future<void> _lanjut() async {
    FocusScope.of(context).unfocus();
    if (_langkah == 0) {
      if (!_keyAkun.currentState!.validate()) return;
      // pastikan NIK & No. HP sudah dicek
      if (_nikTerpakai == null) await _periksaNik();
      if (_hpTerpakai == null) await _periksaHp();
      if (!mounted) return;
      if (_nikTerpakai == true || _hpTerpakai == true) {
        _keyAkun.currentState!.validate();
        kkSnack(context, _nikTerpakai == true ? 'NIK telah digunakan' : 'No. HP telah digunakan');
        return;
      }
      setState(() => _langkah = 1);
    } else if (_langkah == 1) {
      if (!_keyKeluarga.currentState!.validate()) return;
      setState(() => _langkah = 2);
    } else {
      await _simpan();
    }
  }

  void _kembali() {
    FocusScope.of(context).unfocus();
    if (_langkah == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _langkah--);
    }
  }

  // ---------------------------------------------------------------- anak
  bool _dobel(IsianAnak a, {int? kecuali}) {
    for (var i = 0; i < _anak.length; i++) {
      if (i == kecuali) continue;
      final b = _anak[i];
      if (a.nik.isNotEmpty && a.nik == b.nik) return true;
      if (a.nama.toLowerCase() == b.nama.toLowerCase() && a.tglLahir == b.tglLahir) {
        return true;
      }
    }
    return false;
  }

  Future<void> _tambahAnak() async {
    final a = await bukaFormAnak(context);
    if (a == null || !mounted) return;
    if (_dobel(a)) {
      kkSnack(context, 'Data anak sama dengan anak yang sudah ditambahkan');
      return;
    }
    setState(() => _anak.add(a));
  }

  Future<void> _ubahAnak(int i) async {
    final a = await bukaFormAnak(context, awal: _anak[i]);
    if (a == null || !mounted) return;
    if (_dobel(a, kecuali: i)) {
      kkSnack(context, 'Data anak sama dengan anak yang sudah ditambahkan');
      return;
    }
    setState(() => _anak[i] = a);
  }

  // ---------------------------------------------------------------- simpan
  Future<void> _simpan() async {
    if (_anak.isEmpty) {
      kkSnack(context, 'Tambahkan minimal satu data anak');
      return;
    }
    if (!_setuju) {
      kkSnack(context, 'Centang konfirmasi bahwa data sudah diperiksa');
      return;
    }
    setState(() => _menyimpan = true);
    try {
      await KeluargaAkunApi.tambah({
        'nama': _nama.text.trim(),
        'nik': _nik.text.trim(),
        'no_hp': _hp.text.trim(),
        'pin': _pin.text,
        'profil': _keluarga.toJson(),
        'anak': _anak.map((a) => a.toJson()).toList(),
      });
      if (!mounted) return;
      await _dialogBerhasil();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final pesan = kkPesanError(e);
      // NIK / No. HP keburu dipakai akun lain: kembali ke langkah akun
      if (pesan == 'NIK telah digunakan' || pesan == 'No. HP telah digunakan') {
        setState(() {
          if (pesan.startsWith('NIK')) _nikTerpakai = true;
          if (pesan.startsWith('No. HP')) _hpTerpakai = true;
          _langkah = 0;
        });
      }
      kkSnack(context, pesan);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  Future<void> _dialogBerhasil() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Akun berhasil dibuat',
            style: TextStyle(fontWeight: FontWeight.w700, color: kkTeksGelap)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            kkInfo('Nama', _nama.text.trim()),
            kkInfo('NIK', _nik.text.trim()),
            kkInfo('No. HP', _hp.text.trim()),
            kkInfo('Jumlah anak', '${_anak.length}'),
            const SizedBox(height: 8),
            const Text(
              'Orang tua dapat masuk memakai NIK atau No. HP dan PIN yang mereka sebutkan. '
              'PIN tidak ditampilkan di sistem.',
              style: TextStyle(fontSize: 13.5, color: kkTeksAbu, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(c),
            style: ElevatedButton.styleFrom(
              backgroundColor: kkHijau,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- tampilan
  Widget _penandaLangkah() {
    Widget bulat(int i) {
      final selesai = i < _langkah, aktif = i == _langkah;
      return Column(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selesai || aktif ? kkHijau : Colors.white,
              border: Border.all(color: selesai || aktif ? kkHijau : kkGarisInput),
            ),
            child: selesai
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text('${i + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: aktif ? Colors.white : kkTeksAbu,
                    )),
          ),
          const SizedBox(height: 6),
          Text(_judulLangkah[i],
              style: TextStyle(
                fontSize: 13,
                color: aktif || selesai ? kkHijau : kkTeksAbu,
                fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
              )),
        ],
      );
    }

    Widget garis(int i) => Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 22, left: 6, right: 6),
            color: i < _langkah ? kkHijau : kkGarisInput,
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kkGaris),
      ),
      child: Row(children: [bulat(0), garis(0), bulat(1), garis(1), bulat(2)]),
    );
  }

  Widget _langkahAkun() {
    return Form(
      key: _keyAkun,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: KartuBagian(
        judul: 'Data Akun Ibu / Wali',
        sub: 'Dipakai orang tua untuk masuk ke aplikasi.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            kkLabel('Nama lengkap', wajib: true),
            TextFormField(
              controller: _nama,
              textCapitalization: TextCapitalization.words,
              decoration: kkDekor('Sesuai KTP'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
            ),
            kkJarak(),
            kkLabel('NIK', wajib: true),
            TextFormField(
              controller: _nik,
              keyboardType: TextInputType.number,
              maxLength: 16,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _ubahNik,
              decoration: kkDekor('16 digit', suffix: _tandaCek(_cekNik, _nikTerpakai)),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length != 16) return 'NIK harus 16 digit';
                if (_nikTerpakai == true) return 'NIK telah digunakan';
                return null;
              },
            ),
            if (_nikTerpakai == true)
              _peringatan('NIK telah digunakan. Cari keluarga ini di menu Data Keluarga.'),
            kkJarak(),
            kkLabel('No. HP', wajib: true),
            TextFormField(
              controller: _hp,
              keyboardType: TextInputType.phone,
              maxLength: 15,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _ubahHp,
              decoration: kkDekor('08xxxxxxxxxx', suffix: _tandaCek(_cekHp, _hpTerpakai)),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 10 || t.length > 15) return 'No. HP 10-15 digit';
                if (_hpTerpakai == true) return 'No. HP telah digunakan';
                return null;
              },
            ),
            if (_hpTerpakai == true) _peringatan('No. HP telah digunakan oleh akun lain.'),
            kkJarak(),
            kkLabel('PIN (6 digit)', wajib: true),
            TextFormField(
              controller: _pin,
              obscureText: !_lihatPin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: kkDekor(
                'PIN yang disebutkan orang tua',
                suffix: IconButton(
                  icon: Icon(_lihatPin ? Icons.visibility_off : Icons.visibility,
                      color: kkTeksAbu),
                  onPressed: () => setState(() => _lihatPin = !_lihatPin),
                ),
              ),
              validator: (v) => (v ?? '').length != 6 ? 'PIN harus 6 digit' : null,
            ),
            kkJarak(),
            kkLabel('Ulangi PIN', wajib: true),
            TextFormField(
              controller: _pin2,
              obscureText: !_lihatPin,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: kkDekor('Ketik ulang PIN'),
              validator: (v) => v != _pin.text ? 'PIN tidak sama' : null,
            ),
            const SizedBox(height: 6),
            const Text(
              'PIN diminta langsung dari orang tua. Hindari PIN yang mudah ditebak '
              '(contoh: 123456, 111111, atau tanggal lahir).',
              style: TextStyle(fontSize: 13, color: kkTeksAbu, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langkahKeluarga() {
    return Form(
      key: _keyKeluarga,
      child: FormDataKeluarga(isian: _keluarga, nikIbu: _nik.text.trim()),
    );
  }

  Widget _langkahAnak() {
    return Column(
      children: [
        KartuBagian(
          judul: 'Data Anak',
          sub: 'Tambahkan semua balita dalam keluarga ini.',
          child: Column(
            children: [
              if (_anak.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Belum ada data anak.',
                      style: TextStyle(fontSize: 14.5, color: kkTeksAbu)),
                ),
              for (var i = 0; i < _anak.length; i++)
                BarisAnak(
                  anak: _anak[i],
                  onUbah: () => _ubahAnak(i),
                  onHapus: () => setState(() => _anak.removeAt(i)),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _tambahAnak,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Anak',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kkHijau,
                    side: const BorderSide(color: kkHijau),
                    minimumSize: const Size.fromHeight(48),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        KartuBagian(
          judul: 'Ringkasan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              kkInfo('Nama', _nama.text.trim()),
              kkInfo('NIK', _nik.text.trim()),
              kkInfo('No. HP', _hp.text.trim()),
              kkInfo('Alamat', _keluarga.ringkasAlamat),
              kkInfo('Suami/Ayah',
                  _keluarga.tanpaAyah ? 'Tidak ada' : _keluarga.namaAyah.text.trim()),
              kkInfo('Jumlah anak', '${_anak.length}'),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => setState(() => _setuju = !_setuju),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _setuju,
                      activeColor: kkHijau,
                      onChanged: (v) => setState(() => _setuju = v ?? false),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Data sudah saya periksa bersama orang tua dan sesuai dokumen '
                          '(KTP / KK / buku KIA).',
                          style: TextStyle(fontSize: 14, color: kkTeksGelap, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isi = [_langkahAkun, _langkahKeluarga, _langkahAnak][_langkah]();
    return PopScope(
      canPop: _langkah == 0 && !_menyimpan,
      onPopInvokedWithResult: (sudah, _) {
        if (!sudah && !_menyimpan) _kembali();
      },
      child: Scaffold(
        backgroundColor: kkLatar,
        appBar: kkAppBar('Tambahkan Akun'),
        body: SingleChildScrollView(
          key: ValueKey(_langkah),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              _penandaLangkah(), // 1-2-3 di atas kartu data
              isi,
            ],
          ),
        ),
        bottomNavigationBar: BarAksi(
          labelKiri: _langkah == 0 ? 'Batal' : 'Kembali',
          labelKanan: _langkah == 2 ? 'Simpan' : 'Lanjut',
          memuat: _menyimpan,
          onKiri: _kembali,
          onKanan: _lanjut,
        ),
      ),
    );
  }
}