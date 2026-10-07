import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Papan angka PIN: 6 titik indikator dan tombol 0-9 serta hapus.
class PinPad extends StatelessWidget {
  final String pin;
  final int panjang;
  final bool aktif;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSelesai;

  const PinPad({
    super.key,
    required this.pin,
    required this.onChanged,
    this.panjang = 6,
    this.aktif = true,
    this.onSelesai,
  });

  void _tekan(String digit) {
    if (!aktif || pin.length >= panjang) return;
    final baru = pin + digit;
    onChanged(baru);
    if (baru.length == panjang) onSelesai?.call();
  }

  void _hapus() {
    if (!aktif || pin.isEmpty) return;
    onChanged(pin.substring(0, pin.length - 1));
  }

  Widget _tombol(Widget isi, VoidCallback? onTap) {
    return SizedBox(
      width: 72,
      height: 56,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: onTap == null ? Colors.transparent : AppColors.isiField,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: aktif ? onTap : null,
        child: isi,
      ),
    );
  }

  Widget _angka(String d) => _tombol(
        Text(d, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        () => _tekan(d),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < panjang; i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < pin.length ? AppColors.hijau : Colors.transparent,
                  border: Border.all(
                    color: i < pin.length ? AppColors.hijau : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        for (final baris in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in baris)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _angka(d)),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: SizedBox(width: 72, height: 56)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _angka('0')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _tombol(const Icon(Icons.backspace_outlined), _hapus),
            ),
          ],
        ),
      ],
    );
  }
}