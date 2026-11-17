import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zakat_app/core/services/location_currency.dart';
import 'package:zakat_app/core/platform/push_subscription.dart';
import 'package:zakat_app/ui/widgets/location_currency_button.dart';

void main() {
  testWidgets(
      'location is requested only after a tap; denial preserves the chosen currency',
      (tester) async {
    var calls = 0;
    var selected = 'EGP';
    final service = LocationCurrency(locate: () async {
      calls++;
      throw StateError('Denied');
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LocationCurrencyButton(
                service: service, onSelected: (v) => selected = v))));
    expect(calls, 0);
    expect(selected, 'EGP');
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(selected, 'EGP');
    expect(
        find.textContaining('Your currency has not changed'), findsOneWidget);
  });
  test(
      'permitted coordinates suggest the country currency without storing coordinates',
      () async {
    final service = LocationCurrency(
        locate: () async => (latitude: 24.7, longitude: 46.7),
        client: MockClient((r) async {
          expect(r.url.queryParameters['latitude'], '24.7');
          return http.Response(jsonEncode({'countryCode': 'SA'}), 200);
        }));
    expect(await service.suggest(), 'SAR');
  });
  test(
      'browser subscription keys accept padded encodings in canonical URL-safe form',
      () {
    final sub = normalizePushSubscription({
      'endpoint': 'https://web.push.apple.com/test',
      'keys': {'p256dh': 'B${'a' * 86}=', 'auth': '${'a' * 22}=='}
    });
    expect(sub['keys']['p256dh'], hasLength(87));
    expect(sub['keys']['auth'], hasLength(22));
  });
}
