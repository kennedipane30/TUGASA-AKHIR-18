import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/common_widgets.dart';

class _DataGrafik {
  final String nama;
  final List<double> bb, bawah, atas;
  final List<double> tb;
  const _DataGrafik(this.nama, this.bb, this.bawah, this.atas, this.tb);
}

// DATA CONTOH. Ganti dengan data dari API / database lokal.
const _data = <_DataGrafik>[
  _DataGrafik(
    'Rian Pratama',
    [10.6, 11.0, 11.4, 11.8, 12.1, 12.4],
    [9.4, 9.7, 10.0, 10.2, 10.4, 10.6],
    [13.4, 13.8, 14.2, 14.5, 14.8, 15.1],
    [84.0, 85.2, 86.4, 87.1, 87.8, 88.5],
  ),
  _DataGrafik(
    'Aisyah',
    [6.7, 6.9, 7.2, 7.5, 7.7, 7.8],
    [6.3, 6.5, 6.7, 6.9, 7.1, 7.3],
    [8.9, 9.1, 9.3, 9.5, 9.7, 9.9],
    [64.0, 65.0, 66.0, 66.8, 67.5, 68.0],
  ),
];

class OrangTuaGrafikPage extends StatefulWidget {
  const OrangTuaGrafikPage({super.key});

  @override
  State<OrangTuaGrafikPage> createState() => _OrangTuaGrafikPageState();
}

class _OrangTuaGrafikPageState extends State<OrangTuaGrafikPage> {
  int _aktif = 0;

  @override
  Widget build(BuildContext context) {
    final d = _data[_aktif];
    final now = DateTime.now();
    final label = [
      for (var i = d.bb.length - 1; i >= 0; i--)
        bulanSingkat(DateTime(now.year, now.month - i, 1)),
    ];
    final selisih = d.bb.last - d.bb[d.bb.length - 2];

    return Scaffold(
      backgroundColor: AppColors.latar,
      appBar: AppBar(
        title: const Text('Grafik Perkembangan',
            style: TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _data.length; i++)
                ChoiceChip(
                  selected: i == _aktif,
                  selectedColor: AppColors.hijau,
                  backgroundColor: Colors.white,
                  label: Text(_data[i].nama),
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: i == _aktif ? Colors.white : Colors.black87),
                  onSelected: (_) => setState(() => _aktif = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Grafik Berat Badan (KMS)',
            icon: Icons.show_chart,
            trailing: const Pill('BB/U'),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CustomPaint(painter: _GrafikPainter(d.bb, d.bawah, d.atas)),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final l in label)
                      Text(l,
                          style: const TextStyle(fontSize: 10, color: AppColors.teksRedup)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: StatBox(
                            nilai: '${d.bb.last}',
                            label: 'Berat terakhir (kg)',
                            bg: AppColors.hijauMuda,
                            fg: AppColors.hijau)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: StatBox(
                            nilai: '${selisih >= 0 ? '+' : ''}${selisih.toStringAsFixed(1)}',
                            label: 'Perubahan bulan ini (kg)',
                            bg: AppColors.biruMuda,
                            fg: AppColors.biru)),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Tinggi / Panjang Badan',
            icon: Icons.height,
            child: MiniBars(
              nilai: d.tb,
              label: label,
              warna: AppColors.biru,
            ),
          ),
          AppButton('Unduh Grafik KMS Resmi (PDF)',
              icon: Icons.download,
              filled: false,
              onPressed: () => soon(context, 'Unduh PDF')),
        ],
      ),
    );
  }
}

class _GrafikPainter extends CustomPainter {
  final List<double> bb, bawah, atas;
  _GrafikPainter(this.bb, this.bawah, this.atas);

  @override
  void paint(Canvas canvas, Size size) {
    final n = bb.length;
    if (n < 2) return;
    final minY = math.min(bawah.reduce(math.min), bb.reduce(math.min)) - 0.5;
    final maxY = math.max(atas.reduce(math.max), bb.reduce(math.max)) + 0.5;
    final dx = size.width / (n - 1);
    double y(double v) => size.height - (v - minY) / (maxY - minY) * size.height;

    final grid = Paint()
      ..color = const Color(0xFFE5E5EE)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final gy = size.height * i / 3;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }

    final pita = Path()..moveTo(0, y(atas[0]));
    for (var i = 1; i < n; i++) {
      pita.lineTo(dx * i, y(atas[i]));
    }
    for (var i = n - 1; i >= 0; i--) {
      pita.lineTo(dx * i, y(bawah[i]));
    }
    pita.close();
    canvas.drawPath(pita, Paint()..color = const Color(0xFFCFEBDD));

    final garis = Paint()
      ..color = AppColors.hijau
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final jalur = Path()..moveTo(0, y(bb[0]));
    for (var i = 1; i < n; i++) {
      jalur.lineTo(dx * i, y(bb[i]));
    }
    canvas.drawPath(jalur, garis);

    final titik = Paint()..color = AppColors.hijau;
    final putih = Paint()..color = Colors.white;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(dx * i, y(bb[i])), 5, putih);
      canvas.drawCircle(Offset(dx * i, y(bb[i])), 3.5, titik);
    }
  }

  @override
  bool shouldRepaint(covariant _GrafikPainter old) =>
      old.bb != bb || old.bawah != bawah || old.atas != atas;
}