import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/00 §2: no user-facing Persian text in code; everything goes through `copy.t(...)`.
void main() {
  test('no Persian/Arabic characters in lib/features or lib/app.dart', () {
    final re = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');
    final offenders = <String>[];
    final files = [
      ...Directory('lib/features').listSync(recursive: true).whereType<File>(),
      File('lib/app.dart'),
    ].where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.trimLeft().startsWith('//') || l.trimLeft().startsWith('///')) continue;
        if (re.hasMatch(l)) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'Move these strings to config-data/content/copy_fa.json');
  });
}
