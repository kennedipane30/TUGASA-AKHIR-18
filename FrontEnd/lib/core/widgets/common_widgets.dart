import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../pages/notifikasi/notifikasi_page.dart';
import '../../service/notifikasi_service.dart';

// ---------------------------------------------------------------------------
// Fungsi bantu
// ---------------------------------------------------------------------------

/// Pesan sementara untuk fitur yang belum dibuat.
void soon(BuildContext context, String fitur) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('$fitur akan tersedia pada tahap berikutnya')),
    );
}

const _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const _namaBulanSingkat = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatTanggal(DateTime d) =>
    '${d.day} ${_namaBulan[d.month - 1]} ${d.year}';

String formatJam(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}.'
    '${d.minute.toString().padLeft(2, '0')}';

String bulanSingkat(DateTime d) => _namaBulanSingkat[d.month - 1];

/// Tingkat status gizi: hijau (baik), kuning (waspada), merah (berisiko).
enum Gizi { baik, waspada, risiko }

Color giziFg(Gizi g) => switch (g) {
      Gizi.baik => AppColors.hijau,
      Gizi.waspada => AppColors.kuning,
      Gizi.risiko => AppColors.merah,
    };

Color giziBg(Gizi g) => switch (g) {
      Gizi.baik => AppColors.hijauMuda,
      Gizi.waspada => AppColors.kuningMuda,
      Gizi.risiko => AppColors.merahMuda,
    };

// ===========================================================================
// KOMPONEN BERANDA (dipakai bersama oleh Orang Tua, Kader, Bidan, Sekretaris)
//
// Satu tampilan untuk semua peran:
//   header hijau  ->  kartu status yang menumpuk header  ->  grid layanan
//
// Ikon grid tetap memakai gambar PNG yang sudah ada di proyek.
// ===========================================================================

// --------------------------------------------------------------- warna tema

/// Hijau utama header dan tombol.
const warnaUtamaHome = Color(0xFF0D6E52);

/// Hijau tua untuk teks di atas latar terang.
const warnaUtamaTuaHome = Color(0xFF00543D);

/// Hijau lembut: latar pil navigasi aktif dan lingkaran ikon kartu.
const warnaLembutHome = Color(0xFFC6E7D6);

/// Teks di atas [warnaLembutHome].
const warnaTeksLembutHome = Color(0xFF003828);

/// Latar halaman: sama dengan halaman lain agar desain tetap seragam.
const warnaLatarHome = AppColors.latar;

/// Teks utama.
const warnaTeksHome = Color(0xFF181D1A);

/// Teks keterangan.
const warnaTeksVarianHome = Color(0xFF3F4944);

/// Garis tepi dan pemisah.
const warnaGarisHome = Color(0xFFBEC9C2);

/// Warna status.
const warnaErrorHome = Color(0xFFBA1A1A);
const warnaSuksesIsiHome = Color(0xFFD7F9E7);
const warnaSuksesTeksHome = Color(0xFF003828);
const warnaInfoIsiHome = Color(0xFFDCEEFB);
const warnaInfoTeksHome = Color(0xFF113A54);
const warnaPeringatanIsiHome = Color(0xFFFEF3C7);
const warnaPeringatanTeksHome = Color(0xFF78350F);

/// Bayangan kartu beranda: memakai token yang sama dengan halaman lain.
const bayanganKartuHome = AppColors.bayanganKartu;

// --------------------------------------------------------------- kartu dasar

/// Kartu putih bersudut besar: dipakai untuk kartu status di bawah header.
class KartuHome extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color warna;

  const KartuHome({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.warna = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: warna,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: warnaGarisHome.withValues(alpha: 0.4)),
        boxShadow: bayanganKartuHome,
      ),
      child: child,
    );
  }
}

/// Kepala kartu: lingkaran ikon + judul di kiri, lencana status di kanan,
/// lalu garis pemisah tipis di bawahnya.
class KepalaKartuHome extends StatelessWidget {
  /// Ikon bulat di kiri judul. Kosongkan bila judulnya tidak perlu ikon.
  final IconData? ikon;
  final String judul;

