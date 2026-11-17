import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'arabic.dart';

/// Translate interface copy; arguments remain user data, not translation keys.
String l(BuildContext context, Object? source,
    [List<Object?> args = const []]) {
  final code = Localizations.localeOf(context).languageCode;
  final message = source is num
      ? NumberFormat.decimalPattern(code).format(source)
      : source?.toString() ?? '';
  const english = {
    'صدقة · Sadaqah': 'Sadaqah',
    'زكاة · Part of Zakat': 'Zakat · Part of Zakat',
    'زكاة · Counts toward your selected Zakat record':
        'Zakat · Counts toward your selected Zakat record',
    'صدقة · Separate from Zakat': 'Sadaqah · Separate from Zakat',
    'Language / اللغة': 'Language'
  };
  var template = code == 'ar'
      ? (arabic[message] ?? message)
      : (english[message] ?? message);
  for (var i = 0; i < args.length; i++) {
    final value = args[i];
    template = template.replaceAll(
        '{$i}',
        value is num
            ? NumberFormat.decimalPattern(code).format(value)
            : value?.toString() ?? '');
  }
  if (code == 'ar' && args.isEmpty && !arabic.containsKey(message)) {
    for (final entry in _templates) {
      final match = entry.$1.firstMatch(message);
      if (match != null) {
        var result = entry.$2;
        for (var i = 1; i <= match.groupCount; i++) {
          result = result.replaceAll('{${i - 1}}', match.group(i) ?? '');
        }
        return result;
      }
    }
  }
  return template;
}

final _templates = arabic.entries.where((e) => e.key.contains('{0}')).map((e) {
  final chunks = e.key.split(RegExp(r'\{\d+\}'));
  return (
    RegExp('^${chunks.map(RegExp.escape).join('(.*?)')}\$', dotAll: true),
    e.value
  );
}).toList();

/// Accept Arabic/Persian digits and Arabic decimal/group separators in amount fields.
String normalizeNumber(String text) => text
    .replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
      final n = m[0]!.codeUnitAt(0);
      return (n >= 0x6f0 ? n - 0x6f0 : n - 0x660).toString();
    })
    .replaceAll('٫', '.')
    .replaceAll('٬', '')
    .replaceAll(',', '');
double? parseLocalizedNumber(String text) =>
    double.tryParse(normalizeNumber(text).trim());
