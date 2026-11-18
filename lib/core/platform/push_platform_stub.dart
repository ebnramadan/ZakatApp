String get pushSupport => 'unsupported';
String get pushPermission => 'default';
Future<bool> syncPushSession(String? uid,
        {Map<String, dynamic>? preferences}) async =>
    false;
Future<Map<String, dynamic>?> currentPushSubscription() async => null;
Future<Map<String, dynamic>> subscribePush(String key) async =>
    throw UnsupportedError('Push is available in supported web browsers.');
Future<void> unsubscribePush() async {}
Future<void> showPushTest(String title, String body, {String? uid}) async {}

Future<void> refreshPushWorker() async {}

void clearNotificationLink() {}
