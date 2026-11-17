import 'dart:math' as math;
import 'package:flutter/material.dart';

const givingBurgundy = Color(0xFF652B3F);
const givingCream = Color(0xFFFBF5E9);
const givingBrown = Color(0xFF875C43);

/// A gift rising from open hands, with quiet rays rather than flashing confetti.
class GivingArtwork extends StatelessWidget {
  final double progress;
  const GivingArtwork({super.key, this.progress = 1});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(
          size: const Size(180, 160), painter: _GivingPainter(progress)));
}

class _GivingPainter extends CustomPainter {
  final double progress;
  _GivingPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 160);
    final p = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    canvas.drawCircle(
        const Offset(90, 77), 53, Paint()..color = const Color(0xFFF1E3D1));
    final ray = Paint()
      ..color = givingBrown.withOpacity(.45 * p)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final a = math.pi + i * math.pi / 8;
      final r = 54 + 7 * p;
      canvas.drawLine(Offset(90 + math.cos(a) * r, 79 + math.sin(a) * r),
          Offset(90 + math.cos(a) * (r + 5), 79 + math.sin(a) * (r + 5)), ray);
    }
    canvas.save();
    canvas.translate(0, 15 * (1 - p));
    final heart = Path()
      ..moveTo(90, 94)
      ..cubicTo(80, 84, 60, 72, 60, 58)
      ..cubicTo(60, 40, 81, 37, 90, 52)
      ..cubicTo(99, 37, 120, 40, 120, 58)
      ..cubicTo(120, 72, 100, 84, 90, 94)
      ..close();
    canvas.drawPath(
        heart, Paint()..color = givingBurgundy.withOpacity(.3 + .7 * p));
    canvas.restore();
    final hands = Path()
      ..moveTo(24, 114)
      ..lineTo(41, 101)
      ..quadraticBezierTo(48, 95, 57, 100)
      ..lineTo(78, 113)
      ..quadraticBezierTo(90, 120, 102, 113)
      ..lineTo(123, 100)
      ..quadraticBezierTo(132, 95, 139, 101)
      ..lineTo(156, 114)
      ..lineTo(140, 136)
      ..quadraticBezierTo(90, 160, 40, 136)
      ..close();
    canvas.drawPath(hands, Paint()..color = const Color(0xFFE4C3A3));
    final outline = Paint()
      ..color = givingBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(hands, outline);
    canvas.drawPath(
        Path()
          ..moveTo(50, 113)
          ..lineTo(70, 125)
          ..quadraticBezierTo(90, 137, 110, 125)
          ..lineTo(130, 113),
        outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GivingPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
