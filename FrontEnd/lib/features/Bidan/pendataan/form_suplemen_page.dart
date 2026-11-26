part of 'catat_pemeriksaan_page.dart';

// ===========================================================================
// FORM SUPLEMEN
// Model baris suplemen, daftar aturan pakai dan satuan, serta tampilan
// kartu "Suplemen Hari Ini" beserta baris isiannya.
// ===========================================================================

/// Satu baris suplemen. [tetap] = Vitamin A / obat cacing: nama, dosis, dan jumlah (1) tidak diubah.
class _BarisSuplemen {
  final TextEditingController nama;
  final TextEditingController dosis;
  final TextEditingController catatan;

  /// Isian aturan pakai bila bidan memilih "Lainnya".
  final TextEditingController aturanLain;
  int jumlah;
  String satuan;

  /// Pilihan aturan pakai: salah satu [_aturanPakai] atau [_aturanLainnya].
  String aturan;
  final bool tetap;

  _BarisSuplemen({
    String nama = '',
    String dosis = '',
    String catatan = '',
    String aturanPakai = '',
    this.jumlah = 1,
    this.satuan = 'kapsul',
    this.tetap = false,
  })  : nama = TextEditingController(text: nama),
        dosis = TextEditingController(text: dosis),
        catatan = TextEditingController(text: catatan),
        aturan = _aturanPakai.contains(aturanPakai)
            ? aturanPakai
            : (aturanPakai.trim().isEmpty ? (tetap ? 'Dosis tunggal' : '1 x 1 sehari') : _aturanLainnya),
        aturanLain = TextEditingController(
            text: _aturanPakai.contains(aturanPakai) ? '' : aturanPakai.trim());

  /// Aturan pakai yang dikirim ke server.
  String get aturanPakai => aturan == _aturanLainnya ? aturanLain.text.trim() : aturan;

  /// Baris yang belum diisi sama sekali (form suplemen yang dibiarkan kosong).
  bool get kosong =>
      !tetap && nama.text.trim().isEmpty && dosis.text.trim().isEmpty && catatan.text.trim().isEmpty;

  void dispose() {
    nama.dispose();
    dosis.dispose();
    catatan.dispose();
    aturanLain.dispose();
  }
}

/// Pilihan aturan pakai suplemen. Selain ini, bidan memilih "Lainnya" dan mengisi sendiri.
const _aturanPakai = <String>[
  '1 x 1 sehari',
  '2 x 1 sehari',
  '3 x 1 sehari',
  'Dosis tunggal',
];
const _aturanLainnya = 'Lainnya';

const _satuanSuplemen = <String>[
  'kapsul',
  'tablet',
  'sachet',
  'bungkus',
  'porsi',
  'botol',
  'ml',
  'tetes',
];

_BarisSuplemen _vitaminA(int usia) => usia >= 12
    ? _BarisSuplemen(nama: 'Vitamin A (kapsul merah)', dosis: '200.000 IU', satuan: 'kapsul', tetap: true)
    : _BarisSuplemen(nama: 'Vitamin A (kapsul biru)', dosis: '100.000 IU', satuan: 'kapsul', tetap: true);

_BarisSuplemen _obatCacing(int usia) => _BarisSuplemen(
      nama: 'Obat Cacing (Albendazol)',
      dosis: usia < 24 ? '200 mg' : '400 mg',
      satuan: 'tablet',
      tetap: true,
    );

/// Imunisasi yang dipilih hari ini. Nomor batch dan reaksi tidak diisi lagi di sini:
/// reaksi setelah imunisasi dilaporkan orang tua (tampil di kunjungan berikutnya).

