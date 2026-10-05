import 'package:flutter/material.dart';

enum CatMood { happy, sleepy, sad, proud, curious, tea, breathing }

/// Growth stage (docs/22 §4): kitten → young → adult. Lives here so renderers need no feature imports.
enum CatStage { kitten, young, adult }

/// Fur options offered when the cat arrives (docs/22 §5).
enum CatFur { orangeCream, smokeGray, tricolor }

enum CatActivity { idle, eating, away, returning }

class CatVisualState {
  const CatVisualState({
    this.mood = CatMood.happy,
    this.accessories = const [],
    this.background,
    this.activity = CatActivity.idle,
    this.stage = CatStage.kitten,
    this.fur = CatFur.orangeCream,
    this.faceOnly = false,
  });
  final CatStage stage;
  final CatFur fur;

  /// Only the face (the breathing screen shows just a calm face at the bottom).
  final bool faceOnly;
  final CatMood mood;
  final List<String> accessories;
  final String? background;
  final CatActivity activity;
}

/// docs/20 §9. MVP: static WebP + code-driven motion (prompt 11); phase 2: Rive.
abstract class CatRenderer {
  Widget build(BuildContext context, CatVisualState state);
}

/// Temporary renderer: a labelled circle (no art yet).
class PlaceholderCatRenderer implements CatRenderer {
  const PlaceholderCatRenderer();
  @override
  Widget build(BuildContext context, CatVisualState state) => Semantics(
        label: 'cat ${state.mood.name}',
        child: CircleAvatar(radius: 48, child: Text(state.mood.name)),
      );
}
