import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/analytics/analytics_service.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/features/account/phone_link_service.dart';

import 'helpers.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);

  test('phone and code cleaning: Persian digits, spaces, prefixes', () {
    expect(PhoneLinkService.cleanPhone('۰۹۱۲ ۳۴۵ ۶۷۸۹'), '09123456789');
    expect(PhoneLinkService.cleanPhone('+989123456789'), '+989123456789');
    expect(PhoneLinkService.cleanPhone('9123456789'), '9123456789');
    expect(PhoneLinkService.cleanPhone('0212345678'), isNull);
    expect(PhoneLinkService.cleanPhone('abc'), isNull);
    expect(PhoneLinkService.cleanCode('۱۲۳۴۵'), '12345');
    expect(PhoneLinkService.cleanCode('1234'), isNull);
  });

  test('otp request returns the challenge and retry delay; errors map to kind failures', () async {
    final h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 1)), refresh: 'r', userId: 'u1'));
    final svc = PhoneLinkService(h.api, h.tokens, const NoopAnalytics());
    h.mock.onPost('/v1/auth/phone/otp', (s) => s.reply(200, {'challenge_id': 'c-1', 'retry_after_s': 60}), data: {'phone': '09123456789'});
    final c = await svc.requestOtp('۰۹۱۲۳۴۵۶۷۸۹');
    expect((c.id, c.retryAfterSeconds), ('c-1', 60));

    h.mock.onPost('/v1/auth/phone/otp', (s) => s.reply(429, {'error': {'code': 'RATE_LIMITED', 'message': 'x', 'request_id': 'q'}}), data: {'phone': '09120000000'});
    await expectLater(svc.requestOtp('09120000000'), throwsA(predicate((e) => e is PhoneLinkException && e.failure == PhoneLinkFailure.rateLimited)));
    await expectLater(svc.requestOtp('123'), throwsA(predicate((e) => e is PhoneLinkException && e.failure == PhoneLinkFailure.phoneInvalid)));
  });

  test('verify stores the new session (user may change on merge) and reports merged', () async {
    final h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 1)), refresh: 'r', userId: 'u1'));
    final svc = PhoneLinkService(h.api, h.tokens, const NoopAnalytics());
    h.mock.onPost('/v1/auth/phone/verify', (s) => s.reply(200, {
          'user_id': 'u2',
          'access_token': 'a2',
          'access_expires_at': t0.add(const Duration(hours: 1)).toIso8601String(),
          'refresh_token': 'r2',
          'merged': true,
        }), data: {'challenge_id': 'c-1', 'code': '12345'});
    expect(await svc.verify('c-1', '۱۲۳۴۵'), isTrue);
    final t = (await h.tokens.read())!;
    expect((t.userId, t.access, t.refresh), ('u2', 'a2', 'r2'));

    h.mock.onPost('/v1/auth/phone/verify', (s) => s.reply(400, {'error': {'code': 'OTP_INVALID', 'message': 'x', 'request_id': 'q'}}), data: {'challenge_id': 'c-1', 'code': '00000'});
    await expectLater(svc.verify('c-1', '00000'), throwsA(predicate((e) => e is PhoneLinkException && e.failure == PhoneLinkFailure.otpInvalid)));
    expect((await h.tokens.read())!.userId, 'u2', reason: 'a failed verification keeps the session');
  });
}
