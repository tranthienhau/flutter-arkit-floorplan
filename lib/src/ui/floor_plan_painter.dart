import 'package:flutter/material.dart';

import '../models/floor_plan.dart';

/// Draws the 2D floor plan, fitting the meter-space bounds into the canvas
/// with a margin and a faint metric grid.
class FloorPlanPainter extends CustomPainter {
  final FloorPlan plan;

  FloorPlanPainter(this.plan);

  @override
  void paint(Canvas canvas, Size size) {
    if (plan.isEmpty) return;
    const margin = 32.0;
    final b = plan.bounds;
    final spanX = b.width == 0 ? 1 : b.width;
    final spanY = b.height == 0 ? 1 : b.height;
    final scale = ((size.width - margin * 2) / spanX)
        .clamp(0.0, (size.height - margin * 2) / spanY)
        .toDouble();

    Offset toCanvas(Offset m) => Offset(
          margin + (m.dx - b.left) * scale,
          margin + (m.dy - b.top) * scale,
        );

    _drawGrid(canvas, size, b, scale, toCanvas, margin);

    final wallPaint = Paint()
      ..color = const Color(0xFF1B2A4A)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = const Color(0xFF3D7BFF);

    for (final w in plan.walls) {
      final a = toCanvas(w.start);
      final c = toCanvas(w.end);
      canvas.drawLine(a, c, wallPaint);
      canvas.drawCircle(a, 3.5, dotPaint);
      canvas.drawCircle(c, 3.5, dotPaint);

      // Length label at the wall midpoint.
      final mid = Offset((a.dx + c.dx) / 2, (a.dy + c.dy) / 2);
      _label(canvas, mid, '${w.length.toStringAsFixed(2)} m');
    }
  }

  void _drawGrid(Canvas canvas, Size size, Rect b, double scale,
      Offset Function(Offset) toCanvas, double margin) {
    final grid = Paint()
      ..color = const Color(0x11000000)
      ..strokeWidth = 1;
    for (double x = b.left.floorToDouble(); x <= b.right; x += 1) {
      final p = toCanvas(Offset(x, b.top));
      canvas.drawLine(
          Offset(p.dx, margin), Offset(p.dx, size.height - margin), grid);
    }
    for (double y = b.top.floorToDouble(); y <= b.bottom; y += 1) {
      final p = toCanvas(Offset(b.left, y));
      canvas.drawLine(
          Offset(margin, p.dy), Offset(size.width - margin, p.dy), grid);
    }
  }

  void _label(Canvas canvas, Offset at, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFF607089), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter old) => old.plan != plan;
}
