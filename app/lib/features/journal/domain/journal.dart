import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

enum JournalFieldType { text, list3, intensity, choice }

/// One question of a structured journal. Copy: `journal.<template>.<key>` (+ `.hint`, `.opt.<option>`).
class JournalField {
  const JournalField(this.key, this.type, {this.options = const [], this.showIf});
  final String key;
  final JournalFieldType type;
  final List<String> options;

  /// Shown only when another choice field has this value: `(field, value)`.
  final (String, String)? showIf;
}

/// A structured journal. Each entry is an exercise session `journal_<key>` whose `journal_text` holds the answers
/// as JSON, so rewards, streak, backup and export need nothing new.
class JournalTemplate {
  const JournalTemplate(this.key, this.icon, this.fields, {this.premium = false});
  final String key;
  final String icon;
  final List<JournalField> fields;
  final bool premium;

  String get exerciseKey => 'journal_$key';

  static const all = [
    JournalTemplate('gratitude', 'hands/folded_hands', [
      JournalField('things', JournalFieldType.list3),
      JournalField('why', JournalFieldType.text),
    ]),
    JournalTemplate('talk', 'connection/speech_bubble', [
      JournalField('mind', JournalFieldType.text),
      JournalField('more', JournalFieldType.text),
      JournalField('need', JournalFieldType.text),
    ]),
    JournalTemplate('reframe', 'body/brain', [
      JournalField('situation', JournalFieldType.text),
      JournalField('thought', JournalFieldType.text),
      JournalField('feeling', JournalFieldType.intensity),
      JournalField('for', JournalFieldType.text),
      JournalField('against', JournalFieldType.text),
      JournalField('balanced', JournalFieldType.text),
      JournalField('feeling_after', JournalFieldType.intensity),
    ], premium: true),
    JournalTemplate('highlight', 'misc/star_badge', [
      JournalField('moment', JournalFieldType.text),
      JournalField('mood', JournalFieldType.choice, options: ['calm', 'happy', 'proud', 'grateful', 'tired']),
      JournalField('again', JournalFieldType.text),
    ], premium: true),
    JournalTemplate('worry', 'misc/hourglass', [
      JournalField('worry', JournalFieldType.text),
      JournalField('control', JournalFieldType.choice, options: ['yes', 'partly', 'no']),
      JournalField('step', JournalFieldType.text, showIf: ('control', 'yes')),
      JournalField('step_partly', JournalFieldType.text, showIf: ('control', 'partly')),
      JournalField('let_go', JournalFieldType.text, showIf: ('control', 'no')),
    ], premium: true),
  ];

  static JournalTemplate? byExercise(String exerciseKey) => all.where((t) => t.exerciseKey == exerciseKey).firstOrNull;

  /// Fields to ask given the answers so far (conditional ones appear once their condition holds).
  List<JournalField> visible(Map<String, Object?> answers) => [for (final f in fields) if (f.showIf == null || answers[f.showIf!.$1] == f.showIf!.$2) f];
}

/// Encodes answers for `exercise_sessions.journal_text`.
String encodeJournal(String template, Map<String, Object?> answers) =>
    jsonEncode({'v': 1, 'kind': template, 'fields': {for (final e in answers.entries) if (!_empty(e.value)) e.key: e.value}});

bool _empty(Object? v) => v == null || (v is String && v.trim().isEmpty) || (v is List && v.every((x) => '$x'.trim().isEmpty));

/// A stored journal entry: structured (template + answers) or free text from a prompt exercise.
class JournalEntry {
  const JournalEntry({required this.sessionId, required this.exerciseKey, required this.localDay, required this.at, this.template, this.answers = const {}, this.text});
  final String sessionId;
  final String exerciseKey;
  final String localDay;
  final DateTime at;
  final JournalTemplate? template;
  final Map<String, Object?> answers;
  final String? text;

  static JournalEntry? fromSession(ExerciseSession s) {
    final raw = s.journalText;
    if (raw == null || raw.trim().isEmpty) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(s.completedAt ?? s.startedAt);
    if (raw.startsWith('{')) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final t = JournalTemplate.all.where((x) => x.key == j['kind']).firstOrNull;
        if (t != null) {
          return JournalEntry(sessionId: s.id, exerciseKey: s.exerciseKey, localDay: s.localDay, at: at, template: t, answers: (j['fields'] as Map).cast<String, Object?>());
        }
      } on FormatException {
        // not JSON after all: show it as text
      }
    }
    return JournalEntry(sessionId: s.id, exerciseKey: s.exerciseKey, localDay: s.localDay, at: at, text: raw);
  }
}

/// Reads and edits the journal (sessions that carry text).
class JournalRepository {
  JournalRepository(this._db);
  final AppDatabase _db;

  Stream<List<JournalEntry>> watch() => (_db.select(_db.exerciseSessions)
        ..where((s) => s.journalText.isNotNull() & s.completedAt.isNotNull())
        ..orderBy([(s) => OrderingTerm.desc(s.completedAt)]))
      .watch()
      .map((rows) => [for (final r in rows) ?JournalEntry.fromSession(r)]);

  /// Removes the text of an entry (the completed session and its reward stay).
  Future<void> deleteText(String sessionId) =>
      (_db.update(_db.exerciseSessions)..where((s) => s.id.equals(sessionId))).write(const ExerciseSessionsCompanion(journalText: Value(null)));
}
