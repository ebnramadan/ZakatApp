// ignore_for_file: avoid_web_libraries_in_flutter
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js;
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/platform/push_platform_web.dart';

void main() {
  test(
      'notification links are consumed without losing unrelated query parameters',
      () {
    final original = html.window.location.href;
    try {
      final link = Uri.parse(original).replace(queryParameters: {
        'open': 'monthly',
        'plan': 'p',
        'month': '2026-11',
        'notification': 'n',
        'keep': '1'
      });
      html.window.history.replaceState(null, '', link.toString());
      clearNotificationLink();
      expect(
          Uri.parse(html.window.location.href).queryParameters, {'keep': '1'});
      html.window.history.replaceState(
          null,
          '',
          Uri.parse(original).replace(queryParameters: {
            'open': 'tracker',
            'record': 'r',
            'notification': 'n'
          }).toString());
      clearNotificationLink();
      expect(Uri.parse(html.window.location.href).queryParameters, isEmpty);
    } finally {
      html.window.history.replaceState(null, '', original);
    }
  });

  test(
      'PushManager receives a native BufferSource with the original VAPID bytes',
      () {
    final bytes = List<int>.generate(65, (i) => i == 0 ? 4 : i);
    final options =
        pushSubscriptionOptions(base64Url.encode(bytes).replaceAll('=', ''));
    final key = js.getProperty<Object>(options, 'applicationServerKey');
    final bufferClass = js.getProperty<Object>(html.window, 'ArrayBuffer');
    expect(js.callMethod<bool>(bufferClass, 'isView', [key]), true,
        reason:
            'dart:html Map conversion silently converts typed arrays into ordinary arrays');
    expect(js.getProperty<int>(key, 'byteLength'), 65);
    expect(js.dartify(key), bytes);
    expect(js.getProperty<bool>(options, 'userVisibleOnly'), true);
  });
}
