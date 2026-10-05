import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'canonical_json.dart';

/// Public keys by `kid` (two may be active during a key rotation).
class EntitlementKeys {
  EntitlementKeys(Map<String, Uint8List> keys) : _keys = keys;

  /// `{"keys":[{"kid":"ent-1","public_key":"<base64url>"}]}`
  factory EntitlementKeys.fromJson(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return EntitlementKeys({
      for (final k in (m['keys'] as List).cast<Map<String, dynamic>>()) k['kid'] as String: base64Url.decode(base64Url.normalize(k['public_key'] as String)),
    });
  }

  final Map<String, Uint8List> _keys;

  EntitlementKeys withKey(String kid, String base64UrlKey) =>
      EntitlementKeys({..._keys, kid: base64Url.decode(base64Url.normalize(base64UrlKey))});
  Uint8List? operator [](String kid) => _keys[kid];
  bool get isEmpty => _keys.isEmpty;
}

/// Verifies the Ed25519 signature of an EntitlementState (docs/10 §6.2). A state is rejected when the
/// `kid` is unknown, the signature is malformed, or any signed byte changed.
class SignatureVerifier {
  SignatureVerifier(this.keys);
  final EntitlementKeys keys;

  /// [state] is the full JSON object including `signature` and `kid`.
  bool verify(Map<String, dynamic> state) {
    final kid = state['kid'];
    final sig = state['signature'];
    if (kid is! String || sig is! String) return false;
    final pub = keys[kid];
    if (pub == null || pub.length != 32) return false;
    try {
      final body = Map<String, dynamic>.of(state)
        ..remove('signature')
        ..remove('kid');
      final sigBytes = base64Url.decode(base64Url.normalize(sig));
      if (sigBytes.length != 64) return false;
      return ed.verify(ed.PublicKey(pub), canonicalJson(body), sigBytes);
    } catch (_) {
      return false;
    }
  }
}
