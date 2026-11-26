import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../service/laporan_bulanan_service.dart';
import '../../../service/rekap_service.dart' show namaBulanRekap;
import '../../../core/utils/posyandu.dart';

// ============================================================================
// PDF LAPORAN BULANAN POSYANDU - SEKRETARIS
// Hitam putih, tabel transparan (garis hitam, tanpa warna isi).
// ============================================================================

const _hitam = PdfColors.black;

/// Huruf bawaan PDF hanya mendukung Latin dasar; karakter lain diganti.
String _aman(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x2013 || r == 0x2014 || r == 0x2212) {
      b.write('-');
    } else if (r == 0x2018 || r == 0x2019) {
      b.write("'");
    } else if (r == 0x201C || r == 0x201D) {
      b.write('"');
    } else if (r == 0x2265) {
      b.write('>=');
    } else if (r == 0x2264) {
      b.write('<=');
    } else if (r >= 0x20 && r <= 0x7E) {
      b.writeCharCode(r);
    } else if (r == 0x0A) {
      b.write(' ');
    } else {
      b.write('?');
    }
  }
  return b.toString();
}

String _persen(double v) {
  final t = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '${t.replaceAll('.', ',')}%';
}

String _tanggal(DateTime d) => '${d.day} ${namaBulanRekap[d.month]} ${d.year}';

String _tanggalPendek(DateTime d) => '${d.day} ${namaBulanRekap[d.month]}';

String _saranTindakLanjut(List<String> masalah) {
  final m = masalah.join(' ').toLowerCase();
  if (m.contains('buruk') || m.contains('sangat') || m.contains('bgm') || m.contains('obesitas')) {
    return 'Konsultasi ke Puskesmas';
  }
  if (m.contains('2t') || m.contains('kurang')) return 'Konseling gizi, pantau bulan depan';
  if (m.contains('pendek')) return 'Pantau tinggi badan, konseling gizi';
  if (m.contains('lebih')) return 'Konseling pola makan';
  return 'Pantau bulan depan';
}

pw.Widget _teks(String s, {bool tebal = false, double ukuran = 9, pw.TextAlign rata = pw.TextAlign.left}) =>
    pw.Text(
      _aman(s),
      textAlign: rata,
      style: pw.TextStyle(
        fontSize: ukuran,
        fontWeight: tebal ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: _hitam,
      ),
    );

/// Tabel garis hitam tanpa warna isi. Baris pertama = kepala (tebal) bila [kepala] true.
pw.Widget _tabel(
  List<List<String>> data,
  List<double> lebarMm, {
  bool kepala = true,
  Set<int> tengah = const {},
  Set<int> barisTebal = const {},
}) {
  final lebar = <int, pw.TableColumnWidth>{
    for (var i = 0; i < lebarMm.length; i++) i: pw.FixedColumnWidth(lebarMm[i] * PdfPageFormat.mm),
  };
  return pw.Table(
    border: pw.TableBorder.all(color: _hitam, width: 0.6),
    columnWidths: lebar,
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      for (var r = 0; r < data.length; r++)
        pw.TableRow(
          repeat: kepala && r == 0,
          children: [
            for (var c = 0; c < data[r].length; c++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                child: _teks(
                  data[r][c],
                  tebal: (kepala && r == 0) || barisTebal.contains(r),
                  rata: tengah.contains(c) ? pw.TextAlign.center : pw.TextAlign.left,
                ),
              ),
          ],
        ),
    ],
  );
}

/// Tabel info tanpa kepala (Nama Posyandu, Periode, ...).
pw.Widget _tabelInfo(List<List<String>> data, List<double> lebarMm) =>
    _tabel(data, lebarMm, kepala: false);

pw.Widget _bagian(String nomor, String judul) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
      child: _teks('$nomor. $judul', tebal: true, ukuran: 11),
    );

pw.Widget _catatan(String s) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Text(
        _aman(s),
        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: _hitam),
      ),
    );

const _peran = 'Sekretaris';

