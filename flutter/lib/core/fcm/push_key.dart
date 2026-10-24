import 'package:firebase_messaging/firebase_messaging.dart';

/// Clave canónica y estable para deduplicar un push entre isolates.
/// Prioriza `notification_log_id` (único por envío, siempre presente).
String canonicalPushKey(RemoteMessage message) {
  final logId = message.data['notification_log_id']?.toString();
  if (logId != null && logId.isNotEmpty) return 'log:$logId';
  final msgId = message.messageId;
  if (msgId != null && msgId.isNotEmpty) return 'msg:$msgId';
  final titulo = message.data['titulo']?.toString() ?? '';
  final body = message.data['body']?.toString() ?? '';
  return 'fb:$titulo|$body';
}
