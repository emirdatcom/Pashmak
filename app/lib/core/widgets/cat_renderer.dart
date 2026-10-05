import 'package:flutter/material.dart';

enum CatMood { happy, sleepy, sad, proud, curious, tea }

enum CatActivity { idle, eating, away, returning }

class CatVisualState {
  const CatVisualState({this.mood = CatMood.happy, this.accessories = const [], this.background, this.activity = CatActivity.idle});
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
