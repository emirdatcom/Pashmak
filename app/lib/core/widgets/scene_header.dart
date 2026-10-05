import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum SceneTime { morning, day, evening, night }

/// Home/shop scene: a courtyard in layers (sky → far hills → wall with a tree → pond and pots → ground) so it reads
/// with the same depth as the reference forest scene. The hero (the cat) stands on the ground in front.
/// Placeholder painting until the final art exists (docs/art-brief.md).
class SceneHeader extends StatelessWidget {
  const SceneHeader({super.key, required this.child, this.time = SceneTime.day, this.height = 280, this.overlay, this.paintScene = true});
  final Widget child;
  final SceneTime time;
  final double height;
  final Widget? overlay;

  /// False when a full-screen background image is drawn behind the whole page instead.
  final bool paintScene;

  static SceneTime timeFor(int hour) => hour >= 5 && hour < 11 ? SceneTime.morning : (hour >= 11 && hour < 17 ? SceneTime.day : (hour >= 17 && hour < 21 ? SceneTime.evening : SceneTime.night));

  Color get _sky => switch (time) {
        SceneTime.morning || SceneTime.day => DS.bgHomeSky,
        SceneTime.evening => DS.bgHomeSkyEvening,
        SceneTime.night => DS.bgHomeSkyNight,
      };

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Stack(children: [
          if (paintScene) Positioned.fill(child: ColoredBox(color: _sky)),
          if (paintScene) Positioned.fill(child: CustomPaint(painter: _CourtyardPainter(night: time == SceneTime.night))),
          Align(alignment: Alignment(0, paintScene ? 0.62 : 0.9), child: child),
          if (overlay != null) Positioned.fill(child: overlay!),
        ]),
      );
}

class _CourtyardPainter extends CustomPainter {
  const _CourtyardPainter({required this.night});
  final bool night;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    Paint p(Color c) => Paint()..color = c;
    // sun / moon
    canvas.drawCircle(Offset(w * 0.2, h * 0.2), h * 0.07, p(night ? DS.onDark.withValues(alpha: 0.85) : DS.sceneSun));
    // far hills
    canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.62)
          ..quadraticBezierTo(w * 0.25, h * 0.38, w * 0.55, h * 0.58)
          ..quadraticBezierTo(w * 0.8, h * 0.42, w, h * 0.55)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        p(DS.sceneHillFar));
    // courtyard wall with a darker band
    canvas.drawRect(Rect.fromLTWH(0, h * 0.5, w, h * 0.17), p(DS.sceneWall));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.5, w, h * 0.025), p(DS.sceneWallShade));
    // tree on the right (trunk + layered foliage)
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.8, h * 0.18, w * 0.07, h * 0.5), const Radius.circular(12)), p(DS.sceneTrunk));
    for (final o in [Offset(w * 0.78, h * 0.2), Offset(w * 0.9, h * 0.25), Offset(w * 0.7, h * 0.33), Offset(w * 0.84, h * 0.38)]) {
      canvas.drawCircle(o, h * 0.13, p(DS.sceneLeaf));
    }
    canvas.drawCircle(Offset(w * 0.9, h * 0.34), h * 0.09, p(DS.sceneLeafDark));
    // bush on the left
    canvas.drawOval(Rect.fromLTWH(-w * 0.1, h * 0.46, w * 0.45, h * 0.24), p(DS.sceneLeafDark));
    canvas.drawOval(Rect.fromLTWH(w * 0.02, h * 0.4, w * 0.3, h * 0.22), p(DS.sceneLeaf));
    // ground with a soft rolling edge
    canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.72)
          ..quadraticBezierTo(w * 0.5, h * 0.64, w, h * 0.72)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        p(DS.bgHomeGround));
    // pond (hoz) with a rim, and pots
    canvas.drawOval(Rect.fromLTWH(w * 0.58, h * 0.7, w * 0.34, h * 0.09), p(DS.scenePondRim));
    canvas.drawOval(Rect.fromLTWH(w * 0.6, h * 0.715, w * 0.3, h * 0.065), p(DS.scenePond));
    for (final x in [0.08, 0.17]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * x, h * 0.66, w * 0.06, h * 0.07), const Radius.circular(8)), p(DS.scenePot));
      canvas.drawCircle(Offset(w * (x + 0.03), h * 0.65), h * 0.04, p(DS.sceneLeaf));
    }
  }

  @override
  bool shouldRepaint(_CourtyardPainter old) => old.night != night;
}
