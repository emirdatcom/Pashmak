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
                width: 40,
                child: Stack(alignment: Alignment.center, children: [
                  // The dashed line runs from the centre of the first marker to the centre of the last.
                  Positioned.fill(
                    child: Column(children: [
                      Expanded(child: i == 0 ? const SizedBox() : CustomPaint(painter: _DashedLine(), size: const Size(2, double.infinity))),
                      Expanded(child: i == rows.length - 1 ? const SizedBox() : CustomPaint(painter: _DashedLine(), size: const Size(2, double.infinity))),
                    ]),
                  ),
                  _Marker(done: rows[i].$1),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: rows[i].$2)),
            ]),
          ),
      ]);
}

class _Marker extends StatelessWidget {
  const _Marker({required this.done});
  final bool done;
  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, color: done ? DS.questDone : DS.questMarker, border: Border.all(color: DS.onDark, width: 3)),
        child: done ? const Icon(Icons.check_rounded, size: 20, color: DS.onDark) : null,
      );
}

class _DashedLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = DS.onDark
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (double y = 2; y < size.height; y += 9) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, (y + 4).clamp(0, size.height)), p);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => false;
}
