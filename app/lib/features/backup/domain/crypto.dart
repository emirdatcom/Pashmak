import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as hash;

/// 24-character recovery code from an alphabet without look-alikes (no 0/O/1/I), shown as 6 groups of 4.
/// 24 × 5 bits = 120 bits of entropy. It never leaves the device and is never logged (docs/30 §10).
class RecoveryCode {
  RecoveryCode._();
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    final raw = String.fromCharCodes([for (var i = 0; i < 24; i++) alphabet.codeUnitAt(r.nextInt(alphabet.length))]);
    return format(raw);
  }

  static String format(String raw) => [for (var i = 0; i < raw.length; i += 4) raw.substring(i, i + 4)].join('-');

  /// Upper-cases and drops spaces/dashes; returns null when the result is not a valid code.
  static String? normalize(String input) {
    final s = input.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    if (s.length != 24 || s.runes.any((c) => !alphabet.contains(String.fromCharCode(c)))) return null;
    return s;
  }
}

class KdfParams {
  const KdfParams({required this.memoryKiB, required this.iterations, required this.parallelism, required this.salt});

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final Uint8List salt;

  static const targetMs = 2000;

  /// `X-Kdf-Params` header value (the server only checks its shape).
  String toHeader() => jsonEncode({'alg': 'argon2id', 'm': memoryKiB, 't': iterations, 'p': parallelism, 'salt': base64Url.encode(salt).replaceAll('=', '')});

  factory KdfParams.fromHeader(String header) {
    final j = jsonDecode(header) as Map<String, dynamic>;
    if (j['alg'] != 'argon2id') throw const FormatException('unsupported kdf');
    return KdfParams(
      memoryKiB: j['m'] as int,
      iterations: j['t'] as int,
      parallelism: j['p'] as int,
      salt: base64Url.decode(base64Url.normalize(j['salt'] as String)),
    );
  }

  /// Picks the largest memory cost (≤ 64 MiB) whose predicted time stays within [targetMs] on this device,
  /// measured with a small run (Argon2 time is linear in memory × iterations).
  static Future<KdfParams> calibrate({Random? random, int iterations = 3}) async {
    final r = random ?? Random.secure();
    final salt = Uint8List.fromList([for (var i = 0; i < 16; i++) r.nextInt(256)]);
    final sw = Stopwatch()..start();
    await deriveKey('calibration', KdfParams(memoryKiB: 8192, iterations: 1, parallelism: 1, salt: salt));
    final perMiB = sw.elapsedMilliseconds / 8.0; // ms for 1 MiB at t=1
    for (final m in [65536, 32768, 16384]) {
      if (perMiB * (m / 1024) * iterations <= targetMs) return KdfParams(memoryKiB: m, iterations: iterations, parallelism: 1, salt: salt);
    }
    return KdfParams(memoryKiB: 8192, iterations: iterations, parallelism: 1, salt: salt);
  }
}

class BackupDecryptError implements Exception {
  const BackupDecryptError(this.reason);
  final String reason; // wrong_code | corrupt
  @override
  String toString() => 'BackupDecryptError($reason)';
}

Future<List<int>> _argon(List<Object> a) async {
  final p = a[1] as KdfParams;
  final key = await Argon2id(memory: p.memoryKiB, iterations: p.iterations, parallelism: p.parallelism, hashLength: 32)
      .deriveKeyFromPassword(password: a[0] as String, nonce: p.salt);
  return key.extractBytes();
}

/// Argon2id runs in a separate isolate so the UI never freezes.
Future<SecretKey> deriveKey(String code, KdfParams params) async => SecretKey(await Isolate.run(() => _argon([code, params])));

/// AES-256-GCM container: `PSBK1` | nonce(12) | ciphertext | mac(16). The schema version is authenticated.
class BackupCrypto {
  BackupCrypto._();
  static final _aes = AesGcm.with256bits();
  static const _magic = [0x50, 0x53, 0x42, 0x4b, 0x31]; // "PSBK1"

  static List<int> _aad(int schema) => utf8.encode('pashmak-backup-v1|schema=$schema');

  static Future<Uint8List> encrypt(List<int> plain, SecretKey key, int schema, {List<int>? nonce}) async {
    final box = await _aes.encrypt(plain, secretKey: key, aad: _aad(schema), nonce: nonce);
    return Uint8List.fromList([..._magic, ...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> decrypt(List<int> blob, SecretKey key, int schema) async {
    if (blob.length < _magic.length + 12 + 16 || !_startsWithMagic(blob)) throw const BackupDecryptError('corrupt');
    final nonce = blob.sublist(5, 17);
    final mac = Mac(blob.sublist(blob.length - 16));
    final cipher = blob.sublist(17, blob.length - 16);
    try {
      return Uint8List.fromList(await _aes.decrypt(SecretBox(cipher, nonce: nonce, mac: mac), secretKey: key, aad: _aad(schema)));
    } on SecretBoxAuthenticationError {
      // A wrong key and a tampered blob look the same to AES-GCM; the UI says "check the code".
      throw const BackupDecryptError('wrong_code');
    }
  }

  static bool _startsWithMagic(List<int> b) {
    for (var i = 0; i < _magic.length; i++) {
      if (b[i] != _magic[i]) return false;
    }
    return true;
  }

  static String sha256Hex(List<int> data) => hash.sha256.convert(data).toString();
}
