// lib/features/auth/otp_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'otp_service.dart';

const _hijau = Color(0xFF0B6B4D);
const _hijauGelap = Color(0xFF062B20);
const _hijauTerang = Color(0xFF7FE3C0);
const _teal = Color(0xFF2BB59A);
const _oranye = Color(0xFFFF7A1A);
const _oranyeGelap = Color(0xFFE8590C);
const _oranyeTerang = Color(0xFFFFA31A);
const _isiField = Color(0xFFF3FBF8);

/// Halaman memasukkan kode OTP 6 digit dari WhatsApp.
///
/// Kode sudah dikirim SEBELUM halaman ini dibuka (oleh halaman registrasi /
/// lupa PIN), supaya kesalahan seperti "nomor sudah terdaftar" tampil di form.
///
/// Bila kode cocok, halaman ditutup dan mengembalikan token_otp:
///   final token = await Navigator.push<String>(context,
///       MaterialPageRoute(builder: (_) => OtpPage(noHp: hp, tujuan: TujuanOtp.registrasi, info: info)));
///   if (token != null) { ... lanjut registrasi / reset PIN ... }
class OtpPage extends StatefulWidget {
  final String noHp;
  final String tujuan; // TujuanOtp.registrasi | TujuanOtp.resetPin
  final InfoKirimOtp info; // hasil OtpService.kirim()

  const OtpPage({
    super.key,
    required this.noHp,
    required this.tujuan,
    required this.info,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _svc = OtpService();
  final _kode = TextEditingController();
  final _fokus = FocusNode();

  late InfoKirimOtp _info;
  Timer? _timer;
  int _sisaKirimUlang = 0; // detik sebelum tombol "Kirim ulang" aktif
  int _sisaBerlaku = 0; // detik sebelum kode kedaluwarsa
  bool _memeriksa = false;
  bool _mengirim = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _info = widget.info;
    _mulaiHitungMundur();
    _fokus.addListener(() {
      if (mounted) setState(() {}); // perbarui kotak yang sedang aktif
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fokus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _kode.dispose();
    _fokus.dispose();
    super.dispose();
  }

  void _mulaiHitungMundur() {
    _timer?.cancel();
    _sisaKirimUlang = _info.kirimUlangDetik;
    _sisaBerlaku = _info.berlakuDetik;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_sisaKirimUlang > 0) _sisaKirimUlang--;
        if (_sisaBerlaku > 0) _sisaBerlaku--;
      });
    });
  }

  String get _judulTujuan => widget.tujuan == TujuanOtp.resetPin
      ? 'Atur Ulang PIN'
      : 'Verifikasi Pendaftaran';

  String _formatWaktu(int detik) {
    final m = (detik ~/ 60).toString().padLeft(2, '0');
    final s = (detik % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _periksa() async {
    final kode = _kode.text.trim();
    if (kode.length != 6) {
      setState(() => _error = 'Masukkan 6 digit kode dari WhatsApp');
      return;
    }
    if (_sisaBerlaku == 0) {
      setState(() => _error = 'Kode sudah tidak berlaku, silakan kirim ulang kode');
      return;
    }
    setState(() {
      _memeriksa = true;
      _error = null;
    });
    try {
      final token = await _svc.verifikasi(widget.noHp, widget.tujuan, kode);
      if (!mounted) return;
      Navigator.pop(context, token);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _kode.clear();
      });
      _fokus.requestFocus();
    } finally {
      if (mounted) setState(() => _memeriksa = false);
    }
  }

  Future<void> _kirimUlang() async {
    setState(() {
      _mengirim = true;
      _error = null;
    });
    try {
      final info = await _svc.kirim(widget.noHp, widget.tujuan);
      if (!mounted) return;
      setState(() {
        _info = info;
        _kode.clear();
      });
      _mulaiHitungMundur();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode baru sudah dikirim ke WhatsApp Anda')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  // 6 kotak angka. Input sebenarnya dari satu TextField tak terlihat di atasnya,
  // sehingga tempel (paste) kode dan hapus (backspace) tetap berjalan normal.
  Widget _kotakKode() {
    final teks = _kode.text;
    return GestureDetector(
      onTap: () => _fokus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final terisi = i < teks.length;
              final aktif = i == teks.length && _fokus.hasFocus;
              return Container(
                width: 46,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isiField,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _error != null
                        ? Colors.red.shade300
                        : (aktif ? _teal : _teal.withValues(alpha: 0.45)),
                    width: aktif ? 2 : 1.4,
                  ),
                ),
                child: Text(
                  terisi ? teks[i] : '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _kode,
                focusNode: _fokus,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                decoration: const InputDecoration(counterText: ''),
                onChanged: (v) {
                  setState(() => _error = null);
                  if (v.length == 6 && !_memeriksa) _periksa();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tombolPeriksa() {
    return Opacity(
      opacity: _memeriksa ? 0.7 : 1,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_oranyeGelap, _oranye, _oranyeTerang],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _oranye.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _memeriksa ? null : _periksa,
            child: Center(
              child: _memeriksa
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Verifikasi Kode',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kartu() {
    final bisaKirimUlang = _sisaKirimUlang == 0 && !_mengirim;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Text(
            _judulTujuan,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _oranye]),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.45,
              ),
              children: [
                const TextSpan(text: 'Kode 6 digit sudah dikirim lewat WhatsApp ke nomor '),
                TextSpan(
                  text: _info.noHpSamaran,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          if (_info.modeUji) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE0A8)),
              ),
              child: const Text(
                'Mode uji: server belum terhubung ke WhatsApp. Lihat kode di terminal backend.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _kotakKode(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade600, fontSize: 15),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            _sisaBerlaku > 0
                ? 'Kode berlaku ${_formatWaktu(_sisaBerlaku)}'
                : 'Kode sudah tidak berlaku',
            style: TextStyle(
              fontSize: 15,
              color: _sisaBerlaku > 0 ? Colors.black54 : Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 22),
          _tombolPeriksa(),
          const SizedBox(height: 18),
          const Text(
            'Belum menerima kode?',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          TextButton(
            onPressed: bisaKirimUlang ? _kirimUlang : null,
            child: _mengirim
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    bisaKirimUlang
                        ? 'Kirim ulang kode'
                        : 'Kirim ulang dalam ${_formatWaktu(_sisaKirimUlang)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: bisaKirimUlang ? _oranye : Colors.black38,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Jangan berikan kode ini kepada siapa pun, termasuk petugas posyandu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _hijau,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_hijauGelap, _hijau],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Icon(Icons.mark_chat_read_outlined,
                        color: Colors.white, size: 72),
                    const SizedBox(height: 10),
                    const Text(
                      'Cek WhatsApp Anda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Masukkan kode untuk memastikan nomor ini milik Anda',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _hijauTerang, fontSize: 16.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(child: _kartu()),
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