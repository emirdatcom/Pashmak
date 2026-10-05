import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/time/local_day.dart';
import 'package:pashmak_app/features/habits/domain/habit_service.dart';
import 'package:pashmak_app/features/stats/domain/insights.dart';
import 'package:pashmak_app/features/stats/presentation/charts/charts.dart';

import 'core_loop_helpers.dart';

void main() {
  final monday = DateTime(2026, 10, 5, 12);
  LocalDay day(int d) => LocalDay.fromDate(DateTime(2026, 10, d));

  test('range days: Saturday-first week and the whole Jalali month', () {
    final w = rangeDays(StatsRange.week, day(5));
    expect((w.first.value, w.last.value), ('2026-10-03', '2026-10-09'));
    final m = rangeDays(StatsRange.month, day(5)); // 13 Mehr 1405: Mehr has 30 days (23 Sep – 22 Oct)
    expect(m, hasLength(30));
    expect((m.first.value, m.last.value), ('2026-09-23', '2026-10-22'));
  });

  group('InsightMath', () {
    test('average per day over several check-ins', () {
      final a = InsightMath.averageByDay([(day: '2026-10-05', mood: 2), (day: '2026-10-05', mood: 4), (day: '2026-10-06', mood: 5)]);
      expect(a, {'2026-10-05': 3.0, '2026-10-06': 5.0});
    });

    test('best weekday needs enough samples and picks the highest average', () {
      // Mondays (2026-10-05, 12, 19) mood 5; Tuesdays (06, 13, 20) mood 2; Wednesday only one sample.
      final by = {for (final d in [5, 12, 19]) '2026-10-${d.toString().padLeft(2, '0')}': 5.0, for (final d in [6, 13, 20]) '2026-10-${d.toString().padLeft(2, '0')}': 2.0, '2026-10-07': 5.0};
      expect(InsightMath.bestWeekday(by), LocalDay.fromDate(DateTime(2026, 10, 5)).weekdayIndex);
      expect(InsightMath.bestWeekday({'2026-10-05': 5.0, '2026-10-12': 5.0}), isNull, reason: 'two samples are not enough');
    });

    test('habit ↔ mood difference needs five days each side and a clear gap', () {
      final by = {for (var i = 1; i <= 10; i++) '2026-10-${i.toString().padLeft(2, '0')}': i <= 5 ? 4.5 : 3.0};
      final done = {for (var i = 1; i <= 5; i++) '2026-10-${i.toString().padLeft(2, '0')}'};
      expect(InsightMath.moodDifference(by, done), closeTo(1.5, 1e-9));
      expect(InsightMath.moodDifference(by, {'2026-10-01', '2026-10-02'}), isNull, reason: 'too few done days');
      expect(InsightMath.moodDifference({for (final e in by.keys) e: 3.0}, done), isNull, reason: 'no gap');
      expect(InsightMath.moodDifference(by, {for (final k in by.keys.skip(5)) k}), isNull, reason: 'the habit days had LOWER mood');
    });
  });

  test('service: mood series, heatmap rows and a correlation from synthetic data', () async {
    final l = Loop(monday, dayStartHour: 0);
    final walk = await l.habits.create(const HabitDraft(templateKey: 'walk'));
    // 14 days back: walked on days with mood 5, not walked on days with mood 2
    for (var i = 0; i < 14; i++) {
      l.clock.set(monday.subtract(Duration(days: i)));
      final walked = i.isEven;
      if (walked) await l.habits.complete(walk);
      await l.checkins.submit(walked ? 5 : 2);
    }
    l.clock.set(monday);
    final ins = await InsightsService(l.db).compute(StatsRange.week, LocalDay.fromDate(monday));
    expect(ins.mood.where((p) => p.mood != null), isNotEmpty);
    expect(ins.heat.single.done.length, 7);
    expect(ins.heat.single.done.where((d) => d), isNotEmpty);
    expect(ins.correlations.single.habit.id, walk);
    expect(ins.correlations.single.difference, closeTo(3.0, 1e-9));
  });

  testWidgets('charts paint without errors in RTL, including gaps', (tester) async {
    final pts = [for (var i = 0; i < 7; i++) MoodPoint(day(3 + i), i == 2 ? null : 1.0 + i % 5)];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        MoodLineChart(points: pts, color: Colors.orange, gridColor: Colors.grey),
        const HabitHeatmap(rows: [], on: Colors.teal, off: Colors.grey),
      ]),
    ));
    expect(tester.takeException(), isNull);
    final p = MoodLinePainter(pts, Colors.orange, Colors.grey, rtl: true);
    expect(p.x(0, 100), 100, reason: 'RTL: the first day sits at the right edge');
    expect(p.x(6, 100), 0);
    expect(MoodLinePainter(pts, Colors.orange, Colors.grey, rtl: false).x(0, 100), 0);
  });
}
