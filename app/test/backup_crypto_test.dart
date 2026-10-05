import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/features/backup/domain/crypto.dart';

void main() {
  final fast = KdfParams(memoryKiB: 64, iterations: 1, parallelism: 1, salt: Uint8List.fromList(List.generate(16, (i) => i)));

  test('recovery code: 24 unambiguous characters in groups of four, normalised on input', () {
    final code = RecoveryCode.generate(Random(1));
    expect(RegExp(r'^[A-HJ-NP-Z2-9]{4}(-[A-HJ-NP-Z2-9]{4}){5}$').hasMatch(code), isTrue, reason: code);
    expect(RecoveryCode.normalize(code.toLowerCase().replaceAll('-', ' ')), code.replaceAll('-', ''));
    expect(RecoveryCode.normalize('ABCD-EFGH'), isNull);
    expect(RecoveryCode.normalize('${'0' * 24}'), isNull, reason: '0 is not in the alphabet');
    expect({for (var i = 0; i < 50; i++) RecoveryCode.generate()}.length, 50);
  });

  test('kdf params round-trip through the header and keep the server-visible shape', () {
    final h = jsonDecode(fast.toHeader()) as Map<String, dynamic>;
    expect(h.keys.toSet(), {'alg', 'm', 't', 'p', 'salt'});
    expect(h['alg'], 'argon2id');
    final back = KdfParams.fromHeader(fast.toHeader());
    expect((back.memoryKiB, back.iterations, back.parallelism), (64, 1, 1));
    expect(back.salt, fast.salt);
  });

  test('same code and salt give the same key; another code or salt does not', () async {
    final a = await (await deriveKey('CODE', fast)).extractBytes();
    expect(await (await deriveKey('CODE', fast)).extractBytes(), a);
    expect(await (await deriveKey('OTHER', fast)).extractBytes(), isNot(a));
  });

  test('encrypt/decrypt round trip; ciphertext hides the plaintext', () async {
    final key = await deriveKey('CODE', fast);
    final plain = utf8.encode('{"note":"یادداشت خصوصی","mood":1}' * 20);
    final blob = await BackupCrypto.encrypt(plain, key, 1);
    expect(utf8.decode(blob, allowMalformed: true), isNot(contains('note')));
    expect(await BackupCrypto.decrypt(blob, key, 1), plain);
    expect(BackupCrypto.sha256Hex(blob), hasLength(64));
  });

  test('wrong key, tampered byte, wrong schema and truncated blob are all refused', () async {
    final key = await deriveKey('CODE', fast);
    final blob = await BackupCrypto.encrypt(utf8.encode('secret data here'), key, 1);
    Future<void> expectReason(Future<Object?> f, String reason) async {
      try {
        await f;
        fail('expected $reason');
      } on BackupDecryptError catch (e) {
        expect(e.reason, reason);
      }
    }

    await expectReason(BackupCrypto.decrypt(blob, await deriveKey('NOPE', fast), 1), 'wrong_code');
    final bad = Uint8List.fromList(blob)..[blob.length ~/ 2] ^= 1;
    await expectReason(BackupCrypto.decrypt(bad, key, 1), 'wrong_code');
    await expectReason(BackupCrypto.decrypt(blob, key, 2), 'wrong_code');
    await expectReason(BackupCrypto.decrypt(blob.sublist(0, 10), key, 1), 'corrupt');
  });

  test('calibration returns sane parameters within the allowed memory range', () async {
    final p = await KdfParams.calibrate(iterations: 1);
    expect([8192, 16384, 32768, 65536], contains(p.memoryKiB));
    expect(p.salt, hasLength(16));
  });
}
