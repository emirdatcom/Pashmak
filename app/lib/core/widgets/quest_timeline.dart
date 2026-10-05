import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Vertical timeline: a marker circle per row (tick when done) joined by a dashed line.
class QuestTimeline extends StatelessWidget {
  const QuestTimeline({super.key, required this.rows});

  /// Each row is a (done, child) pair.
  final List<(bool, Widget)> rows;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 32,
                child: Column(children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 18),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: rows[i].$1 ? DS.progressYellow : DS.card, border: Border.all(color: DS.onDark, width: 2)),
                    child: rows[i].$1 ? const Icon(Icons.check, size: 16, color: DS.textPrimary) : null,
                  ),
                  if (i < rows.length - 1) Expanded(child: CustomPaint(painter: _DashedLine(), size: const Size(2, double.infinity))),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: rows[i].$2)),
            ]),
          ),
      ]);
}

class _DashedLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = DS.onDark
      ..strokeWidth = 2;
    for (double y = 4; y < size.height; y += 8) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, (y + 4).clamp(0, size.height)), p);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => false;
}
