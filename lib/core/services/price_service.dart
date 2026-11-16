import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class PriceService {
  static final PriceService _instance = PriceService._(http.Client());
  factory PriceService() => _instance;
  PriceService._(this._client);
  PriceService.forTesting(http.Client client) : _client = client;
  final http.Client _client;
  double? _goldUsdPerOz;
  DateTime? _goldFetched;
  DateTime? _fxFetched;
  Map<String, double> _fxRates = {};
  Future<void>? _goldRequest;
  Future<void>? _fxRequest;
  bool _stale(DateTime? time) =>
      time == null ||
      DateTime.now().difference(time) >= const Duration(minutes: 30);

  double _positive(dynamic value) {
    if (value is! num || !value.isFinite || value <= 0) {
      throw const FormatException('Invalid price or exchange rate');
    }
    return value.toDouble();
  }

  Future<dynamic> _get(String url) async {
    final response =
        await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Price service unavailable');
    }
    return jsonDecode(response.body);
  }

  Future<void> _gold() async {
    if (!_stale(_goldFetched)) return;
    if (_goldRequest != null) return _goldRequest;
    final request = () async {
      final data = await _get('https://api.gold-api.com/price/XAU');
      if (data is! Map ||
          data['symbol'] != 'XAU' ||
          data['currency'] != 'USD') {
        throw const FormatException('Unexpected gold response');
      }
      final updatedAt = DateTime.tryParse(data['updatedAt'] as String? ?? '');
      if (updatedAt == null ||
          DateTime.now().toUtc().difference(updatedAt).abs() >
              const Duration(days: 4)) {
        throw const FormatException('Gold quote is stale');
      }
      _goldUsdPerOz = _positive(data['price']);
      _goldFetched = DateTime.now();
    }();
    _goldRequest = request;
    try {
      await request;
    } finally {
      _goldRequest = null;
    }
  }

  Future<void> _fx() async {
    if (!_stale(_fxFetched)) return;
    if (_fxRequest != null) return _fxRequest;
    final request = () async {
      final data = await _get('https://open.er-api.com/v6/latest/USD');
      if (data is! Map ||
          data['result'] != 'success' ||
          data['rates'] is! Map) {
        throw const FormatException('Unexpected FX response');
      }
      final rates = (data['rates'] as Map)
          .map((key, value) => MapEntry(key as String, _positive(value)));
      if (rates['USD'] != 1.0) {
        throw const FormatException('Unexpected FX base');
      }
      _fxRates = rates;
      _fxFetched = DateTime.now();
    }();
    _fxRequest = request;
    try {
      await request;
    } finally {
      _fxRequest = null;
    }
  }

  double _rate(String currency) {
    final value = _fxRates[currency];
    if (value == null) throw FormatException('No exchange rate for $currency');
    return value;
  }

  Future<double> goldPricePerGram(String currency) async {
    await _gold();
    final rate = currency == 'USD' ? 1.0 : await exchangeRate('USD', currency);
    return _positive(_goldUsdPerOz! * rate / kTroyOzToGrams);
  }

  Future<double> nisabValue(String currency) async =>
      kNisabGrams * await goldPricePerGram(currency);
  Future<double> exchangeRate(String foreign, String local) async {
    if (!kCurrencies.containsKey(foreign) || !kCurrencies.containsKey(local)) {
      throw const FormatException('Unsupported currency');
    }
    if (foreign == local) return 1.0;
    await _fx();
    return _positive(_rate(local) / _rate(foreign));
  }

  Future<Map<String, double>> allRatesFor(String local) async {
    await _fx();
    final rate = _rate(local);
    return _fxRates.map((key, value) => MapEntry(key, rate / value));
  }
}
