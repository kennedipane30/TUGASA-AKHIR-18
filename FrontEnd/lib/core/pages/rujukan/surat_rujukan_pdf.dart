import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../service/rujukan_service.dart';
import '../../utils/posyandu.dart';
import '../../utils/no_hp.dart';

// ============================================================================
// PDF SURAT RUJUKAN ANAK
// Hitam putih, tabel transparan (garis hitam, tanpa warna isi),
// format seperti surat rujukan rumah sakit / puskesmas.
// Dipakai bidan & orang tua.
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
    } else if (r == 0x00B1) {
      b.write('+/-');
    } else if (r == 0x0A) {
      b.write('\n');
    } else if (r >= 0x20 && r <= 0x7E) {
      b.writeCharCode(r);
    } else {
      b.write('?');
    }
  }
  return b.toString();
}

String _isi(String s) => s.trim().isEmpty ? '-' : s.trim();

pw.Widget _teks(String s,
        {bool tebal = false, double ukuran = 9.5, pw.TextAlign rata = pw.TextAlign.left, bool miring = false}) =>
    pw.Text(
      _aman(s),
      textAlign: rata,
      style: pw.TextStyle(
        fontSize: ukuran,
        lineSpacing: 1.5,
        fontWeight: tebal ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: miring ? pw.FontStyle.italic : pw.FontStyle.normal,
        color: _hitam,
      ),
    );

/// Tabel 2 kolom (label : isi) bergaris hitam.
pw.Widget _tabelData(List<(String, String)> baris, {double lebarLabel = 52}) => pw.Table(
      border: pw.TableBorder.all(color: _hitam, width: 0.6),
      columnWidths: {
        0: pw.FixedColumnWidth(lebarLabel * PdfPageFormat.mm),
        1: const pw.FlexColumnWidth(),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        for (final b in baris)
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4), child: _teks(b.$1)),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4), child: _teks(b.$2)),
          ]),
      ],
    );

/// Kotak isian bergaris dengan judul tebal.
pw.Widget _kotak(String judul, String isi) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(6, 5, 6, 7),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _hitam, width: 0.6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _teks(judul, tebal: true),
          pw.SizedBox(height: 3),
          _teks(_isi(isi)),
        ],
      ),
    );

pw.Widget _bagian(String nomor, String judul) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 9, bottom: 4),
      child: _teks('$nomor. $judul', tebal: true, ukuran: 10.5),
    );

