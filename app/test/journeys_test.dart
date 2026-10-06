import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/features/journal/domain/journal.dart';
import 'package:pashmak_app/features/journeys/domain/journey.dart';
import 'package:pashmak_app/features/sounds/domain/sound_mixer.dart';

import 'core_loop_helpers.dart';

void main() {
  DateTime at(int d) => DateTime(2026, 10, d, 9);

  test('one day per calendar day; finishing the journey pays once', () async {
    final l = Loop(at(5));
    final svc = JourneyService(l.db, l.wallet, today: l.today);
    final j = Journey.byKey('energy_up');
    var p = await svc.start(j);
    expect(p.isOpen(0, l.today()), isTrue);
    expect(p.isOpen(1, l.today()), isFalse);
    for (var i = 0; i < j.days[0].length; i++) {
      p = await svc.completeStep(j, 0, i);
    }
    expect(p.daysDone, 1);
    expect(p.isOpen(1, l.today()), isFalse, reason: 'the next day opens tomorrow');
    expect((await svc.completeStep(j, 1, 0)).stepDone(1, 0), isFalse, reason: 'a closed day ignores steps');
    for (var d = 1; d < j.days.length; d++) {
      l.clock.set(at(5 + d));
      expect(p.isOpen(d, l.today()), isTrue);
      for (var i = 0; i < j.days[d].length; i++) {
        p = await svc.completeStep(j, d, i);
      }
    }
    expect(p.finished, isTrue);
    expect((await l.wallet.balance()).coins, svc.rewardCoins);
    await svc.completeStep(j, j.days.length - 1, 0);
    expect((await l.wallet.balance()).coins, svc.rewardCoins, reason: 'paid once');
    expect((await svc.progress(j)).finished, isTrue, reason: 'stored');
  });

  test('every step points at real content and every day has its copy', () {
    final ex = {for (final e in (jsonDecode(File('assets/content/exercises.json').readAsStringSync())['entries'] as List)) e['key']};
    final copy = (jsonDecode(File('assets/content/copy_fa.json').readAsStringSync())['entries'] as Map).cast<String, dynamic>();
    for (final j in Journey.all) {
      expect(copy['journey.${j.key}.name'], isNotNull);
      for (var d = 0; d < j.days.length; d++) {
        expect(copy['journey.${j.key}.day.${d + 1}.tip'], isNotNull, reason: '${j.key} day ${d + 1}');
        for (final s in j.days[d]) {
          final [kind, key] = s.split(':');
          final ok = switch (kind) {
            'ex' => ex.contains(key),
            'journal' => JournalTemplate.all.any((t) => t.key == key),
            'sound' => SoundPreset.all.any((p) => p.key == key),
            _ => false,
          };
          expect(ok, isTrue, reason: '${j.key}: $s');
        }
      }
    }
  });
}
