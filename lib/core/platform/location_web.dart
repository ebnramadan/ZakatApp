// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<({double latitude, double longitude})> requestLocation() async {
  final position = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: false,
      timeout: const Duration(seconds: 10),
      maximumAge: Duration.zero);
  final coords = position.coords;
  if (coords == null) throw StateError('Location is unavailable.');
  return (
    latitude: coords.latitude!.toDouble(),
    longitude: coords.longitude!.toDouble()
  );
}