/// Membuat PDF surat rujukan.
Future<Uint8List> buatPdfSuratRujukan(RujukanDetail r) async {
  final doc = pw.Document(
    title: 'Surat Rujukan ${r.nomor}',
    author: 'PosyanduCare',
    creator: 'PosyanduCare',
  );
  final a = r.dataAnak;
  final p = a.pemeriksaan;
  final namaPos = labelPosyandu(r.posyandu.isNotEmpty ? r.posyandu : a.posyandu);
  final ortu = <(String, String)>[
    if (a.namaIbu.isNotEmpty) ('Nama ibu', a.namaIbu),
    if (a.namaAyah.isNotEmpty) ('Nama ayah', a.namaAyah),
    if (a.namaWali.isNotEmpty) ('Nama wali', a.namaWali),
    if (a.namaIbu.isEmpty && a.namaAyah.isEmpty && a.namaWali.isEmpty) ('Nama orang tua', '-'),
    ('No. HP', formatNoHp(a.noHp)),
    ('Alamat', _isi(a.alamat)),
    ('Posyandu', 'Posyandu $namaPos'),
  ];
  final lahir = [
    if (a.beratLahirKg != null) 'BB lahir ${angkaRujukan(a.beratLahirKg, 'kg')}',
    if (a.panjangLahirCm != null) 'PB lahir ${angkaRujukan(a.panjangLahirCm, 'cm')}',
  ].join(', ');

  final isi = <pw.Widget>[
    pw.Center(child: _teks('SURAT RUJUKAN', tebal: true, ukuran: 15)),
    pw.SizedBox(height: 3),
    pw.Center(child: _teks('Posyandu $namaPos', ukuran: 10.5)),
    pw.SizedBox(height: 6),
    pw.Container(height: 1.6, color: _hitam),
    pw.SizedBox(height: 8),
    if (r.dibatalkan) ...[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _hitam, width: 1.2)),
        child: _teks('RUJUKAN INI TELAH DIBATALKAN. Alasan: ${_isi(r.alasanBatal)}', tebal: true),
      ),
      pw.SizedBox(height: 8),
    ],
    _tabelData([
      ('Nomor', r.nomor),
      ('Tanggal', tglRujukan(r.tanggal)),
    ], lebarLabel: 30),
    pw.SizedBox(height: 10),
    _teks('Kepada Yth.'),
    _teks('Dokter / Petugas Kesehatan', tebal: true),
    _teks(_isi(r.tujuan), tebal: true),
    _teks('di tempat'),
    pw.SizedBox(height: 8),
    _teks('Dengan hormat, mohon pemeriksaan dan penanganan lebih lanjut terhadap anak berikut:'),

    _bagian('I', 'Identitas Anak'),
    _tabelData([
      ('Nama anak', a.nama),
      ('NIK', _isi(a.nik)),
      ('Jenis kelamin', jkRujukan(a.jenisKelamin)),
      ('Tanggal lahir / usia', '${tglRujukan(a.tanggalLahir)}  (${_isi(a.usiaTeks)})'),
      if (lahir.isNotEmpty) ('Data lahir', lahir),
    ]),

    _bagian('II', 'Identitas Orang Tua'),
    _tabelData(ortu),

    _bagian('III', 'Hasil Pemeriksaan Terakhir di Posyandu'),
    if (p == null)
      _tabelData([('Keterangan', 'Belum ada data pengukuran')])
    else
      _tabelData([
        ('Tanggal ukur', '${tglRujukan(p.tanggalUkur)}${p.usiaUkur.isEmpty ? '' : '  (usia ${p.usiaUkur})'}'),
        ('Berat badan', angkaRujukan(p.bbKg, 'kg')),
        ('Tinggi / panjang badan', angkaRujukan(p.tbCm, 'cm')),
        ('Lingkar lengan atas (LiLA)', angkaRujukan(p.lilaCm, 'cm')),
        ('Lingkar kepala', angkaRujukan(p.lkCm, 'cm')),
        ('Status gizi BB/U', _isi(p.statusBbu)),
        ('Status gizi TB/U', _isi(p.statusTbu)),
        ('Status gizi BB/TB', _isi(p.statusBbtb)),
        ('Penimbangan', p.tandaTimbang.isEmpty ? '-' : p.tandaTimbang),
      ]),

    _bagian('IV', 'Keterangan Rujukan'),
    _kotak('Keluhan', r.keluhan),
    pw.SizedBox(height: 5),
    _kotak('Diagnosis', r.diagnosis),
    pw.SizedBox(height: 5),
    _kotak('Tindakan yang sudah dilakukan', r.tindakan),
    pw.SizedBox(height: 10),
    _teks('Demikian surat rujukan ini kami sampaikan. Atas perhatian dan kerja samanya kami ucapkan terima kasih.'),
    pw.SizedBox(height: 14),

    // tanda tangan bidan perujuk (kanan)
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 70 * PdfPageFormat.mm,
          child: pw.Column(children: [
            _teks('$namaPos, ${tglRujukan(r.tanggal)}', rata: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            _teks('Bidan Perujuk', rata: pw.TextAlign.center),
            pw.SizedBox(height: 46),
            _teks(r.bidanNama.isEmpty ? '(______________________)' : '( ${r.bidanNama} )',
                rata: pw.TextAlign.center),
          ]),
        ),
      ],
    ),
    pw.SizedBox(height: 16),

    // jawaban rujukan
    _jawabanRujukan(r),
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
            pw.Text(_aman('Dicetak dari aplikasi PosyanduCare  |  ${r.nomor}'),
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

/// Bagian "Jawaban Rujukan": kosong untuk diisi faskes tujuan,
/// atau terisi bila hasilnya sudah dicatat bidan.
pw.Widget _jawabanRujukan(RujukanDetail r) {
  final b = r.balik;
  pw.TableRow baris(String label, String isi, {double tinggi = 0}) => pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4), child: _teks(label)),
        pw.Container(
          constraints: pw.BoxConstraints(minHeight: tinggi),
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: _teks(isi),
        ),
      ]);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _teks(
          b == null
              ? 'JAWABAN RUJUKAN (diisi oleh fasilitas kesehatan tujuan)'
              : 'JAWABAN RUJUKAN (dicatat oleh bidan posyandu)',
          tebal: true,
          ukuran: 10.5),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: _hitam, width: 0.6),
        columnWidths: {
          0: pw.FixedColumnWidth(52 * PdfPageFormat.mm),
          1: const pw.FlexColumnWidth(),
        },
        children: b == null
            ? [
                baris('Tanggal diperiksa', '', tinggi: 20),
                baris('Diagnosis', '', tinggi: 34),
                baris('Terapi / tindakan', '', tinggi: 34),
                baris('Saran / tindak lanjut', '', tinggi: 34),
                baris('Nama & tanda tangan petugas', '', tinggi: 40),
              ]
            : [
                baris('Tanggal diperiksa', tglRujukan(b.tanggalDiperiksa)),
                baris('Hasil / diagnosis', _isi(b.hasilDiagnosis)),
                baris('Terapi / saran', _isi(b.terapiSaran)),
                baris('Tindak lanjut di posyandu', _isi(b.tindakLanjut)),
              ],
      ),
    ],
  );
}