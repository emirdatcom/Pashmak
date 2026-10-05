/// Wire/domain types of the support chat (docs/10 §6.3).
class SupportInfo {
  const SupportInfo({required this.status, this.conversationId, this.unreadCount = 0, this.operatorName, this.online = false, this.nextOnlineAt});
  factory SupportInfo.fromJson(Map<String, dynamic> j) => SupportInfo(
        status: j['status'] as String,
        conversationId: j['conversation_id'] as String?,
        unreadCount: (j['unread_count'] as int?) ?? 0,
        operatorName: j['operator_display_name'] as String?,
        online: (j['online'] as bool?) ?? false,
        nextOnlineAt: j['next_online_at'] == null ? null : DateTime.parse(j['next_online_at'] as String),
      );
  final String status; // none | open | waiting_user | closed
  final String? conversationId;
  final int unreadCount;
  final String? operatorName;
  final bool online;
  final DateTime? nextOnlineAt;
}

class RemoteMessage {
  const RemoteMessage({required this.id, required this.sender, required this.body, required this.createdAt, this.readAt, this.operatorName, this.clientMsgId});
  factory RemoteMessage.fromJson(Map<String, dynamic> j) => RemoteMessage(
        id: j['id'] as String,
        sender: j['sender'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        readAt: j['read_at'] == null ? null : DateTime.parse(j['read_at'] as String),
        operatorName: j['operator_display_name'] as String?,
        clientMsgId: j['client_msg_id'] as String?,
      );
  final String id;
  final String sender;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? operatorName;
  final String? clientMsgId;
}

/// Failures the UI words kindly (copy `support.error.<reason>`).
enum SupportFailure { disabled, rateLimited, tooLong, offline, other }
