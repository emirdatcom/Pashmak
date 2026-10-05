import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown when the bundled SQLite library has no encryption support.
class CipherUnavailableException implements Exception {
  @override
  String toString() => 'SQLCipher is not available in this SQLite build';
}

/// The Android Keystore (via flutter_secure_storage) could not provide the database key.
class KeystoreException implements Exception {
  KeystoreException(this.cause);
  final Object cause;
  @override
  String toString() => 'Keystore failure: $cause';
}

/// Holds the 32-byte database key in secure storage (docs/20 §5).
class DbKeyStore {
  DbKeyStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _k = 'db_key_v1';

  /// Returns the hex key, creating it on first use.
  Future<String> getOrCreate() async {
    try {
      var key = await _storage.read(key: _k);
      if (key == null || key.length != 64) {
        final rnd = Random.secure();
        key = List.generate(32, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
        await _storage.write(key: _k, value: key);
      }
      return key;
    } catch (e) {
      throw KeystoreException(e);
    }
  }
}

/// Opens an encrypted database file. [hexKey] is the raw 256-bit key (64 hex chars).
/// Throws [CipherUnavailableException] if the linked SQLite is not SQLCipher.
QueryExecutor openEncrypted(File file, String hexKey) {
  assert(RegExp(r'^[0-9a-f]{64}$').hasMatch(hexKey));
  return NativeDatabase(file, setup: (raw) {
    final v = raw.select('PRAGMA cipher_version');
    if (v.isEmpty) throw CipherUnavailableException();
    raw.execute("PRAGMA key = \"x'$hexKey'\";");
  });
}
