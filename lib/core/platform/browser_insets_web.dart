// This adapter is selected only for web builds.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/widgets.dart';

html.DivElement? _probe;

/// Safari standalone may expose its home-indicator inset only through CSS env().
EdgeInsets browserSafeInsets() {
  final probe = _probe ??= (html.DivElement()
    ..setAttribute('aria-hidden', 'true')
    ..style.cssText =
        'position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top,0px) env(safe-area-inset-right,0px) env(safe-area-inset-bottom,0px) env(safe-area-inset-left,0px);');
  if (probe.parent == null) html.document.body?.append(probe);
  final css = probe.getComputedStyle();
  double px(String value) => double.tryParse(value.replaceAll('px', '')) ?? 0;
  return EdgeInsets.fromLTRB(px(css.paddingLeft), px(css.paddingTop),
      px(css.paddingRight), px(css.paddingBottom));
}
