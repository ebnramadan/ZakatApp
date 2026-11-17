// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js;

String? deviceTimeZone() {
  try {
    final intl = js.getProperty<Object>(html.window, 'Intl');
    final formatter = js.callMethod<Object>(intl, 'DateTimeFormat', []);
    final options = js.callMethod<Object>(formatter, 'resolvedOptions', []);
    return js.getProperty<String?>(options, 'timeZone');
  } catch (_) {
    return null;
  }
}
