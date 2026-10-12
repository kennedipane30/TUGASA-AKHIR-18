import 'package:flutter/material.dart';

class PosyanduPilihan {
  final String kode;
  final String nama;
  const PosyanduPilihan(this.kode, this.nama);
}

const daftarPosyandu = [
  PosyanduPilihan('silimbat', 'Silimbat'),
  PosyanduPilihan('sitoluama', 'Sitoluama'),
  PosyanduPilihan('aekbolon', 'Aek Bolon'),
];

String labelPosyandu(String? kode) {
  for (final p in daftarPosyandu) {
    if (p.kode == kode) return p.nama;
  }
  return (kode == null || kode.isEmpty) ? 'Semua Posyandu' : kode;
}

List<DropdownMenuItem<String>> itemPosyandu() => [
      for (final p in daftarPosyandu)
        DropdownMenuItem(value: p.kode, child: Text('Posyandu ${p.nama}')),
    ];