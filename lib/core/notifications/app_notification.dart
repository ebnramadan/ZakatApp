import 'notification_target.dart';

class AppNotification {
  final String id, title, body, kind;
  final DateTime sentAt;
  final int? readAt;
  final NotificationTarget target;
  const AppNotification(
      {required this.id,
      required this.title,
      required this.body,
      required this.kind,
      required this.sentAt,
      required this.target,
      this.readAt});
  factory AppNotification.fromMap(String id, Map<String, dynamic> data) =>
      AppNotification(
          id: id,
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
          kind: data['kind'] as String? ?? 'duaa',
          sentAt: DateTime.fromMillisecondsSinceEpoch(
              (data['sentAt'] as num?)?.toInt() ?? 0),
          readAt: (data['readAt'] as num?)?.toInt(),
          target: NotificationTarget(
              kind: data['kind'] == 'monthly'
                  ? 'monthly'
                  : data['kind'] == 'zakat'
                      ? 'zakat'
                      : 'home',
              notificationId: id,
              planId: NotificationTarget.safeId(data['planId']),
              recordId: NotificationTarget.safeId(data['recordId']),
              month: NotificationTarget.safeMonth(data['month'])));
  AppNotification read() => AppNotification(
      id: id,
      title: title,
      body: body,
      kind: kind,
      sentAt: sentAt,
      target: target,
      readAt: DateTime.now().millisecondsSinceEpoch);
}
