import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/entitlement/canonical_json.dart';
import 'package:pashmak_app/core/entitlement/signature_verifier.dart';

/// Cross-language contract with the Go backend: `fixtures/entitlement_state_signed.json` is produced
/// by `go test ./internal/modules/entitlement -update` (prompt 03).
void main() {
  final fx = jsonDecode(File('../fixtures/entitlement_state_signed.json').readAsStringSync()) as Map<String, dynamic>;
  final state = fx['state'] as Map<String, dynamic>;
  final keys = EntitlementKeys.fromJson(jsonEncode({
    'keys': [
      {'kid': fx['kid'], 'public_key': fx['public_key']},
    ]
  }));

  String canon(Map<String, dynamic> s) => utf8.decode(canonicalJson(Map<String, dynamic>.of(s)..remove('signature')..remove('kid')));

  test('Dart canonicalization is byte-identical to the Go fixture', () {
    expect(canon(state), fx['canonical']);
  });

  test('server signature verifies; changing any byte is rejected', () {
    final v = SignatureVerifier(keys);
    expect(v.verify(state), isTrue);
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (s) => s['grace_days'] = 4,
      (s) => s['server_time'] = '2026-10-05T08:00:01Z',
      (s) => (s['entitlements'] as List).first['ends_at'] = '2027-01-03T08:00:01Z',
      (s) => (s['trial'] as Map)['used'] = false,
      (s) => s['signature'] = (s['signature'] as String).replaceFirst(RegExp('.'), 'A'),
      (s) => s['kid'] = 'ent-other',
      (s) => s.remove('signature'),
    ]) {
      final copy = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
      mutate(copy);
      expect(v.verify(copy), isFalse);
    }
  });

  test('canonicalization rules: sorted keys, minimal escapes, no whitespace, utf-8 order', () {
    expect(utf8.decode(canonicalJson({'b': 1, 'a': [true, null, 'x/y', 'فارسی', 'q"\\\n\u0001'], 'é': 1, 'z': {'k2': 2, 'k1': 1}})),
        '{"a":[true,null,"x/y","فارسی","q\\"\\\\\\n\\u0001"],"b":1,"z":{"k1":1,"k2":2},"é":1}');
    expect(() => canonicalJson({'x': 1.5}), throwsArgumentError);
  });
}
