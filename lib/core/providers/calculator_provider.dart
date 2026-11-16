import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../calculation/zakat_calculator.dart';
import '../models/zakat_record.dart';
import '../services/firestore_service.dart';
import '../services/price_service.dart';

class CalculatorProvider extends ChangeNotifier {
  final FirestoreService _fs;
  final PriceService _prices;
  CalculatorProvider({FirestoreService? store, PriceService? prices})
      : _fs = store ?? FirestoreService(),
        _prices = prices ?? PriceService();
  StreamSubscription<List<ZakatRecord>>? _sub;
  List<ZakatRecord> _records = [];
  ZakatRecord? _draft;
  bool _loading = false;
  bool _recordsLoading = false;
  String? _error;
  double _goldPricePerGram = 0;
  bool _pricesLoading = false;
  bool _disposed = false;
  int _priceRequest = 0;

  List<ZakatRecord> get records => List.unmodifiable(_records);
  ZakatRecord? get draft => _draft;
  bool get loading => _loading;
  bool get recordsLoading => _recordsLoading;
  String? get error => _error;
  double get goldPricePerGram => _goldPricePerGram;
  double get nisabValue =>
      (_draft?.goldPricePerGram24k ?? _goldPricePerGram) * kNisabGrams;
  bool get pricesLoading => _pricesLoading;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void loadRecords(String uid) {
    _sub?.cancel();
    _recordsLoading = true;
    _notify();
    _sub = _fs.recordsStream(uid).listen((list) {
      _records = list;
      _recordsLoading = false;
      _notify();
    }, onError: (Object e) {
      _recordsLoading = false;
      _error = 'Could not load records. Check your connection and retry.';
      _notify();
    });
  }

  Future<void> fetchPrices(String currency) async {
    final request = ++_priceRequest;
    final target = _draft;
    _pricesLoading = true;
    _error = null;
    _notify();
    try {
      final price = await _prices.goldPricePerGram(currency);
      if (_disposed || request != _priceRequest) return;
      _goldPricePerGram = price;
      if (identical(target, _draft) &&
          target != null &&
          !target.manualNisabPrice) {
        target.goldPricePerGram24k = price;
        target.pricedAt = DateTime.now();
        for (final entry in target.goldEntries) {
          if (!entry.isManualPrice) entry.pricePerGram24k = price;
        }
      }
    } catch (_) {
      if (_disposed || request != _priceRequest) return;
      _error =
          'Live prices unavailable. Retry or enter a verified manual gold price.';
    }
    if (_disposed || request != _priceRequest) return;
    _pricesLoading = false;
    _notify();
  }

  Future<double> getExchangeRate(String foreign, String local) =>
      _prices.exchangeRate(foreign, local);

  void startNewRecord(String userId, String currency) {
    _priceRequest++;
    _goldPricePerGram = 0;
    _error = null;
    final now = DateTime.now();
    _draft = ZakatRecord(
        id: const Uuid().v4(),
        userId: userId,
        currency: currency,
        name: 'Zakat ${now.year}',
        hawlStartDate: DateTime(now.year, now.month, now.day),
        foreignCash: [],
        goldEntries: [],
        createdAt: now);
    _notify();
  }

  void resumeRecord(ZakatRecord record) {
    if (record.isSubmitted) return;
    _draft = ZakatRecord.fromMap(record.id, record.toMap());
    _goldPricePerGram = _draft!.goldPricePerGram24k;
    _error = null;
    _notify();
  }

  void updateDraftName(String name) {
    _draft!.name = name;
    _notify();
  }

  void updateDraftHawl(DateTime date, bool isHijri) {
    _draft!.hawlStartDate = date;
    _draft!.isHijriCalendar = isHijri;
    _notify();
  }

  void updateCashLocal(double amount) {
    _draft!.cashLocal = amount;
    _notify();
  }

  void setForeignCash(List<ForeignCashEntry> entries) {
    _draft!.foreignCash = entries;
    _notify();
  }

  void setGoldEntries(List<GoldEntry> entries) {
    _draft!.goldEntries = entries;
    _notify();
  }

  void updateGoldPrice(double price) {
    _draft!.goldPricePerGram24k = price;
    _draft!.manualNisabPrice = true;
    _draft!.pricedAt = DateTime.now();
    for (final entry in _draft!.goldEntries) {
      if (!entry.isManualPrice) entry.pricePerGram24k = price;
    }
    _notify();
  }

  bool computeResults() {
    _error = null;
    try {
      ZakatCalculator.calculate(_draft!);
    } catch (e) {
      _error =
          e is FormatException ? e.message : 'Unable to calculate this record.';
    }
    _notify();
    return _error == null;
  }

  Future<bool> saveDraft() async {
    if (_loading || _draft == null) return false;
    _loading = true;
    _error = null;
    _notify();
    try {
      await _fs.saveRecord(_draft!);
    } catch (_) {
      _error = 'Failed to save draft. Your input is still here; retry.';
    }
    _loading = false;
    _notify();
    return _error == null;
  }

  Future<ZakatRecord?> submitDraft(String userId) async {
    if (_loading || _draft == null || _draft!.userId != userId) return null;
    if (!computeResults()) return null;
    _loading = true;
    _notify();
    final saved = ZakatRecord.fromMap(_draft!.id, _draft!.toMap());
    saved.isSubmitted = true;
    saved.submittedAt = DateTime.now();
    try {
      final committed = await _fs.submitRecord(saved);
      _draft = null;
      return committed;
    } catch (_) {
      _error = 'Failed to submit record. Your draft is unchanged; retry.';
      return null;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> deleteDraft() async {
    if (_draft != null) await _fs.deleteRecord(_draft!.userId, _draft!.id);
    _draft = null;
    _notify();
  }

  void clearError() {
    _error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _priceRequest++;
    _sub?.cancel();
    super.dispose();
  }
}
