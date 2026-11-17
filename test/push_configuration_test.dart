import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zakat_app/core/services/push_configuration.dart';

void main() {
  test(
      'public configuration loads without an auth header and decodes Firestore fields',
      () async {
    final loader = PushConfiguration(client: MockClient((request) async {
      expect(request.headers.containsKey('authorization'), isFalse);
      return http.Response(
          jsonEncode({
            'fields': {
              'publicKey': {'stringValue': 'B${'a' * 86}'},
              'configured': {'booleanValue': true},
              'scheduledAt': {'integerValue': '1794931200000'},
            }
          }),
          200);
    }));
    final result = await loader.load(Uri.parse(
        'https://firestore.googleapis.com/v1/projects/test/databases/(default)/documents/appConfig/push'));
    expect(result['publicKey'], hasLength(87));
    expect(result['configured'], isTrue);
    expect(result['scheduledAt'], 1794931200000);
  });
  test(
      'invalid responses fail safely instead of presenting broken registration keys',
      () async {
    for (final response in [
      http.Response('{}', 403),
      http.Response('{}', 200),
      http.Response('{"fields":{"publicKey":{"stringValue":"bad"}}}', 200)
    ]) {
      final loader =
          PushConfiguration(client: MockClient((_) async => response));
      await expectLater(
          loader.load(Uri.parse('https://example.com')), throwsA(anything));
    }
  });
}