  /// Ditekan bila judul dapat dipilih (mis. memilih anak).
  final VoidCallback? onJudul;
  final Widget? lencana;

  const KepalaKartuHome({
    super.key,
    this.ikon,
    required this.judul,
    this.onJudul,
    this.lencana,
  });

  @override
  Widget build(BuildContext context) {
    final teks = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            judul,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: warnaTeksHome,
            ),
          ),
        ),
        if (onJudul != null)
          const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: warnaUtamaHome),
      ],
    );

    return Column(
      children: [
        Row(
          children: [
            if (ikon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: warnaLembutHome.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(ikon, size: 20, color: warnaUtamaHome),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: onJudul == null
                  ? teks
                  : InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onJudul,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: teks,
                      ),
                    ),
            ),
            if (lencana != null) ...[const SizedBox(width: 8), lencana!],
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: warnaGarisHome.withValues(alpha: 0.4)),
      ],
    );
  }
}

/// Lencana status berbentuk pil, mis. "Selesai dilayani".
class LencanaStatusHome extends StatelessWidget {
  final String teks;
  final IconData ikon;
  final Color isi;
  final Color warnaTeks;

  const LencanaStatusHome({
    super.key,
    required this.teks,
    this.ikon = Icons.check_circle,
    this.isi = warnaSuksesIsiHome,
    this.warnaTeks = warnaSuksesTeksHome,
  });

  /// Lencana sesuai jenis: sukses (hijau), info (biru), peringatan (kuning), bahaya (merah).
  factory LencanaStatusHome.jenis(String jenis, String teks) {
    switch (jenis) {
      case 'info':
        return LencanaStatusHome(
            teks: teks,
            ikon: Icons.hourglass_top_rounded,
            isi: warnaInfoIsiHome,
            warnaTeks: warnaInfoTeksHome);
      case 'peringatan':
        return LencanaStatusHome(
            teks: teks,
            ikon: Icons.schedule_rounded,
            isi: warnaPeringatanIsiHome,
            warnaTeks: warnaPeringatanTeksHome);
      case 'bahaya':
        return LencanaStatusHome(
            teks: teks,
            ikon: Icons.error_outline_rounded,
            isi: const Color(0xFFFFDAD6),
            warnaTeks: const Color(0xFF93000A));
      default:
        return LencanaStatusHome(teks: teks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: isi, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 16, color: warnaTeks),
          const SizedBox(width: 6),
          Text(
            teks,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: warnaTeks),
          ),
        ],
      ),
    );
  }
}

/// Baris keterangan: ikon, label berkolom tetap, lalu nilainya.
class BarisInfoHome extends StatelessWidget {
  final IconData ikon;
  final String label;
  final String nilai;
  final Color? warnaNilai;

  const BarisInfoHome(this.ikon, this.label, this.nilai, {super.key, this.warnaNilai});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(ikon, size: 20, color: warnaUtamaHome),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15.5, height: 1.4, color: warnaTeksVarianHome),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nilai.isEmpty ? '-' : nilai,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: warnaNilai ?? warnaTeksHome,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiga angka ringkasan berjajar dengan pemisah tegak.
class RingkasAngkaHome extends StatelessWidget {
  /// Setiap isian: (nilai, label, warna).
  final List<(String, String, Color)> item;

  const RingkasAngkaHome({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final anak = <Widget>[];
    for (var i = 0; i < item.length; i++) {
      if (i > 0) {
        anak.add(Container(width: 1, height: 34, color: warnaGarisHome.withValues(alpha: 0.5)));
      }
      anak.add(
        Expanded(
          child: Column(
            children: [
              Text(
                item[i].$1,
                style: TextStyle(
                    fontSize: 22, height: 1.1, fontWeight: FontWeight.w700, color: item[i].$3),
              ),
              const SizedBox(height: 4),
              Text(
                item[i].$2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: warnaTeksVarianHome),
              ),
            ],
          ),
        ),
      );
    }
    return Row(children: anak);
  }
}

