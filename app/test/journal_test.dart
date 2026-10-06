import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/features/journal/domain/journal.dart';

import 'core_loop_helpers.dart';

void main() {
  DateTime at(int d) => DateTime(2026, 10, d, 9);

  test('a structured entry is stored on its session and read back with its answers', () async {
    final l = Loop(at(5));
    final repo = JournalRepository(l.db);
    final t = JournalTemplate.all.firstWhere((t) => t.key == 'worry');
    final id = await l.exercises.start(t.exerciseKey);
    final r = await l.exercises.complete(id, durationS: 0, journalText: encodeJournal('worry', {'worry': 'امتحان', 'control': 'yes', 'step': 'یه ساعت درس', 'let_go': ''}));
    expect(r.rewarded, isTrue, reason: 'journals earn energy like exercises');
    final entries = await repo.watch().first;
    expect(entries.single.template?.key, 'worry');
    expect(entries.single.answers, {'worry': 'امتحان', 'control': 'yes', 'step': 'یه ساعت درس'}, reason: 'empty answers are dropped');
  });

  test('conditional fields follow the choice', () {
    final t = JournalTemplate.all.firstWhere((t) => t.key == 'worry');
    expect(t.visible({'control': 'no'}).map((f) => f.key), ['worry', 'control', 'let_go']);
    expect(t.visible({'control': 'yes'}).map((f) => f.key), ['worry', 'control', 'step']);
    expect(t.visible({}).map((f) => f.key), ['worry', 'control']);
  });

  test('prompt-exercise text shows as a plain entry; deleting keeps the completed session', () async {
    final l = Loop(at(5));
    final repo = JournalRepository(l.db);
    final id = await l.exercises.start('gratitude');
    await l.exercises.complete(id, durationS: 60, journalText: 'چای صبح');
    final e = (await repo.watch().first).single;
    expect((e.text, e.template), ('چای صبح', null));
    await repo.deleteText(e.sessionId);
    expect(await repo.watch().first, isEmpty);
    expect((await l.db.select(l.db.exerciseSessions).getSingle()).completedAt, isNotNull);
  });
}
