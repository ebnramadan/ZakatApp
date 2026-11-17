/// Normalize browser key encodings before Firestore validation and Web Push use.
Map<String, dynamic> normalizePushSubscription(Map value) {
  final result = Map<String, dynamic>.from(value);
  final keys = Map<String, dynamic>.from(result['keys'] as Map);
  for (final name in ['p256dh', 'auth']) {
    keys[name] = (keys[name] as String)
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
  }
  result['keys'] = keys;
  return result;
}
