import '../Bidan/vaksin_model.dart';

class VaksinStatistikItem {
  final VaksinJenis vaksin;
  final int jumlahDiberikan;
  final int jumlahAnak;

  const VaksinStatistikItem({
    required this.vaksin,
    required this.jumlahDiberikan,
    required this.jumlahAnak,
  });

  factory VaksinStatistikItem.fromJson(Map<String, dynamic> j) => VaksinStatistikItem(
        vaksin: VaksinJenis.fromJson(j['jenis_vaksin']),
        jumlahDiberikan: (j['jumlah_diberikan'] ?? 0) as int,
        jumlahAnak: (j['jumlah_anak'] ?? 0) as int,
      );
}

class VaksinStatistik {
  final int totalDiberikan;
  final int totalAnakDivaksin;
  final int rencanaAktif;
  final int jumlahJenis;
  final List<VaksinStatistikItem> jenis;

  const VaksinStatistik({
    required this.totalDiberikan,
    required this.totalAnakDivaksin,
    required this.rencanaAktif,
    required this.jumlahJenis,
    required this.jenis,
  });

  factory VaksinStatistik.fromJson(Map<String, dynamic> j) => VaksinStatistik(
        totalDiberikan: (j['total_diberikan'] ?? 0) as int,
        totalAnakDivaksin: (j['total_anak_divaksin'] ?? 0) as int,
        rencanaAktif: (j['rencana_aktif'] ?? 0) as int,
        jumlahJenis: (j['jumlah_jenis'] ?? 0) as int,
        jenis: ((j['jenis'] as List?) ?? [])
            .map((e) => VaksinStatistikItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}