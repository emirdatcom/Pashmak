import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokens {
  const Tokens({required this.access, required this.accessExpiresAt, required this.refresh, required this.userId});
  final String access;
  final DateTime accessExpiresAt;
  final String refresh;
  final String userId;
}

/// Minimal key-value port so tests do not need the Keystore.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSecretStore implements SecretStore {
  const SecureSecretStore([this._s = const FlutterSecureStorage()]);
  final FlutterSecureStorage _s;
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

/// Stores access/refresh tokens in secure storage (docs/80 §2).
class TokenStore {
  TokenStore(this._store);
  final SecretStore _store;

  Future<Tokens?> read() async {
    final a = await _store.read('access_token');
    final r = await _store.read('refresh_token');
    final e = await _store.read('access_expires_at');
    final u = await _store.read('user_id');
    if (a == null || r == null || e == null || u == null) return null;
    return Tokens(access: a, accessExpiresAt: DateTime.parse(e), refresh: r, userId: u);
  }

  Future<void> write(Tokens t) async {
    await _store.write('access_token', t.access);
    await _store.write('refresh_token', t.refresh);
    await _store.write('access_expires_at', t.accessExpiresAt.toUtc().toIso8601String());
    await _store.write('user_id', t.userId);
  }

  Future<void> clear() async {
    for (final k in ['access_token', 'refresh_token', 'access_expires_at', 'user_id']) {
      await _store.delete(k);
    }
  }
}
