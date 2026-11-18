// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js;

void completeStartupStage(int stage) {
  try {
    final startup = js.getProperty<Object?>(html.window, 'zakatStartup');
    if (startup != null) js.callMethod<Object?>(startup, 'complete', [stage]);
  } catch (_) {}
}
