class NotificationTarget {
  final String kind;
  final String? planId, recordId, month, notificationId;
  const NotificationTarget(
      {this.kind = 'home',
      this.planId,
      this.recordId,
      this.month,
      this.notificationId});
  static String? safeId(Object? value) => value is String &&
          value.isNotEmpty &&
          value.length <= 200 &&
          !value.contains('/') &&
          !value.contains('\\') &&
          value != '.' &&
          value != '..'
      ? value
      : null;
  static String? safeMonth(Object? value) =>
      value is String && RegExp(r'^(20\d\d)-(0[1-9]|1[0-2])$').hasMatch(value)
          ? value
          : null;
  factory NotificationTarget.fromUri(Uri uri) => NotificationTarget(
      kind: uri.queryParameters['open'] == 'monthly'
          ? 'monthly'
          : uri.queryParameters['open'] == 'tracker'
              ? 'zakat'
              : 'home',
      planId: safeId(uri.queryParameters['plan']),
      recordId: safeId(uri.queryParameters['record']),
      month: safeMonth(uri.queryParameters['month']),
      notificationId: safeId(uri.queryParameters['notification']));
}
