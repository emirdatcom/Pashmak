import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../../core/network/api_client.dart';

/// A gesture friends send each other (once per friend per day, server enforced).
class VibeKind {
  const VibeKind(this.key, this.icon);
  final String key;
  final String icon;

  static const all = [
    VibeKind('hug', 'connection/people_hugging'),
    VibeKind('sun', 'nature/sun_face'),
    VibeKind('tea', 'food/tea_glass'),
    VibeKind('cheer', 'hands/clapping_hands'),
    VibeKind('star', 'misc/star'),
  ];

  static VibeKind of(String key) => all.firstWhere((k) => k.key == key, orElse: () => all.first);
}

/// What friends see of each other: a nickname and the cat's look. Nothing else ever leaves the phone.
class SocialProfile {
  const SocialProfile({this.code = '', required this.nickname, required this.catName, required this.fur, required this.stage, this.hue = 0});
  final String code;
  final String nickname;
  final String catName;
  final String fur;
  final String stage;
  final int hue;

  factory SocialProfile.fromJson(Map<String, dynamic> j) => SocialProfile(
      code: j['friend_code'] as String? ?? '',
      nickname: j['nickname'] as String? ?? '',
      catName: j['cat_name'] as String? ?? '',
      fur: j['cat_fur'] as String? ?? 'orangeCream',
      stage: j['cat_stage'] as String? ?? 'kitten',
      hue: (j['cat_hue'] as num?)?.toInt() ?? 0);

  Map<String, dynamic> toBody() => {'nickname': nickname, 'cat_name': catName, 'cat_fur': fur, 'cat_stage': stage, 'cat_hue': hue};
}

class Friend {
  const Friend({required this.profile, required this.since, required this.vibedToday});
  final SocialProfile profile;
  final DateTime since;
  final bool vibedToday;

  factory Friend.fromJson(Map<String, dynamic> j) =>
      Friend(profile: SocialProfile.fromJson(j), since: DateTime.parse(j['since'] as String), vibedToday: j['vibed_today'] as bool? ?? false);

  Friend copyWith({bool? vibedToday}) => Friend(profile: profile, since: since, vibedToday: vibedToday ?? this.vibedToday);
}

class ReceivedVibe {
  const ReceivedVibe({required this.id, required this.kind, required this.fromCode, required this.fromNickname, required this.fromCatName, required this.sentAt, required this.unread});
  final String id;
  final String kind;
  final String fromCode;
  final String fromNickname;
  final String fromCatName;
  final DateTime sentAt;
  final bool unread;

  factory ReceivedVibe.fromJson(Map<String, dynamic> j) => ReceivedVibe(
      id: j['id'] as String,
      kind: j['kind'] as String,
      fromCode: j['from_code'] as String? ?? '',
      fromNickname: j['from_nickname'] as String? ?? '',
      fromCatName: j['from_cat_name'] as String? ?? '',
      sentAt: DateTime.parse(j['sent_at'] as String),
      unread: j['unread'] as bool? ?? false);
}

/// Everything the friends screen shows.
class SocialSnapshot {
  const SocialSnapshot({required this.me, required this.friends, required this.vibes});
  final SocialProfile me;
  final List<Friend> friends;
  final List<ReceivedVibe> vibes;
  int get unread => vibes.where((v) => v.unread).length;
}

/// Lifetime counters kept on the phone; companions unlock from them.
class SocialStats {
  const SocialStats({this.friends = 0, this.vibesSent = 0, this.vibesReceived = 0});
  final int friends;
  final int vibesSent;
  final int vibesReceived;
}

/// Friends and good vibes over `/v1/social`. The public profile is pushed only when what friends would see changed.
class SocialService {
  SocialService(this._db, this._api, {required this.defaultCatName, required this.stage});

  final AppDatabase _db;
  final ApiClient _api;
  final String defaultCatName;
  final String Function() stage;

  static const _pushedKey = 'social_pushed';
  static const _friendsMaxKey = 'social_friends_max';
  static const _sentKey = 'social_vibes_sent';
  static const _receivedKey = 'social_vibes_received';
  static const _cursorKey = 'social_vibes_cursor';

