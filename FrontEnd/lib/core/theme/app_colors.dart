import 'package:flutter/material.dart';

/// Warna tema aplikasi Posyandu Sehat. Dipakai oleh semua halaman home.
class AppColors {
  static const hijau = Color(0xFF0B6B4D);
  static const hijauMuda = Color(0xFFE3F4EC);
  static const latar = Color(0xFFFFFFFF);
  static const isiField = Color(0xFFEDEBF7);

  static const kuning = Color(0xFFB77900);
  static const kuningMuda = Color(0xFFFFF1CC);

  static const merah = Color(0xFFC62828);
  static const merahMuda = Color(0xFFFDE8E8);

  static const biru = Color(0xFF2F5BEA);
  static const biruMuda = Color(0xFFE6EDFF);

  static const teksRedup = Color(0xFF6B6B7B);

  // ---------------------------------------------------------------------
  // Token kartu: dipakai halaman grafik dan halaman lain agar seragam
  // ---------------------------------------------------------------------

  /// Teks utama pada kartu.
  static const teksGelap = Color(0xFF1F2937);

  /// Teks keterangan, lebih redup daripada [teksGelap].
  static const teksAbu = Color(0xFF64748B);

  /// Hijau tua untuk judul dan ikon di atas latar terang.
  static const hijauTua = Color(0xFF065F46);

  /// Hijau lembut sebagai garis aksen kartu.
  static const aksen = Color(0xFF5E9C84);

  /// Garis tepi kotak di dalam kartu.
  static const garis = Color(0xFFB8BEC6);

  /// Bayangan kartu: satu lapis tipis menegaskan garis tepi di semua sisi,
  /// satu lapis lebih gelap memberi kedalaman di bawahnya. Latar putih bersih
  /// membuat kedua lapis ini terlihat jelas.
  static const bayanganKartu = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 3, offset: Offset(0, 0)),
    BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}