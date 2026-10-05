import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum SceneTime { morning, day, evening, night }

/// Home/shop scene: sky + ground layers that change with the time of day, the hero (the cat) in the middle.
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
          if (paintScene) Positioned(left: 0, right: 0, bottom: 0, height: height * 0.38, child: const ColoredBox(color: DS.bgHomeGround)),
          if (paintScene) Positioned(left: 0, right: 0, bottom: height * 0.38 - 12, height: 24, child: const DecoratedBox(decoration: BoxDecoration(color: DS.bgHomeGround, borderRadius: BorderRadius.all(Radius.elliptical(400, 24))))),
          Align(alignment: Alignment(0, paintScene ? 0.45 : 0.9), child: child),
          if (overlay != null) Positioned.fill(child: overlay!),
        ]),
      );
}