/// Tombol utama kartu: ikon + label di kiri, panah di kanan.
class TombolUtamaHome extends StatelessWidget {
  final String label;
  final IconData? ikon;
  final VoidCallback? onTap;

  const TombolUtamaHome({super.key, required this.label, this.ikon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: warnaUtamaHome,
          foregroundColor: Colors.white,
          disabledBackgroundColor: warnaUtamaHome.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          children: [
            if (ikon != null) ...[Icon(ikon, size: 20), const SizedBox(width: 10)],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Tautan kecil di sudut kanan kartu, mis. "Lihat antrean".
class TautanKartuHome extends StatelessWidget {
  final String teks;
  final VoidCallback? onTap;

  const TautanKartuHome({super.key, required this.teks, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                teks,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600, color: warnaUtamaHome),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: warnaUtamaHome),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- grid layanan

/// Satu ikon layanan pada grid beranda.
/// Gambar PNG proyek dipakai apa adanya; [cadangan] hanya dipakai bila gambar
/// tidak ditemukan.
class ItemLayananHome {
  final String aset;
  final IconData cadangan;
  final Color warna;
  final String judul;
  final VoidCallback onTap;

  /// Angka kecil di sudut ikon (mis. jumlah anak berisiko).
  final int? badge;
  final Color badgeWarna;

  const ItemLayananHome({
    required this.aset,
    required this.cadangan,
    required this.warna,
    required this.judul,
    required this.onTap,
    this.badge,
    this.badgeWarna = warnaErrorHome,
  });
}

/// Judul bagian, mis. "Layanan Posyandu".
class JudulBagianHome extends StatelessWidget {
  final String teks;

  const JudulBagianHome(this.teks, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      teks,
      style: const TextStyle(
        fontSize: 21,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: warnaTeksHome,
      ),
    );
  }
}

/// Grid layanan 4 kolom beserta judulnya.
class GridLayananHome extends StatelessWidget {
  final String judul;
  final List<ItemLayananHome> item;

  const GridLayananHome({super.key, required this.judul, required this.item});

  Widget _item(ItemLayananHome m) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: m.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.asset(
                      m.aset,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: warnaLembutHome.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Icon(m.cadangan, color: m.warna, size: 26),
                      ),
                    ),
                  ),
                  if (m.badge != null && m.badge! > 0)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: m.badgeWarna,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          m.badge! > 99 ? '99+' : '${m.badge}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    m.judul,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: warnaTeksHome,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baris = <Widget>[];
    for (var i = 0; i < item.length; i += 4) {
      final potong = item.sublist(i, i + 4 > item.length ? item.length : i + 4);
      baris.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in potong) _item(m),
              for (var k = potong.length; k < 4; k++) const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagianHome(judul),
        const SizedBox(height: 16),
        ...baris,
      ],
    );
  }
}

// --------------------------------------------------------------- kartu pesan

/// Kartu pemberitahuan sederhana (memuat data, gagal memuat, data kosong).
class KartuPesanHome extends StatelessWidget {
  final IconData ikon;
  final String judul;
  final String pesan;
  final Color isi;
  final Color warnaIkon;
  final Widget? aksi;

  const KartuPesanHome({
    super.key,
    required this.ikon,
    required this.judul,
    required this.pesan,
    this.isi = Colors.white,
    this.warnaIkon = warnaUtamaHome,
    this.aksi,
  });

