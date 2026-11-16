import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zakat_app/core/services/price_service.dart';

void main() {
  test('FX works even when the gold endpoint fails', () async {
    final service = PriceService.forTesting(MockClient((request) async {
      if (request.url.host == 'api.gold-api.com') {
        return http.Response('unavailable', 503);
      }
      return http.Response(
          jsonEncode({
            'result': 'success',
            'rates': {'USD': 1, 'EUR': .8, 'EGP': 50}
          }),
          200);
    }));
    expect(await service.exchangeRate('EUR', 'EGP'), 62.5);
    await expectLater(service.goldPricePerGram('USD'), throwsException);
  });
  test('missing currency never silently becomes a 1:1 rate', () async {
    final service = PriceService.forTesting(MockClient((_) async =>
        http.Response('{"result":"success","rates":{"USD":1}}', 200)));
    await expectLater(
        service.exchangeRate('EUR', 'USD'), throwsFormatException);
  });
  test('USD gold quote converts troy ounces to grams', () async {
    final service = PriceService.forTesting(MockClient((_) async => http.Response(
        '{"symbol":"XAU","currency":"USD","price":3110.35,"updatedAt":"${DateTime.now().toUtc().toIso8601String()}"}',
        200)));
    expect(await service.goldPricePerGram('USD'), closeTo(100, .0001));
  });
  test('concurrent gold requests are coalesced and cached', () async {
    var calls = 0;
    final service = PriceService.forTesting(MockClient((_) async {
      calls++;
      return http.Response(
          '{"symbol":"XAU","currency":"USD","price":3110.35,"updatedAt":"${DateTime.now().toUtc().toIso8601String()}"}',
          200);
    }));
    await Future.wait(
        [service.goldPricePerGram('USD'), service.goldPricePerGram('USD')]);
    await service.goldPricePerGram('USD');
    expect(calls, 1);
  });
  test('identical currency needs no network', () async {
    final service = PriceService.forTesting(
        MockClient((_) async => throw Exception('Offline')));
    expect(await service.exchangeRate('USD', 'USD'), 1);
  });
  test('invalid and unsuccessful responses are rejected', () async {
    for (final body in [
      '{"result":"error","rates":{"USD":1}}',
      '{"result":"success","rates":{"USD":1,"EUR":0}}',
      'not json'
    ]) {
      final service = PriceService.forTesting(
          MockClient((_) async => http.Response(body, 200)));
      await expectLater(
          service.exchangeRate('EUR', 'USD'), throwsFormatException);
    }
  });
}