/// Membuat PDF laporan bulanan sekretaris. [namaPencetak] nama akun yang mencetak.
Future<Uint8List> buatPdfLaporanBulananSekretaris({
  required LaporanBulanan data,
  required String namaPencetak,
}) async {
  final doc = pw.Document(
    title: 'Laporan Bulanan Posyandu ${labelPosyandu(data.posyandu)} ${data.label}',
    author: 'PosyanduCare',
    creator: 'PosyanduCare',
  );

  final namaPos = labelPosyandu(data.posyandu);
  final cetak = DateTime.now();
  final awal = DateTime.tryParse('${data.bulan}-01') ?? DateTime(cetak.year, cetak.month);
  final akhir = DateTime(awal.year, awal.month + 1, 0);
  final periode = '1 - ${akhir.day} ${namaBulanRekap[awal.month]} ${awal.year}';
  final k = data.kegiatan;
  final sesi = k.jumlahSesi == 0
      ? 'Tidak ada sesi'
      : '${k.jumlahSesi} sesi (${k.tanggalSesi.map(_tanggalPendek).join(', ')})';

  final isi = <pw.Widget>[
    pw.Center(child: _teks('LAPORAN BULANAN POSYANDU', tebal: true, ukuran: 15)),
    pw.SizedBox(height: 3),
    pw.Center(child: _teks('Posyandu $namaPos  |  Bulan ${data.label}', ukuran: 10)),
    pw.SizedBox(height: 6),
    pw.Container(height: 1.6, color: _hitam),
    pw.SizedBox(height: 8),
    _tabelInfo([
      ['Nama Posyandu', ': $namaPos', 'Periode', ': $periode'],
      ['Desa', ': $namaPos', 'Dicetak oleh', ': $_peran${namaPencetak.isEmpty ? '' : ' ($namaPencetak)'}'],
      ['Jumlah sesi', ': $sesi', 'Tanggal cetak', ': ${_tanggal(cetak)}'],
    ], [30, 57, 28, 59]),

    // I. Kegiatan
    _bagian('I', 'Kegiatan dan Kehadiran'),
    _tabel([
      ['Uraian', 'Jumlah'],
      ['Balita sasaran (0-59 bulan)', '${k.sasaran}'],
      ['Balita didaftarkan ke sesi', '${k.didaftarkan}'],
      ['Balita hadir (check-in)', '${k.hadir}'],
      ['Balita tidak hadir', '${k.tidakHadir}'],
      ['Persentase kehadiran', _persen(k.persenHadir)],
    ], [130, 44], tengah: {1}),

    // II. SKDN
    _bagian('II', 'Penimbangan (SKDN)'),
    _tabel([
      ['Kode', 'Keterangan', 'Jumlah', 'Capaian'],
      ['S', 'Seluruh balita di wilayah posyandu', '${data.skdn.s}', '-'],
      ['K', 'Balita yang memiliki Buku KIA / terdaftar', '${data.skdn.k}', 'K/S = ${_persen(data.skdn.persenKS)}'],
      ['D', 'Balita yang ditimbang bulan ini', '${data.skdn.d}', 'D/S = ${_persen(data.skdn.persenDS)}'],
      ['N', 'Balita yang berat badannya naik', '${data.skdn.n}', 'N/D = ${_persen(data.skdn.persenND)}'],
    ], [16, 98, 25, 35], tengah: {0, 2, 3}),

    // III. Status gizi
    _bagian('III', 'Status Gizi Balita yang Ditimbang'),
    _tabel([
      ['Kategori', 'Indeks', 'Jumlah', 'Persen'],
      ['Balita diukur bulan ini', '-', '${data.gizi.diukur}', '-'],
      for (final g in data.gizi.kategori) [g.label, g.indeks, '${g.jumlah}', _persen(g.persen)],
      ['2T (dua kali tidak naik)', 'Penimbangan', '${data.skdn.duaT}', '-'],
      ['BGM (bawah garis merah)', 'Penimbangan', '${data.skdn.bgm}', '-'],
    ], [62, 56, 26, 30], tengah: {2, 3}),
    _catatan('Satu balita dapat masuk lebih dari satu kategori. Persen dihitung dari balita yang diukur.'),

    // IV. Imunisasi
    _bagian('IV', 'Imunisasi yang Diberikan'),
    if (data.imunisasi.isEmpty)
      _tabel([
        ['Jenis imunisasi', 'Jumlah balita'],
        ['Tidak ada imunisasi di posyandu bulan ini', '0'],
      ], [130, 44], tengah: {1})
    else
      _tabel([
        ['Jenis imunisasi', 'Jumlah balita'],
        for (final v in data.imunisasi) [v.nama, '${v.jumlah}'],
        ['Total pemberian', '${data.totalImunisasi}'],
      ], [130, 44], tengah: {1}, barisTebal: {data.imunisasi.length + 1}),

    // V. Suplemen
    _bagian('V', 'Pemberian Suplemen'),
    if (data.suplemen.isEmpty)
      _tabel([
        ['Suplemen', 'Jumlah balita'],
        ['Tidak ada pemberian suplemen bulan ini', '0'],
      ], [130, 44], tengah: {1})
    else
      _tabel([
        ['Suplemen', 'Jumlah balita'],
        for (final s in data.suplemen) [s.nama, '${s.jumlah}'],
      ], [130, 44], tengah: {1}),
    _catatan('Vitamin A dosis tinggi dan obat cacing umumnya diberikan pada bulan Februari dan Agustus.'),

    // VI. Balita berisiko
    _bagian('VI', 'Daftar Balita Berisiko'),
    if (data.balitaBerisiko.isEmpty)
      _tabel([
        ['Keterangan'],
        ['Tidak ada balita berisiko pada bulan ini'],
      ], [174])
    else
      _tabel([
        ['No', 'Nama balita', 'L/P', 'Umur', 'Masalah', 'Saran tindak lanjut'],
        for (var i = 0; i < data.balitaBerisiko.length; i++)
          [
            '${i + 1}',
            data.balitaBerisiko[i].nama,
            data.balitaBerisiko[i].jk,
            data.balitaBerisiko[i].usiaTeks,
            data.balitaBerisiko[i].masalah.join(', '),
            _saranTindakLanjut(data.balitaBerisiko[i].masalah),
          ],
      ], [9, 36, 10, 22, 47, 50], tengah: {0, 2}),

    // Tanda tangan
    pw.SizedBox(height: 18),
    _tandaTangan(namaPos, cetak, namaPencetak),
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 18 * PdfPageFormat.mm,
        marginRight: 18 * PdfPageFormat.mm,
        marginTop: 16 * PdfPageFormat.mm,
        marginBottom: 18 * PdfPageFormat.mm,
      ),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Dicetak dari aplikasi PosyanduCare',
                style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: _hitam)),
            pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic, color: _hitam)),
          ],
        ),
      ),
      build: (_) => isi,
    ),
  );
  return doc.save();
}

pw.Widget _tandaTangan(String namaPos, DateTime cetak, String namaPencetak) {
  String nama(bool milikSaya) =>
      milikSaya && namaPencetak.isNotEmpty ? '( $namaPencetak )' : '(______________________)';
  const bidan = false;

  pw.Widget kolom(String a, String b, String n) => pw.SizedBox(
        width: 70 * PdfPageFormat.mm,
        child: pw.Column(
          children: [
            _teks(a, ukuran: 9.5, rata: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            _teks(b, ukuran: 9.5, rata: pw.TextAlign.center),
            pw.SizedBox(height: 46),
            _teks(n, ukuran: 9.5, rata: pw.TextAlign.center),
          ],
        ),
      );

  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      kolom('Mengetahui,', 'Bidan Desa', nama(bidan)),
      kolom('$namaPos, ${_tanggal(cetak)}', 'Sekretaris Posyandu', nama(!bidan)),
    ],
  );
}