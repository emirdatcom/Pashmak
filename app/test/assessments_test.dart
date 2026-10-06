import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/time/local_day.dart';
import 'package:pashmak_app/features/assessments/domain/assessments.dart';

import 'core_loop_helpers.dart';

void main() {
  test('scores, ranges and bands follow the published cut-offs', () {
    final who = Assessment.byKey('who5'), gad = Assessment.byKey('gad7'), phq = Assessment.byKey('phq9');
    expect((who.maxScore, gad.maxScore, phq.maxScore), (100, 21, 27));
    expect(who.score([5, 5, 5, 5, 5]), 100);
    expect(who.band(28).name, 'very_low');
    expect(who.band(52).name, 'good');
    expect([0, 4, 5, 9, 10, 14, 15, 21].map((s) => gad.band(s).name), ['minimal', 'minimal', 'mild', 'mild', 'moderate', 'moderate', 'severe', 'severe']);
    expect([4, 5, 10, 15, 20].map((s) => phq.band(s).name), ['minimal', 'mild', 'moderate', 'mod_severe', 'severe']);
    expect(gad.band(10).suggestHelp, isTrue);
  });

  test('PHQ-9 item 9 above zero always asks for the safety resources, whatever the total', () {
    final phq = Assessment.byKey('phq9');
    expect(phq.needsSafety([0, 0, 0, 0, 0, 0, 0, 0, 1]), isTrue);
    expect(phq.needsSafety([3, 3, 3, 3, 3, 3, 3, 3, 0]), isFalse);
    expect(Assessment.byKey('gad7').needsSafety([3, 3, 3, 3, 3, 3, 3]), isFalse);
  });

  test('results are stored per assessment, newest first, score only', () async {
    final l = Loop(DateTime(2026, 10, 5, 9));
    final s = AssessmentStore(l.db, l.clock);
    await s.save('gad7', 6, LocalDay.parse('2026-10-05'));
    l.clock.set(DateTime(2026, 10, 19, 9));
    await s.save('gad7', 3, LocalDay.parse('2026-10-19'));
    await s.save('who5', 64, LocalDay.parse('2026-10-19'));
    final gad = await s.watch('gad7').first;
    expect(gad.map((r) => r.score), [3, 6]);
    expect((await s.watch().first).length, 3);
  });
}