  static String _cut(String s, int max) {
    final r = s.trim().runes.toList();
    return String.fromCharCodes(r.length > max ? r.sublist(0, max) : r);
  }

  /// The profile as it is on this phone right now.
  Future<SocialProfile> localProfile() async {
    final name = await _db.meta('cat_name') ?? '';
    return SocialProfile(
      nickname: _cut(await _db.meta('user_name') ?? '', 20),
      catName: _cut(name.isEmpty ? defaultCatName : name, 16),
      fur: await _db.meta('cat_fur') ?? 'orangeCream',
      stage: stage(),
      hue: (int.tryParse(await _db.meta('cat_hue') ?? '') ?? 0).clamp(0, 359),
    );
  }

  Future<SocialProfile> _syncMe() async {
    final local = await localProfile();
    final body = jsonEncode(local.toBody());
    if (await _db.meta(_pushedKey) == body) {
      final r = await _api.request<Map<String, dynamic>>('GET', '/v1/social/me');
      return SocialProfile.fromJson(r.data!);
    }
    final r = await _api.request<Map<String, dynamic>>('PUT', '/v1/social/me', data: local.toBody());
    await _db.setMeta(_pushedKey, body);
    return SocialProfile.fromJson(r.data!);
  }

  Future<SocialSnapshot> load() async {
    final me = await _syncMe();
    final friends = await this.friends();
    final vibes = await this.vibes();
    return SocialSnapshot(me: me, friends: friends, vibes: vibes);
  }

  Future<List<Friend>> friends() async {
    final r = await _api.request<Map<String, dynamic>>('GET', '/v1/social/friends');
    final list = [for (final f in (r.data!['friends'] as List).cast<Map<String, dynamic>>()) Friend.fromJson(f)];
    await _bumpMax(_friendsMaxKey, list.length);
    return list;
  }

  Future<List<ReceivedVibe>> vibes() async {
    final r = await _api.request<Map<String, dynamic>>('GET', '/v1/social/vibes');
    final list = [for (final v in (r.data!['vibes'] as List).cast<Map<String, dynamic>>()) ReceivedVibe.fromJson(v)];
    // count each vibe once, however often the inbox is opened
    final cursor = int.tryParse(await _db.meta(_cursorKey) ?? '') ?? 0;
    final fresh = list.where((v) => v.sentAt.millisecondsSinceEpoch > cursor).toList();
    if (fresh.isNotEmpty) {
      await _add(_receivedKey, fresh.length);
      await _db.setMeta(_cursorKey, '${fresh.map((v) => v.sentAt.millisecondsSinceEpoch).reduce((a, b) => a > b ? a : b)}');
    }
    return list;
  }

  /// Adds a friend by code; throws the server's ApiError (FRIEND_CODE_INVALID, FRIEND_LIMIT, ...).
  Future<Friend> add(String code) async {
    final r = await _api.request<Map<String, dynamic>>('POST', '/v1/social/friends', data: {'code': code.trim()});
    await friends();
    return Friend.fromJson(r.data!);
  }

  Future<void> remove(String code) => _api.request<void>('DELETE', '/v1/social/friends/{code}'.replaceFirst('{code}', Uri.encodeComponent(code)));

  Future<void> sendVibe(String code, String kind) async {
    await _api.request<void>('POST', '/v1/social/vibes', data: {'to': code, 'kind': kind});
    await _add(_sentKey, 1);
  }

  Future<void> markRead() => _api.request<void>('POST', '/v1/social/vibes/read');

  Future<SocialStats> stats() async => SocialStats(
        friends: int.tryParse(await _db.meta(_friendsMaxKey) ?? '') ?? 0,
        vibesSent: int.tryParse(await _db.meta(_sentKey) ?? '') ?? 0,
        vibesReceived: int.tryParse(await _db.meta(_receivedKey) ?? '') ?? 0,
      );

  Future<void> _add(String key, int n) async => _db.setMeta(key, '${(int.tryParse(await _db.meta(key) ?? '') ?? 0) + n}');

  Future<void> _bumpMax(String key, int n) async {
    if (n > (int.tryParse(await _db.meta(key) ?? '') ?? 0)) await _db.setMeta(key, '$n');
  }
}