// ---------------------------------------------------------------------------
// TAMPILAN BAGIAN SUPLEMEN
// ---------------------------------------------------------------------------
mixin _FormSuplemen<T extends StatefulWidget> on _FormPemeriksaan<T> {
  // -------------------------------------------------------------------------
  // SUPLEMEN HARI INI
  // -------------------------------------------------------------------------
  /// Form suplemen langsung tampil (tanpa pilihan cepat): suplemen berbeda untuk
  /// setiap anak sesuai kondisi kesehatannya, jadi nama, dosis, dan aturan pakai
  /// diisi bidan. Baris yang dibiarkan kosong tidak disimpan.
  Widget _kartuSuplemen() {
    final terisi = _suplemenTerisi.length;
    return kartuBidan(
      judul: 'Suplemen Hari Ini',
      kanan: terisi == 0 ? null : '$terisi item',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _suplemen.length; i++) _barisSuplemen(i),
          tombolGarisBidan(
            'Tambah Suplemen',
            ikon: Icons.add,
            onPressed: () => setState(() => _suplemen.add(_BarisSuplemen())),
          ),
        ],
      ),
    );
  }

  Widget _barisSuplemen(int i) {
    final s = _suplemen[i];
    final satuan = {..._satuanSuplemen, s.satuan}.toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: garisKartuBidan, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.tetap ? s.nama.text : 'Suplemen ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _teksGelap),
                ),
              ),
              if (!(_suplemen.length == 1 && s.kosong))
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Hapus',
                  onPressed: () => _hapusSuplemen(i),
                  icon: const Icon(Icons.delete_outline, color: AppColors.merah),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: s.tetap
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      barisInfoBidan('Dosis', '${s.dosis.text} · 1 ${s.satuan}', lebar: 70),
                      const SizedBox(height: 4),
                      _aturanSuplemen(s),
                      const SizedBox(height: 8),
                      TextField(
                        controller: s.catatan,
                        style: const TextStyle(fontSize: 17),
                        decoration: _dekor('Catatan (opsional)', ikon: Icons.notes_outlined),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      TextField(
                        controller: s.nama,
                        style: const TextStyle(fontSize: 17.5),
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 100,
                        decoration: _dekor('Nama suplemen', ikon: Icons.medication_outlined).copyWith(counterText: ''),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: s.dosis,
                        style: const TextStyle(fontSize: 17.5),
                        maxLength: 60,
                        decoration: _dekor('Dosis (mis. 400 mg)', ikon: Icons.scale_outlined).copyWith(counterText: ''),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: garisKartuBidan, width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: s.jumlah > 1 ? () => setState(() => s.jumlah--) : null,
                                  icon: const Icon(Icons.remove),
                                ),
                                SizedBox(
                                  width: 38,
                                  child: Text('${s.jumlah}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: s.jumlah < 999 ? () => setState(() => s.jumlah++) : null,
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: s.satuan,
                              isExpanded: true,
                              style: const TextStyle(fontSize: 17.5, color: Colors.black87),
                              decoration: _dekor('Satuan', ikon: Icons.inventory_2_outlined),
                              items: [for (final x in satuan) DropdownMenuItem(value: x, child: Text(x))],
                              onChanged: (v) => setState(() => s.satuan = v ?? s.satuan),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _aturanSuplemen(s),
                      const SizedBox(height: 8),
                      TextField(
                        controller: s.catatan,
                        style: const TextStyle(fontSize: 17.5),
                        decoration: _dekor('Catatan (opsional)', ikon: Icons.notes_outlined),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Aturan pakai suplemen: pilihan cepat (1 x 1, 2 x 1, 3 x 1, dosis tunggal)
  /// atau "Lainnya" yang diisi sendiri oleh bidan.
  Widget _aturanSuplemen(_BarisSuplemen s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: s.aturan,
          isExpanded: true,
          style: const TextStyle(fontSize: 17.5, color: Colors.black87),
          decoration: _dekor('Aturan pakai', ikon: Icons.schedule_outlined),
          items: [
            for (final x in [..._aturanPakai, _aturanLainnya])
              DropdownMenuItem(value: x, child: Text(x == _aturanLainnya ? 'Lainnya (isi sendiri)' : x)),
          ],
          onChanged: (v) => setState(() => s.aturan = v ?? s.aturan),
        ),
        if (s.aturan == _aturanLainnya) ...[
          const SizedBox(height: 8),
          TextField(
            controller: s.aturanLain,
            style: const TextStyle(fontSize: 17.5),
            maxLength: 60,
            decoration: _dekor('Mis. 1 x ½ sehari sesudah makan', ikon: Icons.edit_note_outlined)
                .copyWith(counterText: ''),
          ),
        ],
      ],
    );
  }
}