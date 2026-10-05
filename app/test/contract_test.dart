import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static contract checks between the app, `backend/api/openapi.yaml` and `config-data` (prompt 20 §1).
void main() {
  Set<String> openApiOperations() {
    final ops = <String>{};
    String? path;
    var inPaths = false;
    for (final line in File('../backend/api/openapi.yaml').readAsLinesSync()) {
      if (line.startsWith('paths:')) {
        inPaths = true;
        continue;
      }
      if (inPaths && line.isNotEmpty && !line.startsWith(' ')) inPaths = false;
      if (!inPaths) continue;
      final p = RegExp(r'^  (/[^\s:]+):\s*$').firstMatch(line);
      if (p != null) path = p.group(1);
      final m = RegExp(r'^    (get|post|put|delete|patch):').firstMatch(line);
      if (m != null && path != null) ops.add('${m.group(1)!.toUpperCase()} $path');
    }
    return ops;
  }

  Iterable<File> dartFiles(String dir) => Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  test('every API call in lib/ exists in openapi.yaml with the same method', () {
    final ops = openApiOperations();
    expect(ops, isNotEmpty);
    final calls = <String>{};
    for (final f in dartFiles('lib')) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r"""request(?:<[^(]*>)?\(\s*'(GET|POST|PUT|DELETE|PATCH)',\s*'(/v1/[^'?]+)'""").allMatches(src)) {
        calls.add('${m.group(1)} ${m.group(2)}');
      }
    }
    expect(calls, isNotEmpty);
    final missing = calls.where((c) => !ops.contains(c)).toList();
    expect(missing, isEmpty, reason: 'app calls an operation the OpenAPI contract does not define');
    // The calls the product depends on must be present in the app at all.
    for (final must in ['GET /v1/config', 'GET /v1/content/manifest', 'GET /v1/entitlements', 'POST /v1/trial/start', 'POST /v1/purchases/verify', 'POST /v1/purchases/restore', 'POST /v1/events', 'DELETE /v1/me']) {
      expect(calls, contains(must), reason: 'the app should implement $must');
    }
  });

  test('every /v1 path literal in lib/ (auth included) is defined by the contract', () {
    final paths = openApiOperations().map((o) => o.split(' ').last).toSet();
    for (final f in dartFiles('lib')) {
      for (final m in RegExp(r"'(/v1/[A-Za-z0-9_/\-]+)'").allMatches(f.readAsStringSync())) {
        expect(paths, contains(m.group(1)), reason: '${f.path} uses ${m.group(1)}');
      }
    }
  });

  test('config-data/config/default.json and the AppConfig getters cover each other', () {
    final raw = jsonDecode(File('../config-data/config/default.json').readAsStringSync()) as Map<String, dynamic>;
    final leaves = <String>[];
    void walk(String prefix, Object? v) {
      if (v is Map<String, dynamic> && v.isNotEmpty) {
        v.forEach((k, x) => walk(prefix.isEmpty ? k : '$prefix.$k', x));
      } else {
        leaves.add(prefix);
      }
    }

    walk('', raw);
    final src = File('lib/core/config/app_config.dart').readAsStringSync();
    final accessors = RegExp(r"_(?:get|strings)(?:<[^(]*>)?\('([a-z0-9_.]+)'\)").allMatches(src).map((m) => m.group(1)!).toSet();
    bool covered(String leaf) => accessors.any((a) => leaf == a || leaf.startsWith('$a.'));
    expect(leaves.where((l) => !covered(l)), isEmpty, reason: 'keys in default.json that no AppConfig getter reads');
    bool exists(String a) {
      Object? cur = raw;
      for (final p in a.split('.')) {
        if (cur is! Map<String, dynamic> || !cur.containsKey(p)) return false;
        cur = cur[p];
      }
      return true;
    }

    expect(accessors.where((a) => !exists(a)), isEmpty, reason: 'AppConfig getters whose key is missing from default.json');
  });

  test('the AnalyticsEvent enum covers the client events of config-data/analytics/events.json', () {
    final cat = jsonDecode(File('../config-data/analytics/events.json').readAsStringSync()) as Map<String, dynamic>;
    final names = [for (final e in (cat['events'] as List).cast<Map<String, dynamic>>()) if (e['server_side'] != true) e['name'] as String];
    final src = File('lib/core/analytics/analytics_event.dart').readAsStringSync();
    for (final n in names) {
      expect(src, contains("'$n'"), reason: 'enum is missing $n (run tool/gen_analytics_events.dart)');
    }
  });
}
