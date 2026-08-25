import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
///  Sparkline — مؤشر بياني صغير احترافي داخل الكروت
///  - بياخد سلسلة أرقام (آخر 7 أيام) ويرسمها كخط متدرج
///  - مع تعبئة متدرجة تحت الخط (gradient fill)
///  - نقطه عند آخر قيمة + خط قاعدة خفيف
/// ─────────────────────────────────────────────────────────────
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final bool showFill;
  final bool showDot;

  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.height = 34,
    this.showFill = true,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          color: color,
          showFill: showFill,
          showDot: showDot,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool showFill;
  final bool showDot;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.showFill,
    required this.showDot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) {
      // بيانات غير كافية — نرسم خط مسطح خفيف
      final baseY = size.height * 0.7;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, baseY),
        Offset(size.width, baseY),
        paint,
      );
      return;
    }

    // حساب المدى
    double minV = data.reduce((a, b) => a < b ? a : b);
    double maxV = data.reduce((a, b) => a > b ? a : b);
    if (maxV == minV) {
      maxV = minV + 1; // تجنب القسمة على صفر
    }

    final points = <Offset>[];
    final stepX = size.width / (data.length - 1);
    final range = maxV - minV;

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalized = (data[i] - minV) / range;
      final y = size.height - 4 - (normalized * (size.height - 12));
      points.add(Offset(x, y));
    }

    // ── خط القاعدة ─────────────────────────────────────
    final basePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 3),
      Offset(size.width, size.height - 3),
      basePaint,
    );

    // ── التعبئة المتدرجة تحت الخط ──────────────────────
    if (showFill) {
      final fillPath = Path()
        ..moveTo(points.first.dx, size.height - 3)
        ..lineTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath
        ..lineTo(points.last.dx, size.height - 3)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size);
      canvas.drawPath(fillPath, fillPaint);
    }

    // ── الخط نفسه ──────────────────────────────────────
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // ── نقطة آخر قيمة (الحالية) ────────────────────────
    if (showDot) {
      final last = points.last;
      // هالة
      canvas.drawCircle(
        last,
        6,
        Paint()..color = color.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        last,
        3.2,
        Paint()..color = color,
      );
      // دائرة بيضاء جوه (لمسة احترافية)
      canvas.drawCircle(
        last,
        1.4,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.showFill != showFill ||
        oldDelegate.showDot != showDot;
  }
}

/// تحويل سلسلة نصية "1,2,3" إلى قائمة أرقام
List<double> parseTrend(dynamic value) {
  if (value == null) return const [];
  final s = value.toString();
  if (s.isEmpty) return const [];

  return s
      .split(',')
      .map((e) => double.tryParse(e.trim()))
      .whereType<double>()
      .toList();
}
