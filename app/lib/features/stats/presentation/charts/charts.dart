import 'package:flutter/material.dart';

import '../../domain/insights.dart';

/// Light line chart of daily average mood (1..5). Days without a check-in leave a gap. RTL: the first day is at the right.
class MoodLineChart extends StatelessWidget {
  const MoodLineChart({super.key, required this.points, required this.color, required this.gridColor, this.height = 140});
  final List<MoodPoint> points;
  final Color color;
  final Color gridColor;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.fromHeight(height),
        painter: MoodLinePainter(points, color, gridColor, rtl: Directionality.of(context) == TextDirection.rtl),
      );
}

class MoodLinePainter extends CustomPainter {
  MoodLinePainter(this.points, this.color, this.gridColor, {required this.rtl});
  final List<MoodPoint> points;
  final Color color;
  final Color gridColor;
  final bool rtl;

  /// x of the i-th point (mirrored in RTL so time flows right → left like the rest of the UI).
  double x(int i, double w) {
    final f = points.length <= 1 ? 0.5 : i / (points.length - 1);
    return rtl ? w - f * w : f * w;
  }

  double y(double mood, double h) => h - ((mood - 1) / 4) * h;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = gridColor..strokeWidth = 1;
    for (var m = 1; m <= 5; m++) {
      canvas.drawLine(Offset(0, y(m.toDouble(), size.height)), Offset(size.width, y(m.toDouble(), size.height)), grid);
    }
    final line = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dot = Paint()..color = color;
    Offset? prev;
    for (var i = 0; i < points.length; i++) {
      final m = points[i].mood;
      if (m == null) {
        prev = null;
        continue;
      }
      final o = Offset(x(i, size.width), y(m, size.height));
      if (prev != null) canvas.drawLine(prev, o, line);
      canvas.drawCircle(o, 4, dot);
      prev = o;
    }
  }

  @override
  bool shouldRepaint(MoodLinePainter old) => old.points != points || old.color != color || old.rtl != rtl;
}

/// Habit × day grid: filled cell = done.
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({super.key, required this.rows, required this.on, required this.off, this.cell = 14});
  final List<HeatRow> rows;
  final Color on;
  final Color off;
  final double cell;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(double.infinity, rows.length * (cell + 4)),
        painter: HeatmapPainter(rows, on, off, cell, rtl: Directionality.of(context) == TextDirection.rtl),
      );
}

class HeatmapPainter extends CustomPainter {
  HeatmapPainter(this.rows, this.on, this.off, this.cell, {required this.rtl});
  final List<HeatRow> rows;
  final Color on;
  final Color off;
  final double cell;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    for (var r = 0; r < rows.length; r++) {
      final n = rows[r].done.length;
      final gap = n <= 1 ? 0.0 : ((size.width - n * cell) / (n - 1)).clamp(1.0, 6.0);
      for (var c = 0; c < n; c++) {
        final dx = c * (cell + gap);
        final left = rtl ? size.width - dx - cell : dx;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, r * (cell + 4), cell, cell), const Radius.circular(3)), Paint()..color = rows[r].done[c] ? on : off);
      }
    }
  }

  @override
  bool shouldRepaint(HeatmapPainter old) => old.rows != rows || old.on != on || old.off != off;
}
