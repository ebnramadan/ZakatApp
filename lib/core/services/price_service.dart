import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class PriceService {
  static const _fxBase = 'https://open.er-api.com/v6/latest/';
  static const _goldUrl = 'https://api.metals.live/v1/spot';

  // Cache
  double? _goldUsdPerOz;
  final Map<String, double> _fxRates = {}; // currency -> rate vs USD
  DateTime? _lastFetch;

  static final PriceService _instance = PriceService._();
  factory PriceService() => _instance;
  PriceService._();

  bool get _isStale =>
      _lastFetch == null ||
      DateTime.now().difference(_lastFetch!).inMinutes > 30;

  /// Returns gold price in USD per troy oz
  Future<double> _fetchGoldUsdPerOz() async {
    final res = await http
        .get(Uri.parse(_goldUrl))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Gold API error ${res.statusCode}');
    final List<dynamic> data = jsonDecode(res.body) as List;
    // Response: [{"gold": 2045.21, ...}]
    final gold = (data.first as Map<String, dynamic>)['gold'];
    return (gold as num).toDouble();
  }

  /// Returns rates: 1 USD = X currency
  Future<Map<String, double>> _fetchFxRates() async {
    final res = await http
        .get(Uri.parse('${_fxBase}USD'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('FX API error ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final rates = data['rates'] as Map<String, dynamic>;
    return rates.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  Future<void> _refresh() async {
    if (!_isStale) return;
    final results = await Future.wait([_fetchGoldUsdPerOz(), _fetchFxRates()]);
    _goldUsdPerOz = results[0] as double;
    _fxRates.clear();
    _fxRates.addAll(results[1] as Map<String, double>);
    _lastFetch = DateTime.now();
  }

  /// Gold price per gram in [localCurrency] (24K basis)
  Future<double> goldPricePerGram(String localCurrency) async {
    await _refresh();
    final goldOz = _goldUsdPerOz!;
    final rate = _localRate(localCurrency);
    return goldOz * rate / kTroyOzToGrams;
  }

  /// Nisab threshold in [localCurrency] (85 g × 24K gold price)
  Future<double> nisabValue(String localCurrency) async {
    final pricePerGram = await goldPricePerGram(localCurrency);
    return kNisabGrams * pricePerGram;
  }

  /// How many [localCurrency] units equal 1 [foreignCurrency] unit
  Future<double> exchangeRate(String foreignCurrency, String localCurrency) async {
    await _refresh();
    if (foreignCurrency == localCurrency) return 1.0;
    final foreignToUsd = 1.0 / (_fxRates[foreignCurrency] ?? 1.0);
    final usdToLocal = _fxRates[localCurrency] ?? 1.0;
    return foreignToUsd * usdToLocal;
  }

  /// All fx rates relative to [localCurrency]
  Future<Map<String, double>> allRatesFor(String localCurrency) async {
    await _refresh();
    final usdToLocal = _fxRates[localCurrency] ?? 1.0;
    return _fxRates.map((k, v) => MapEntry(k, usdToLocal / v));
  }

  double _localRate(String localCurrency) =>
      localCurrency == 'USD' ? 1.0 : (_fxRates[localCurrency] ?? 1.0);
}