  @override
  Widget build(BuildContext context) {
    return KartuHome(
      warna: isi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 22, color: warnaIkon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  judul,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600, color: warnaTeksHome),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pesan,
            style: const TextStyle(fontSize: 15.5, height: 1.45, color: warnaTeksVarianHome),
          ),
          if (aksi != null) ...[const SizedBox(height: 14), aksi!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kerangka halaman home (dipakai semua peran)
// ---------------------------------------------------------------------------

const _hijauTua = Color(0xFF0B3D2E);
const _hijauGelap = Color(0xFF14634A);
const _hijauAksen = Color(0xFF1F7A5C);

/// Kerangka beranda untuk semua peran. Susunannya sama di tiap peran:
///
///   header hijau  : logo, nama aplikasi, lonceng, avatar, posyandu, sapaan
///   [kartuUtama]  : kartu status yang sebagian menumpuk header
///   [children]    : isi halaman, biasanya grid layanan
class HomeShell extends StatelessWidget {
  /// Nama peran (Orang Tua, Kader, Bidan, Sekretaris). Disimpan sebagai
  /// keterangan halaman; keluar dari akun dilakukan lewat menu Akun.
  final String peran;

  /// Posyandu atau wilayah kerja pengguna.
  final String lokasi;

  /// Nama sapaan, mis. "KENNEDI". Kosong berarti sapaan tidak ditampilkan.
  final String sapaan;

  /// Kartu status yang menumpuk header, mis. jadwal posyandu terdekat.
  final Widget? kartuUtama;

  /// Tidak dipakai lagi; jumlah notifikasi diambil dari server.
  final int notif;
  final List<Widget> children;

  const HomeShell({
    super.key,
    required this.peran,
    required this.lokasi,
    required this.children,
    this.sapaan = '',
    this.kartuUtama,
    this.notif = 0,
  });

  void _bukaNotifikasi(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotifikasiPage()),
    );
  }

  /// Logo aplikasi di sudut kiri atas, tanpa kotak pembungkus.
  Widget _logo() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Image.asset(
        'logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.health_and_safety,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  /// Lonceng notifikasi dengan titik merah bila ada yang belum dibaca.
  Widget _lonceng(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotifikasiService.instance.belumDibaca,
      builder: (context, jumlah, _) => Tooltip(
        message: jumlah > 0 ? '$jumlah notifikasi belum dibaca' : 'Notifikasi',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _bukaNotifikasi(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.notifications, color: Colors.white, size: 22),
              ),
              if (jumlah > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: IgnorePointer(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: warnaErrorHome,
                        shape: BoxShape.circle,
                        border: Border.all(color: warnaUtamaHome, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Baris atas header: logo di kiri, nama aplikasi di tengah, lonceng di kanan.
  /// Bagian ini tetap berada di atas layar walaupun halaman digulir.
  Widget _barisAtas(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Nama aplikasi, selalu di tengah baris
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Posyandu Care',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Layanan Kesehatan Anak',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xCCFFFFFF),
                ),
              ),
            ],
          ),
        ),

