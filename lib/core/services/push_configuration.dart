import 'dart:convert';
import 'package:http/http.dart' as http;

/// Public VAPID/configuration data does not need the authenticated WebChannel.
class PushConfiguration {
  final http.Client? client;
  PushConfiguration({this.client});

  Future<Map<String, dynamic>> load(Uri uri) async {
    final response = await (client?.get(uri) ?? http.get(uri))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Notification configuration is unavailable.');
    }
    final document = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = document['fields'] as Map<String, dynamic>? ?? {};
    final key = (fields['publicKey'] as Map?)?['stringValue'];
    if (key is! String || !RegExp(r'^[A-Za-z0-9_-]{87}$').hasMatch(key)) {
      throw const FormatException('Invalid public notification configuration.');
    }
    final scheduled = (fields['scheduledAt'] as Map?)?['integerValue'];
    return {
      'publicKey': key,
      'configured': (fields['configured'] as Map?)?['booleanValue'] == true,
      if (scheduled != null && int.tryParse('$scheduled') != null)
        'scheduledAt': int.parse('$scheduled'),
    };
  }
}
