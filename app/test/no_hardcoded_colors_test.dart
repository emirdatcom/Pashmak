import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/22 rules: no colour literals outside the theme folder, and the internal reference screenshots never
/// ship inside the app.
void main() {
  test('no Color(0x…) or Colors.* outside core/theme (tokens only)', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('/core/theme/') || f.path.endsWith('.g.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'Color\(0x|(?<![A-Za-z])Colors\.(?!transparent)[a-z]').hasMatch(lines[i])) bad.add('${f.path}:${i + 1}');
      }
    }
    expect(bad, isEmpty);
  });

  test('input/reference is not part of the app assets', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    expect(pub, isNot(contains('input/reference')));
    expect(Directory('assets').existsSync() && Directory('assets').listSync(recursive: true).any((e) => e.path.contains('finch')), isFalse);
  });

  test('no reference-app names anywhere in app/lib or the content packs', () {
    final re = RegExp(r'finch|sparkles|rainbow stones|micropet|prickles', caseSensitive: false);
    final hits = <String>[];
    for (final dir in ['lib', '../config-data']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!(f.path.endsWith('.dart') || f.path.endsWith('.json'))) continue;
        if (f.path.endsWith('no_hardcoded_colors_test.dart')) continue;
        if (re.hasMatch(f.readAsStringSync())) hits.add(f.path);
      }
    }
    expect(hits, isEmpty);
  });
}
