import '../../../core/widgets/cat_renderer.dart';

export '../../../core/widgets/cat_renderer.dart' show CatStage;

/// Cat growth (docs/22 §9): `kitten` → `young` → `adult` by completed adventures.

class CatGrowth {
  const CatGrowth({required this.young, required this.adult});
  final int young;
  final int adult;

  CatStage stageFor(int adventuresCount) => adventuresCount >= adult ? CatStage.adult : (adventuresCount >= young ? CatStage.young : CatStage.kitten);

  /// Stage reached by going from [before] to [after] adventures, or null when the stage did not change.
  CatStage? upgrade(int before, int after) {
    final a = stageFor(before), b = stageFor(after);
    return b.index > a.index ? b : null;
  }
}
