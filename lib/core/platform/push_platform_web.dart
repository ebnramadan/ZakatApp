// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js;
import 'dart:typed_data';

const _scope = '/push-scope/';
String get pushSupport {
  final n = html.window.navigator;
  final ios = RegExp(r'iPhone|iPad|iPod').hasMatch(n.userAgent) ||
      (n.platform == 'MacIntel' && (n.maxTouchPoints ?? 0) > 1);
  if (ios &&
      !html.window.matchMedia('(display-mode: standalone)').matches &&
      js.getProperty<Object?>(n, 'standalone') != true) return 'install';
  return n.serviceWorker != null &&
          js.hasProperty(html.window, 'PushManager') &&
          js.hasProperty(html.window, 'Notification')
      ? 'supported'
      : 'unsupported';
}

String get pushPermission => js.hasProperty(html.window, 'Notification')
    ? (html.Notification.permission ?? 'default')
    : 'denied';
Future<html.ServiceWorkerRegistration?> _registration() async {
  final container = html.window.navigator.serviceWorker;
  if (container == null) return null;
  // The generated DOM binding incorrectly assumes getRegistration never returns null.
  final registration =
      await js.promiseToFuture<html.ServiceWorkerRegistration?>(
          js.callMethod(container, 'getRegistration', [_scope]));
  // getRegistration returns the root Flutter worker when the push worker is absent.
  return registration?.scope == Uri.base.resolve(_scope).toString()
      ? registration
      : null;
}

Future<bool> syncPushSession(String? uid,
    {Map<String, dynamic>? preferences}) async {
  try {
    final registration = await _registration();
    final worker = registration?.active;
    if (worker == null) return false;
    final channel = html.MessageChannel();
    final complete = Completer<void>();
    channel.port1.onMessage.first.then((_) {
      if (!complete.isCompleted) complete.complete();
    });
    worker.postMessage(
        {'type': 'push-session', 'uid': uid, ...?preferences}, [channel.port2]);
    await complete.future.timeout(const Duration(seconds: 3));
    channel.port1.close();
    return true;
  } catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>?> currentPushSubscription() async {
  final registration = await _registration();
  final manager = registration?.pushManager;
  if (manager == null) return null;
  final sub = await js
      .promiseToFuture<Object?>(js.callMethod(manager, 'getSubscription', []));
  if (sub == null) return null;
  return Map<String, dynamic>.from(
      js.dartify(js.callMethod(sub, 'toJSON', [])) as Map);
}

Future<html.ServiceWorkerRegistration> _ensureRegistration() async {
  final registration = await html.window.navigator.serviceWorker!
      .register('/push-worker.js', {'scope': _scope});
  for (var i = 0; registration.active == null && i < 40; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (registration.active == null) {
    throw StateError('The notification service did not start.');
  }
  return registration;
}

Future<Map<String, dynamic>> subscribePush(String key) async {
  if (pushSupport != 'supported') {
    throw StateError('Push is not supported here.');
  }
  // Permission must be requested directly from the user's tap (required by iOS).
  final permission = await html.Notification.requestPermission();
  if (permission != 'granted') {
    throw StateError('Notification permission was not granted.');
  }
  final registration = await _ensureRegistration();
  final existing = await currentPushSubscription();
  if (existing != null) return existing;
  final subscription = await registration.pushManager!.subscribe({
    'userVisibleOnly': true,
    'applicationServerKey':
        Uint8List.fromList(base64Url.decode(base64Url.normalize(key))),
  });
  return Map<String, dynamic>.from(
      js.dartify(js.callMethod(subscription, 'toJSON', [])) as Map);
}

Future<void> unsubscribePush() async {
  final registration = await _registration();
  final manager = registration?.pushManager;
  if (manager == null) return;
  final sub = await js
      .promiseToFuture<Object?>(js.callMethod(manager, 'getSubscription', []));
  if (sub != null) {
    await js.promiseToFuture<Object?>(js.callMethod(sub, 'unsubscribe', []));
  }
}

Future<void> showPushTest(String title, String body) async {
  if (pushSupport != 'supported') {
    throw StateError('Push is not supported here.');
  }
  // Local testing needs OS permission, but no account settings or VAPID subscription.
  final permission = await html.Notification.requestPermission();
  if (permission != 'granted') {
    throw StateError('Notification permission was not granted.');
  }
  final registration = await _ensureRegistration();
  await registration.showNotification(title, {
    'body': body,
    'icon': '/icons/zakat-v4-192.png',
    'tag': 'ztracker-test',
    'data': {'target': 'monthly'}
  });
}
