class VaksinJenis {
  final String id;
  final String nama;
  const VaksinJenis(this.id, this.nama);

  factory VaksinJenis.fromJson(dynamic j) {
    if (j is! Map) return const VaksinJenis('', '-');
    final nama = j['nama'] ?? j['nama_vaksin'] ?? j['singkatan'] ?? '-';
    return VaksinJenis('${j['id'] ?? ''}', '$nama');
  }
}

class VaksinMaster {
  final String id;
  final VaksinJenis vaksin;
  final int dosisKe;
  final int usiaMinBulan;
  final int usiaIdealBulan;
  final int? usiaMaksBulan;

  const VaksinMaster({
    required this.id,
    required this.vaksin,
    required this.dosisKe,
    required this.usiaMinBulan,
    required this.usiaIdealBulan,
    this.usiaMaksBulan,
  });

  factory VaksinMaster.fromJson(Map<String, dynamic> j) => VaksinMaster(
        id: '${j['id']}',
        vaksin: VaksinJenis.fromJson(j['jenis_vaksin']),
        dosisKe: (j['dosis_ke'] ?? 0) as int,
        usiaMinBulan: (j['usia_min_bulan'] ?? 0) as int,
        usiaIdealBulan: (j['usia_ideal_bulan'] ?? 0) as int,
        usiaMaksBulan: j['usia_maks_bulan'] as int?,
      );

  String get label => '${vaksin.nama} · Dosis $dosisKe (ideal $usiaIdealBulan bln)';
}

class VaksinRencana {
  final String id;
  final String anakId;
  final String jadwalImunisasiId;
  final VaksinJenis vaksin;
  final int dosisKe;
  final int usiaIdealBulan;
  final String perkiraanTanggal;
  final String status;
  final bool terlambat;
  final String alasan;

  const VaksinRencana({
    required this.id,
    required this.anakId,
    required this.jadwalImunisasiId,
    required this.vaksin,
    required this.dosisKe,
    required this.usiaIdealBulan,
    required this.perkiraanTanggal,
    required this.status,
    required this.terlambat,
    required this.alasan,
  });

  factory VaksinRencana.fromJson(Map<String, dynamic> j) => VaksinRencana(
        id: '${j['id']}',
        anakId: '${j['anak_id']}',
        jadwalImunisasiId: '${j['jadwal_imunisasi_id']}',
        vaksin: VaksinJenis.fromJson(j['jenis_vaksin']),
        dosisKe: (j['dosis_ke'] ?? 0) as int,
        usiaIdealBulan: (j['usia_ideal_bulan'] ?? 0) as int,
        perkiraanTanggal: '${j['perkiraan_tanggal']}',
        status: '${j['status']}',
        terlambat: j['terlambat'] == true,
        alasan: '${j['alasan'] ?? ''}',
      );
}

class VaksinRiwayat {
  final String id;
  final VaksinJenis vaksin;
  final int dosisKe;
  final String tanggalPemberian;
  final String kondisiAnak;
  final String catatan;
  final String namaPemberi;

  const VaksinRiwayat({
    required this.id,
    required this.vaksin,
    required this.dosisKe,
    required this.tanggalPemberian,
    required this.kondisiAnak,
    required this.catatan,
    required this.namaPemberi,
  });

  factory VaksinRiwayat.fromJson(Map<String, dynamic> j) => VaksinRiwayat(
        id: '${j['id']}',
        vaksin: VaksinJenis.fromJson(j['jenis_vaksin']),
        dosisKe: (j['dosis_ke'] ?? 0) as int,
        tanggalPemberian: '${j['tanggal_pemberian']}',
        kondisiAnak: '${j['kondisi_anak'] ?? ''}',
        catatan: '${j['catatan'] ?? ''}',
        namaPemberi: '${j['nama_pemberi'] ?? ''}',
      );
}

const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String formatTanggalApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String formatTanggalTampil(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}