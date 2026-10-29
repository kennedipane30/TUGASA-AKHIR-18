import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import 'keluarga_common.dart';

const kGarisKartu = Color(0xFFE6ECE8);
const kGarisInput = Color(0xFFD7E6DD);

InputDecoration dekorKeluarga(String hint,
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
    border: b(kGarisInput),
    enabledBorder: b(terkunci ? Colors.transparent : kGarisInput),
    focusedBorder: b(kHijauTua),
    errorBorder: b(AppColors.merah),
    focusedErrorBorder: b(AppColors.merah),
  );
}

Widget labelKeluarga(String teks, {String? ket}) => Padding(
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

Widget gapKeluarga() => const SizedBox(height: 14);

Widget centangKeluarga(bool nilai, String teks, ValueChanged<bool?> onChanged) =>
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: kHijauGelap,
      value: nilai,
      title: Text(teks, style: const TextStyle(fontSize: 13)),
      onChanged: onChanged,
    );

Widget pillStatusKeluarga(bool lengkap) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: lengkap ? AppColors.hijauMuda : AppColors.kuningMuda,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(lengkap ? 'Lengkap' : 'Belum lengkap',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: lengkap ? kHijauTua : AppColors.kuning)),
    );

class KartuKeluarga extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;
  final Widget child;

  const KartuKeluarga({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGarisKartu),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
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
                      color: const Color(0xFFD7F0E3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: kHijauGelap),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: kHijauTua)),
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

class StepperKeluarga extends StatelessWidget {
  final DataKeluarga data;
  const StepperKeluarga({super.key, required this.data});

  Widget _bulat(String no, bool selesai) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
              color: selesai ? kHijauGelap : Colors.grey.shade400, width: 1.6),
        ),
        child: selesai
            ? const Icon(Icons.check, size: 18, color: kHijauGelap)
            : Text(no,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: no == '1' ? kHijauGelap : Colors.grey)),
      );

  @override
  Widget build(BuildContext context) {
    final d = data;
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
            color: kHijauGelap,
          ),
        ),
        const SizedBox(height: 8),
        Text('${d.langkahSelesai} dari 2 bagian lengkap. Data boleh disimpan bertahap.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.teksRedup)),
      ],
    );
  }
}