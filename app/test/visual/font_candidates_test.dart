import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the real headline strings in each candidate font into docs/font-candidates.png (prompt 23 §4).
/// Manual tool: `FONT_DIR=/path/with/*-sub.ttf flutter test --update-goldens test/visual/font_candidates_test.dart`.
void main() {
  final dir = Platform.environment['FONT_DIR'];
  final candidates = {
    'Lalezar': 'Lalezar-sub.ttf',
    'BalooBhaijaan2': 'Baloo-sub.ttf',
    'Rakkas': 'Rakkas-sub.ttf',
    'Vazirmatn Bold (baseline)': '',
  };
  testWidgets('font candidates sheet', (tester) async {
    for (final e in candidates.entries) {
      if (e.value.isEmpty) continue;
      final l = FontLoader(e.key)..addFont(Future.value(ByteData.sublistView(File('$dir/${e.value}').readAsBytesSync())));
      await l.load();
    }
    final v = FontLoader('Vazirmatn')..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Vazirmatn-Bold.ttf').readAsBytesSync())));
    await v.load();
    tester.view.physicalSize = const Size(1400, 1500);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const samples = ['مأموریت‌های روزانه', 'آخرین هدف امروز!', 'کیف ملوس', '۳۰۲'];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFAF7E56),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final e in candidates.entries) ...[
              Text(e.key, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white, fontSize: 14)),
              for (final s in samples)
                Text(s, style: TextStyle(fontFamily: e.value.isEmpty ? 'Vazirmatn' : e.key, fontSize: 30, color: const Color(0xFF1A2226), fontWeight: e.value.isEmpty ? FontWeight.w700 : FontWeight.w800)),
              const Divider(),
            ],
          ]),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('../../../docs/font-candidates.png'));
  }, skip: dir == null);
}
