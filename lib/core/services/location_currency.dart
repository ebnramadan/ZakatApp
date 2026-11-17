import 'dart:convert';
import 'package:http/http.dart' as http;
import '../platform/device_currency.dart';
import '../platform/location_stub.dart'
    if (dart.library.html) '../platform/location_web.dart' as platform;

class LocationCurrency {
  final Future<({double latitude, double longitude})> Function() locate;
  final http.Client? client;
  LocationCurrency(
      {Future<({double latitude, double longitude})> Function()? locate,
      this.client})
      : locate = locate ?? platform.requestLocation;
  Future<String> suggest() async {
    // This is called only by the explicit button. Coordinates are never saved.
    final point = await locate();
    final uri =
        Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
      'latitude': '${point.latitude}',
      'longitude': '${point.longitude}',
      'localityLanguage': 'en'
    });
    final response = await (client?.get(uri) ?? http.get(uri))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Country lookup unavailable.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return currencyForCountryCode(body['countryCode'] as String?);
  }
}
