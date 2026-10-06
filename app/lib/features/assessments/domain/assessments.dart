import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/local_day.dart';

/// A score band: from [min] (inclusive) up to the next band. Copy: `assess.<key>.band.<name>`.
class Band {
  const Band(this.min, this.name, {this.suggestHelp = false});
  final int min;
  final String name;
  final bool suggestHelp;
}

/// A validated self-check questionnaire. Copy: `assess.<key>.q.<n>` and `assess.<key>.opt.<value>`.
/// [optionValues] are listed in display order. A result is a reflection aid, never a diagnosis.
class Assessment {
  const Assessment(this.key, this.icon, this.questions, this.optionValues, this.bands, {this.multiplier = 1, this.safetyItem});
  final String key;
  final String icon;
  final int questions;
  final List<int> optionValues;
  final List<Band> bands;

  /// The raw sum is multiplied by this to give the reported score (WHO-5 reports 0..100).
  final int multiplier;

  /// 1-based question whose any non-zero answer shows the safety resources at once (PHQ-9 item 9).
  final int? safetyItem;

  int get maxScore => questions * optionValues.reduce((a, b) => a > b ? a : b) * multiplier;

  static const all = [
    // WHO-5 Well-Being Index (WHO, free to use): 0..100, higher is better; ≤ 50 low, ≤ 28 very low.
    Assessment('who5', 'faces/smiling_blush', 5, [5, 4, 3, 2, 1, 0], [Band(0, 'very_low', suggestHelp: true), Band(29, 'low'), Band(51, 'good')], multiplier: 4),
    // GAD-7 (Spitzer et al., public domain): 0..21.
    Assessment('gad7', 'body/brain', 7, [0, 1, 2, 3], [Band(0, 'minimal'), Band(5, 'mild'), Band(10, 'moderate', suggestHelp: true), Band(15, 'severe', suggestHelp: true)]),
    // PHQ-9 (Kroenke et al., public domain): 0..27; item 9 asks about thoughts of self-harm.
    Assessment('phq9', 'faces/thinking', 9, [0, 1, 2, 3],
        [Band(0, 'minimal'), Band(5, 'mild'), Band(10, 'moderate', suggestHelp: true), Band(15, 'mod_severe', suggestHelp: true), Band(20, 'severe', suggestHelp: true)],
        safetyItem: 9),
  ];

  static Assessment byKey(String key) => all.firstWhere((a) => a.key == key);

  int score(List<int> answers) => answers.fold(0, (a, b) => a + b) * multiplier;

  Band band(int score) => bands.lastWhere((b) => score >= b.min);

  bool needsSafety(List<int> answers) => safetyItem != null && answers.length >= safetyItem! && answers[safetyItem! - 1] > 0;
}

class AssessmentResult {
  const AssessmentResult(this.key, this.day, this.score, this.at);
  final String key;
  final String day; // LocalDay.value
  final int score;
  final DateTime at;
}

/// Results live only on the device (app_meta `assessment:<key>:<ms>`), are part of the encrypted backup and never
/// reach analytics. Answers are not kept, only the score.
class AssessmentStore {
  AssessmentStore(this._db, this._clock);
  final AppDatabase _db;
  final Clock _clock;

  static const prefix = 'assessment:';

  Future<AssessmentResult> save(String key, int score, LocalDay day) async {
    final now = _clock.now();
    await _db.setMeta('$prefix$key:${now.millisecondsSinceEpoch}', jsonEncode({'score': score, 'day': day.value}));
    return AssessmentResult(key, day.value, score, now);
  }

  /// Every result of [key] (or all), newest first.
  Stream<List<AssessmentResult>> watch([String? key]) => (_db.select(_db.appMeta)..where((m) => m.key.like('$prefix${key ?? ''}%'))).watch().map((rows) {
        final out = <AssessmentResult>[];
        for (final r in rows) {
          final parts = r.key.split(':');
          if (parts.length != 3) continue;
          final j = jsonDecode(r.value) as Map<String, dynamic>;
          out.add(AssessmentResult(parts[1], j['day'] as String, j['score'] as int, DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2]))));
        }
        return out..sort((a, b) => b.at.compareTo(a.at));
      });
}
