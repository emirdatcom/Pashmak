import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pashmak_app/core/auth/token_store.dart';
import 'package:pashmak_app/core/network/api_error.dart';
import 'package:pashmak_app/features/social/domain/social.dart';
import 'package:pashmak_app/features/social/presentation/friends_screen.dart' show socialErrorKey;

import 'helpers.dart';

Map<String, dynamic> prof(String code, {String nick = 'سارا', String cat = 'پشمک'}) =>
    {'friend_code': code, 'nickname': nick, 'cat_name': cat, 'cat_fur': 'smokeGray', 'cat_stage': 'young', 'cat_hue': 0};

void main() {
  final t0 = DateTime.utc(2026, 10, 5, 8);
  late ApiHarness h;
  late SocialService svc;
  late List<String> calls;

  setUp(() async {
    h = ApiHarness(t0);
    await h.tokens.write(Tokens(access: 'a', accessExpiresAt: t0.add(const Duration(hours: 5)), refresh: 'r', userId: 'u1'));
    svc = SocialService(h.db, h.api, defaultCatName: 'پشمک', stage: () => 'kitten');
    calls = [];
    h.api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, hd) {
      calls.add('${o.method} ${o.path}');
      hd.next(o);
    }));
    h.mock
      ..onPut('/v1/social/me', (s) => s.reply(200, prof('ABCD2345', nick: 'من')), data: Matchers.any)
      ..onGet('/v1/social/me', (s) => s.reply(200, prof('ABCD2345', nick: 'من')))
      ..onGet('/v1/social/friends', (s) => s.reply(200, {
            'friends': [
              {...prof('QWER7890'), 'since': '2026-10-01T10:00:00Z', 'vibed_today': false},
            ]
          }))
      ..onGet('/v1/social/vibes', (s) => s.reply(200, {
            'vibes': [
              {'id': 'v1', 'kind': 'tea', 'from_code': 'QWER7890', 'from_nickname': 'سارا', 'from_cat_name': 'پشمک', 'sent_at': '2026-10-05T07:00:00Z', 'read_at': null, 'unread': true},
            ]
          }));
  });

  test('profile is pushed once, then only when what friends see changes', () async {
    await h.db.setMeta('user_name', 'یه اسم خیلی خیلی خیلی بلند برای تست');
    final s = await svc.load();
    expect(s.me.code, 'ABCD2345');
    expect(s.friends.single.profile.fur, 'smokeGray');
    expect(s.unread, 1);
    expect(calls.where((c) => c == 'PUT /v1/social/me'), hasLength(1));
    final local = await svc.localProfile();
    expect(local.nickname.runes.length, lessThanOrEqualTo(20), reason: 'server limit');
    expect(local.catName, 'پشمک', reason: 'default cat name when none was chosen');

    await svc.load();
    expect(calls.where((c) => c == 'PUT /v1/social/me'), hasLength(1), reason: 'nothing changed → GET only');
    await h.db.setMeta('cat_fur', 'tricolor');
    await svc.load();
    expect(calls.where((c) => c == 'PUT /v1/social/me'), hasLength(2));
  });

  test('stats: received vibes are counted once however often the inbox is opened; sends and friends are counted', () async {
    h.mock.onPost('/v1/social/vibes', (s) => s.reply(204, null), data: Matchers.any);
    await svc.load();
    await svc.load();
    await svc.sendVibe('QWER7890', 'hug');
    final st = await svc.stats();
    expect((st.friends, st.vibesReceived, st.vibesSent), (1, 1, 1));
  });

  test('server errors map to friendly copy', () {
    expect(socialErrorKey(ApiError(code: 'FRIEND_CODE_INVALID', status: 404)), 'social.err.code');
    expect(socialErrorKey(ApiError(code: 'VIBE_ALREADY_SENT', status: 409)), 'social.err.vibed');
    expect(socialErrorKey(ApiError(code: 'NETWORK')), 'social.err.offline');
    expect(socialErrorKey(StateError('x')), 'social.err.generic');
  });

  test('every vibe kind has a sticker and the server enum matches', () {
    expect(VibeKind.all.map((k) => k.key).toSet(), {'hug', 'sun', 'tea', 'cheer', 'star'});
  });
}
