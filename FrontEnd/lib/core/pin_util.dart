/// Aturan PIN 6 digit (sama dengan di backend).
/// Mengembalikan pesan kesalahan, atau null jika PIN valid.
String? validasiPin(String pin) {
  if (!RegExp(r'^\d{6}$').hasMatch(pin)) return 'PIN harus 6 digit angka';
  const mudah = 'PIN terlalu mudah ditebak, hindari angka kembar, berurutan, atau berulang';

  final d = pin.codeUnits;
  var sama = true, naik = true, turun = true;
  for (var i = 1; i < 6; i++) {
    if (d[i] != d[i - 1]) sama = false;
    if (d[i] != d[i - 1] + 1) naik = false;
    if (d[i] != d[i - 1] - 1) turun = false;
  }
  if (sama || naik || turun) return mudah;

  if (pin.substring(0, 3) == pin.substring(3) ||
      (pin.substring(0, 2) == pin.substring(2, 4) && pin.substring(2, 4) == pin.substring(4))) {
    return mudah;
  }
  const umum = {'112233', '123321', '159753', '147258', '258369', '102030', '696969', '121314'};
  if (umum.contains(pin)) return mudah;
  return null;
}