        Align(alignment: Alignment.centerLeft, child: _logo()),
        Align(alignment: Alignment.centerRight, child: _lonceng(context)),
      ],
    );
  }

  /// Isi halaman beserta alas hijaunya.
  ///
  /// Latar hijau dibuat setinggi sepertiga layar (termasuk baris atas yang
  /// diam), lalu sapaan dan kartu status digambar di atasnya. Jadi hijaunya
  /// hanya memanjang ke bawah, sedangkan susunan isinya tidak berubah.
  Widget _isi(double tinggiHijau) {
    return Stack(
      children: [
        // Alas hijau yang memanjang ke bawah
        if (tinggiHijau > 0)
          Container(
            width: double.infinity,
            height: tinggiHijau,
            decoration: const BoxDecoration(
              color: warnaUtamaHome,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Color(0x1A003828), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
          ),

        // Sapaan dan isi halaman, digambar di atas alas hijau
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sapaan.isNotEmpty)
              Padding(
                // Jarak dari baris atas yang diam ke sapaan.
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
                child: Text(
                  'Hi, $sapaan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (kartuUtama != null) ...[
                    kartuUtama!,
                    const SizedBox(height: 24),
                  ],
                  ...children,
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tinggi baris atas yang tetap: jarak status bar + padding + tinggi logo.
    final atas = MediaQuery.of(context).padding.top;
    final tinggiTetap = atas + 18 + 52 + 12;

    // Hijau seluruhnya sepertiga tinggi layar; sisanya dipakai sebagai alas isi.
    final tinggiHijau = (MediaQuery.of(context).size.height / 3) - tinggiTetap;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: warnaLatarHome,
        body: Stack(
          children: [
            // Isi halaman: sapaan, kartu status, lalu grid layanan.
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: NotifikasiService.instance.perbaruiJumlah,
                notificationPredicate: (n) => n.depth == 0,
                displacement: tinggiTetap + 8,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(top: tinggiTetap),
                  children: [_isi(tinggiHijau)],
                ),
              ),
            ),

            // Baris atas tetap diam di bagian paling atas layar.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: warnaUtamaHome,
                padding: EdgeInsets.fromLTRB(16, atas + 18, 16, 12),
                child: _barisAtas(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// Komponen kecil
// ---------------------------------------------------------------------------

class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final Color color;

  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECE8)),
        boxShadow: AppColors.bayanganKartu,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: _hijauGelap),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _hijauTua,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  const Pill(
    this.text, {
    super.key,
    this.bg = AppColors.hijauMuda,
    this.fg = AppColors.hijau,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak angka ringkas (misalnya Terdaftar 42).
class StatBox extends StatelessWidget {
  final String nilai;
  final String label;
  final Color bg;
  final Color fg;

  const StatBox({
    super.key,
    required this.nilai,
    required this.label,
    this.bg = AppColors.isiField,
    this.fg = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            nilai,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.teksRedup,
            ),
          ),
        ],
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final Color color;

  const AppButton(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.filled = true,
    this.color = AppColors.hijau,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final teks = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15.5,
      ),
    );
    final ikon = icon == null ? null : Icon(icon, size: 17);

    if (filled) {
      final gaya = ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: shape,
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      );

      return ikon == null
          ? ElevatedButton(
              style: gaya,
              onPressed: onPressed,
              child: teks,
            )
          : ElevatedButton.icon(
              style: gaya,
              onPressed: onPressed,
              icon: ikon,
              label: teks,
            );
    }

    final gaya = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color),
      shape: shape,
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 12,
      ),
    );

    return ikon == null
        ? OutlinedButton(
            style: gaya,
            onPressed: onPressed,
            child: teks,
          )
        : OutlinedButton.icon(
            style: gaya,
            onPressed: onPressed,
            icon: ikon,
            label: teks,
          );
  }
}

/// Indikator status online/offline, data tertunda, dan sinkron terakhir.
class SyncStrip extends StatelessWidget {
  final bool online;
  final int tertunda;
  final String sinkronTerakhir;
  final bool sedangSinkron;
  final VoidCallback? onSinkron;

  const SyncStrip({
    super.key,
    required this.online,
    required this.tertunda,
    required this.sinkronTerakhir,
    this.sedangSinkron = false,
    this.onSinkron,
  });

  @override
  Widget build(BuildContext context) {
    final bg = online ? const Color(0xFFE3F6EC) : AppColors.kuningMuda;
    final fg = online ? _hijauGelap : AppColors.kuning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: online ? const Color(0xFFBFE5D0) : const Color(0xFFF3DFA8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'Mode Online Terhubung' : 'Mode Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                    color: fg,
                  ),
                ),
                Text(
                  '$tertunda data belum terkirim · '
                  'sinkron terakhir $sinkronTerakhir',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (onSinkron != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hijauGelap,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: sedangSinkron ? null : onSinkron,
              icon: sedangSinkron
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync, size: 16),
              label: Text(
                sedangSinkron ? 'Proses' : 'Sinkron',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grafik batang sederhana tanpa package tambahan.
class MiniBars extends StatelessWidget {
  final List<double> nilai;
  final List<String> label;
  final double tinggi;
  final Color warna;

  const MiniBars({
    super.key,
    required this.nilai,
    required this.label,
    this.tinggi = 90,
    this.warna = _hijauAksen,
  });

  @override
  Widget build(BuildContext context) {
    final maks = nilai.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: tinggi + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < nilai.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    nilai[i].toInt().toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: tinggi * nilai[i] / maks,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: warna,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label[i],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.teksRedup,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}