import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keluarga_common.dart';
import 'keluarga_widgets.dart';

class BagianIbu extends StatelessWidget {
  final DataKeluarga data;
  final bool tanpaIbu;
  final ValueChanged<bool?> onTanpaIbu;
  final TextEditingController nama, nik, tgl, hp, kerja, alamat, rt, rw;
  final VoidCallback onPilihTanggal;

  const BagianIbu({
    super.key,
    required this.data,
    required this.tanpaIbu,
    required this.onTanpaIbu,
    required this.nama,
    required this.nik,
    required this.tgl,
    required this.hp,
    required this.kerja,
    required this.alamat,
    required this.rt,
    required this.rw,
    required this.onPilihTanggal,
  });

  @override
  Widget build(BuildContext context) {
    return KartuKeluarga(
      title: '1. Data Diri Ibu / Wali',
      icon: Icons.person_outline,
      trailing: pillStatusKeluarga(data.ibuLengkap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          centangKeluarga(tanpaIbu, 'Tidak ada data ibu', onTanpaIbu),
          if (!tanpaIbu) ...[
            labelKeluarga('Nama lengkap', ket: '(dari akun)'),
            TextFormField(
              controller: nama,
              readOnly: true,
              decoration:
                  dekorKeluarga('Nama', icon: Icons.person_outline, terkunci: true),
            ),
            gapKeluarga(),
            labelKeluarga('NIK', ket: '(dari akun)'),
            TextFormField(
              controller: nik,
              readOnly: true,
              decoration:
                  dekorKeluarga('NIK', icon: Icons.badge_outlined, terkunci: true),
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
            labelKeluarga('No. WhatsApp', ket: '(dari akun)'),
            TextFormField(
              controller: hp,
              readOnly: true,
              decoration: dekorKeluarga('No. WhatsApp',
                  icon: Icons.phone_outlined, terkunci: true),
            ),
            gapKeluarga(),
            labelKeluarga('Pekerjaan', ket: '(opsional)'),
            TextFormField(
              controller: kerja,
              textCapitalization: TextCapitalization.words,
              decoration:
                  dekorKeluarga('Pekerjaan (opsional)', icon: Icons.work_outline),
            ),
            gapKeluarga(),
          ],
          labelKeluarga('Alamat Tempat Tinggal'),
          TextFormField(
            controller: alamat,
            maxLines: 3,
            decoration: dekorKeluarga('Alamat tempat tinggal lengkap...',
                icon: Icons.home_outlined),
          ),
          gapKeluarga(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelKeluarga('RT'),
                    TextFormField(
                      controller: rt,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 3,
                      decoration: dekorKeluarga('RT'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelKeluarga('RW'),
                    TextFormField(
                      controller: rw,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 3,
                      decoration: dekorKeluarga('RW'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}