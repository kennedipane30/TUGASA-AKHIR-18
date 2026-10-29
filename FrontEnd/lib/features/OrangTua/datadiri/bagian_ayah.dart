import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keluarga_common.dart';
import 'keluarga_widgets.dart';

class BagianAyah extends StatelessWidget {
  final DataKeluarga data;
  final bool tanpaAyah;
  final ValueChanged<bool?> onTanpaAyah;
  final TextEditingController nama, nik, tgl, hp, kerja;
  final VoidCallback onPilihTanggal;

  const BagianAyah({
    super.key,
    required this.data,
    required this.tanpaAyah,
    required this.onTanpaAyah,
    required this.nama,
    required this.nik,
    required this.tgl,
    required this.hp,
    required this.kerja,
    required this.onPilihTanggal,
  });

  @override
  Widget build(BuildContext context) {
    return KartuKeluarga(
      title: '2. Data Suami / Ayah',
      icon: Icons.man_outlined,
      trailing: pillStatusKeluarga(data.ayahLengkap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          centangKeluarga(
              tanpaAyah, 'Tidak ada data suami / ayah yang diisi', onTanpaAyah),
          if (!tanpaAyah) ...[
            labelKeluarga('Nama lengkap'),
            TextFormField(
              controller: nama,
              textCapitalization: TextCapitalization.words,
              decoration: dekorKeluarga('Nama lengkap', icon: Icons.person_outline),
            ),
            gapKeluarga(),
            labelKeluarga('NIK', ket: '(opsional)'),
            TextFormField(
              controller: nik,
              keyboardType: TextInputType.number,
              maxLength: 16,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: dekorKeluarga('16 digit NIK',
                  icon: Icons.badge_outlined, counter: '${nik.text.length}/16'),
              validator: (v) => (v != null && v.isNotEmpty && v.length != 16)
                  ? 'NIK harus 16 digit'
                  : null,
            ),
            gapKeluarga(),
            labelKeluarga('Tanggal Lahir'),
            TextFormField(
              controller: tgl,
              readOnly: true,
              onTap: onPilihTanggal,
              decoration:
                  dekorKeluarga('dd/mm/yyyy', icon: Icons.calendar_today_outlined),
            ),
            gapKeluarga(),
            labelKeluarga('No. HP', ket: '(opsional)'),
            TextFormField(
              controller: hp,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  dekorKeluarga('No. HP (opsional)', icon: Icons.phone_outlined),
              validator: (v) => (v != null && v.isNotEmpty && v.length < 10)
                  ? 'No. HP tidak valid'
                  : null,
            ),
            gapKeluarga(),
            labelKeluarga('Pekerjaan', ket: '(opsional)'),
            TextFormField(
              controller: kerja,
              textCapitalization: TextCapitalization.words,
              decoration:
                  dekorKeluarga('Pekerjaan (opsional)', icon: Icons.work_outline),
            ),
          ],
        ],
      ),
    );
  }
}