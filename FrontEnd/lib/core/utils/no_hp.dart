import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// NOMOR HP (Indonesia) - sama dengan backend utils/no_hp.go
//
//  - Disimpan di server dalam format +62 (E.164), contoh: +6281234567890.
//  - No. HP adalah identitas login semua role (bersama PIN 6 digit).
//  - Di setiap kolom isian, "+62" tampil TETAP di depan; pengguna hanya
//    mengetik lanjutannya (diawali 8, 9-12 digit), contoh: 81234567890.
//  - Di tampilan: +62 812-3456-7890.
// ============================================================================

const contohNoHp = '81234567890';
const ketNoHp = '+62 lalu 9-12 digit';
const maksNoHp = 12;

/// Awalan "+62" tetap di depan kolom No. HP (tidak bisa dihapus).
class AwalanNoHp extends StatelessWidget {
  const AwalanNoHp({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 8),
      padding: const EdgeInsets.only(right: 10),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.black26, width: 1.2)),
      ),
      child: const Text(
        '+62',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
      ),
    );
  }
}

/// Pasang awalan +62 pada dekorasi kolom yang sudah ada.
InputDecoration denganAwalanNoHp(InputDecoration d) => d.copyWith(
      prefixIcon: const AwalanNoHp(),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    );

/// Formatter isian setelah +62: hanya angka; "0" atau "62" di depan dibuang
/// (mis. menempel 0812... / 62812...); maksimal 12 digit.
final inputNoHp = <TextInputFormatter>[_FormatNoHp()];

class _FormatNoHp extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue lama, TextEditingValue baru) {
    var t = baru.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.startsWith('62')) t = t.substring(2);
    while (t.startsWith('0')) {
      t = t.substring(1);
    }
    if (t.length > maksNoHp) t = t.substring(0, maksNoHp);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Validasi isian setelah +62 (wajib). null = valid.
String? validasiNoHp(String? v, {String label = 'No. HP'}) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return '$label wajib diisi';
  if (!t.startsWith('8')) return '$label setelah +62 harus diawali angka 8';
  if (!RegExp(r'^8\d{8,11}$').hasMatch(t)) return '$label harus 9-12 digit setelah +62';
  return null;
}

/// Validasi isian setelah +62 (opsional, boleh kosong). null = valid.
String? validasiNoHpOpsional(String? v, {String label = 'No. HP'}) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  return validasiNoHp(t, label: label);
}

/// Isian kolom (812...) -> format server (+62812...). Kosong tetap kosong.
String noHpKeServer(String isian) {
  final t = isian.replaceAll(RegExp(r'[^0-9]'), '');
  return t.isEmpty ? '' : '+62$t';
}

/// Nomor dari server (+62812... / 62812... / 0812...) -> isian kolom (812...).
String noHpKeIsian(String dariServer) {
  var t = dariServer.replaceAll(RegExp(r'[^0-9]'), '');
  if (t.startsWith('62')) {
    t = t.substring(2);
  } else if (t.startsWith('0')) {
    t = t.substring(1);
  }
  return t;
}

/// Tampilan No. HP: +6281234567890 -> "+62 812-3456-7890". Kosong -> "-".
String formatNoHp(String dariServer) {
  final t = noHpKeIsian(dariServer);
  if (t.isEmpty) return '-';
  if (t.length <= 3) return '+62 $t';
  if (t.length <= 7) return '+62 ${t.substring(0, 3)}-${t.substring(3)}';
  return '+62 ${t.substring(0, 3)}-${t.substring(3, 7)}-${t.substring(7)}';
}