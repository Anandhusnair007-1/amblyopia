import 'dart:math' as math;

import 'package:flutter/material.dart';

class PlateData {
  final String number;
  final Color fgColor;
  final Color bgColor;
  final String description;

  const PlateData({
    required this.number,
    required this.fgColor,
    required this.bgColor,
    required this.description,
  });
}

class IshiharaPlateWidget extends StatelessWidget {
  const IshiharaPlateWidget({
    super.key,
    required this.plateNumber,
    required this.size,
  });

  final int plateNumber;
  final double size;

  static const List<PlateData> plates = <PlateData>[
    PlateData(
      number: '12',
      fgColor: Color(0xFFE53935),
      bgColor: Color(0xFF8BC34A),
      description: 'Demo plate',
    ),
    PlateData(
      number: '8',
      fgColor: Color(0xFF8D6E63),
      bgColor: Color(0xFF66BB6A),
      description: 'R-G test',
    ),
    PlateData(
      number: '29',
      fgColor: Color(0xFFE57373),
      bgColor: Color(0xFF81C784),
      description: 'R-G test',
    ),
    PlateData(
      number: '5',
      fgColor: Color(0xFFEF5350),
      bgColor: Color(0xFF4CAF50),
      description: 'R-G test',
    ),
    PlateData(
      number: '3',
      fgColor: Color(0xFFD32F2F),
      bgColor: Color(0xFF388E3C),
      description: 'R-G test',
    ),
    PlateData(
      number: '15',
      fgColor: Color(0xFFB71C1C),
      bgColor: Color(0xFF1B5E20),
      description: 'R-G test',
    ),
    PlateData(
      number: '74',
      fgColor: Color(0xFFFF7043),
      bgColor: Color(0xFF26A69A),
      description: 'R-G test',
    ),
    PlateData(
      number: '6',
      fgColor: Color(0xFFFF5722),
      bgColor: Color(0xFF009688),
      description: 'Tracing test',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final plate = plates[plateNumber.clamp(0, plates.length - 1)];
    return CustomPaint(
      size: Size(size, size),
      painter: _PlatePainter(
        plate: plate,
        seed: plateNumber * 100 + 7,
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter({
    required this.plate,
    required this.seed,
  });

  final PlateData plate;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2;

    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..color = const Color(0xFFF1F4FB),
    );

    final boundary = radius * 0.95;
    const dots = 520;
    for (var i = 0; i < dots; i++) {
      double x;
      double y;
      do {
        x = random.nextDouble() * size.width;
        y = random.nextDouble() * size.height;
      } while ((x - cx) * (x - cx) + (y - cy) * (y - cy) > boundary * boundary);

      final dotR = 3.6 + random.nextDouble() * 5.2;
      final isNumber = _isInNumberRegion(x, y, size);

      final base = isNumber ? plate.fgColor : plate.bgColor;
      final varied = _vary(base, random);
      canvas.drawCircle(
        Offset(x, y),
        dotR,
        Paint()..color = varied,
      );
    }

    // Soft rim
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.98,
      Paint()
        ..color = const Color(0x330B1020)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  Color _vary(Color base, math.Random random) {
    int tweak(int v) => (v + random.nextInt(22) - 11).clamp(0, 255);
    int channel(double value) => ((value * 255.0).round() & 0xff);
    return Color.fromARGB(
      channel(base.a),
      tweak(channel(base.r)),
      tweak(channel(base.g)),
      tweak(channel(base.b)),
    );
  }

  bool _isInNumberRegion(double x, double y, Size size) {
    final digits = plate.number.split('');
    final cx = size.width / 2;
    final cy = size.height / 2;

    final digitW = size.width * 0.16;
    final digitH = size.width * 0.28;
    final gap = size.width * 0.04;
    final totalW = digits.length * digitW + (digits.length - 1) * gap;
    final startX = cx - totalW / 2;

    for (var i = 0; i < digits.length; i++) {
      final dx = startX + i * (digitW + gap) + digitW / 2;
      if (_isInDigit(x, y, dx, cy, digitW, digitH, digits[i])) {
        return true;
      }
    }
    return false;
  }

  bool _isInDigit(
    double px,
    double py,
    double dx,
    double dy,
    double w,
    double h,
    String digit,
  ) {
    final rx = px - dx;
    final ry = py - dy;

    bool segTop() => ry.abs() < h * 0.07 && rx.abs() < w * 0.45;
    bool segMid() => (ry).abs() < h * 0.07 && rx.abs() < w * 0.45;
    bool segBot() => (ry - h * 0.38).abs() < h * 0.07 && rx.abs() < w * 0.45;
    bool segLeftUpper() => (rx + w * 0.40).abs() < w * 0.10 && ry > -h * 0.40 && ry < -h * 0.05;
    bool segRightUpper() => (rx - w * 0.40).abs() < w * 0.10 && ry > -h * 0.40 && ry < -h * 0.05;
    bool segLeftLower() => (rx + w * 0.40).abs() < w * 0.10 && ry > h * 0.05 && ry < h * 0.40;
    bool segRightLower() => (rx - w * 0.40).abs() < w * 0.10 && ry > h * 0.05 && ry < h * 0.40;

    switch (digit) {
      case '1':
        return (rx).abs() < w * 0.10 && ry.abs() < h * 0.45;
      case '2':
        return segTop() || segRightUpper() || segMid() || segLeftLower() || segBot();
      case '3':
        return segTop() || segRightUpper() || segMid() || segRightLower() || segBot();
      case '4':
        return segLeftUpper() || segMid() || segRightUpper() || segRightLower();
      case '5':
        return segTop() || segLeftUpper() || segMid() || segRightLower() || segBot();
      case '6':
        return segTop() || segLeftUpper() || segMid() || segLeftLower() || segRightLower() || segBot();
      case '7':
        return segTop() || segRightUpper() || segRightLower();
      case '8':
        return segTop() ||
            segMid() ||
            segBot() ||
            segLeftUpper() ||
            segRightUpper() ||
            segLeftLower() ||
            segRightLower();
      case '9':
        return segTop() || segMid() || segBot() || segLeftUpper() || segRightUpper() || segRightLower();
      default:
        return rx.abs() < w * 0.30 && ry.abs() < h * 0.35;
    }
  }

  @override
  bool shouldRepaint(covariant _PlatePainter oldDelegate) {
    return oldDelegate.plate.number != plate.number || oldDelegate.seed != seed;
  }
}
