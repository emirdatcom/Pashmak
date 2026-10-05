
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/support_models.dart';

/// Thin typed wrapper over the user-facing support endpoints.
class SupportApi {
  SupportApi(this._api);
  final ApiClient _api;

  Future<SupportInfo> conversation() async {
    final r = await _api.request<Map<String, dynamic>>('GET', '/v1/support/conversation');
    return SupportInfo.fromJson(r.data!);
  }

  /// Messages after [after] (chronological). [before] pages backwards.
  Future<({List<RemoteMessage> messages, bool hasMore})> messages({String? after, String? before, int limit = 50}) async {
    final r = await _api.request<Map<String, dynamic>>('GET', '/v1/support/messages', query: {
      'after': ?after,
      'before': ?before,
      'limit': limit,
    });
    final list = (r.data!['messages'] as List).cast<Map<String, dynamic>>().map(RemoteMessage.fromJson).toList();
    return (messages: list, hasMore: r.data!['has_more'] as bool);
  }

  /// Idempotent on [clientMsgId]. Technical info headers are sent only with explicit consent.
  Future<RemoteMessage> send(String clientMsgId, String body, {bool includeDeviceMeta = false, Map<String, String> metaHeaders = const {}}) async {
    final r = await _api.request<Map<String, dynamic>>('POST', '/v1/support/messages',
        data: {'client_msg_id': clientMsgId, 'body': body, 'include_device_meta': includeDeviceMeta},
        headers: includeDeviceMeta ? metaHeaders : null);
    return RemoteMessage.fromJson(r.data!);
  }

  Future<void> markRead(String upToMessageId) =>
      _api.request<void>('POST', '/v1/support/read', data: {'up_to_message_id': upToMessageId});

  Future<void> deleteConversation() => _api.request<void>('DELETE', '/v1/support/conversation');
}

SupportFailure supportFailureOf(ApiError e) => switch (e.code) {
      'SUPPORT_DISABLED' => SupportFailure.disabled,
      'RATE_LIMITED' => SupportFailure.rateLimited,
      'INVALID_INPUT' => SupportFailure.tooLong,
      'NETWORK' => SupportFailure.offline,
      _ => SupportFailure.other,
    };

