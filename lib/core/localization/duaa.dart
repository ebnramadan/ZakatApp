import 'arabic.dart';

/// Keep the Arabic prayer alongside its meaning in English mode.
String duaaText(String english, String language) {
  final translation = arabic[english];
  if (translation == null) return english;
  return language == 'ar' ? translation : '$english\n\n$translation';
}

/// Also covers older inbox items saved before bilingual push messages existed.
/// Only known prayers at the end are changed; personal names remain untouched.
String notificationDuaaText(String body, String language) {
  final prayers = arabic.entries.where((e) => e.key.startsWith('O Allah,'));
  for (final prayer in prayers) {
    final bilingual = '${prayer.key}\n\n${prayer.value}';
    if (body.endsWith(bilingual)) {
      return body.substring(0, body.length - bilingual.length) +
          duaaText(prayer.key, language);
    }
    if (body.endsWith(prayer.key)) {
      return body.substring(0, body.length - prayer.key.length) +
          duaaText(prayer.key, language);
    }
  }
  for (final prayer in prayers) {
    if (body.endsWith(prayer.value)) {
      return body.substring(0, body.length - prayer.value.length) +
          duaaText(prayer.key, language);
    }
  }
  return body;
}
