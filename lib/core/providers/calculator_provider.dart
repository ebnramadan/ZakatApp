import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../calculation/zakat_calculator.dart';
import '../models/zakat_record.dart';
import '../models/payment.dart';
import '../services/firestore_service.dart';
import '../services/price_service.dart';

class CalculatorProvider extends ChangeNotifier {
  final FirestoreService _fs;
  final PriceService _prices;
  final Duration _initialLoadTimeout;
  Timer? _loadDeadline;
  int _dataGeneration = 0;
  String? _recordsUid;
  CalculatorProvider(
      {FirestoreService? store,
      PriceService? prices,
      Duration initialLoadTimeout = const Duration(seconds: 10)})
      : _fs = store ?? FirestoreService(),
        _prices = prices ?? PriceService(),
        _initialLoadTimeout = initialLoadTimeout;
  StreamSubscription<List<ZakatRecord>>? _sub;
  List<ZakatRecord> _records = [];
  ZakatRecord? _draft;
  bool _loading = false;
  bool _recordsLoading = false;
  String? _error;
  String? _recordsError;
  double _goldPricePerGram = 0;
  bool _pricesLoading = false;
  bool _disposed = false;
  int _priceRequest = 0;

  StreamSubscription<List<Payment>>? _paymentSub;
  List<Payment> _allPayments = [];
  bool paymentsLoading = true;
  String? paymentsError;
  List<Payment> get allPayments => List.unmodifiable(_allPayments);
  List<ZakatRecord> get records =>
      List.unmodifiable(_records.where((r) => !r.isDeleted));
  List<ZakatRecord> get recycledRecords =>
      List.unmodifiable(_records.where((r) => r.canRestoreAt(DateTime.now())));
  bool isRecordActive(String id) => records.any((r) => r.id == id);
  ZakatRecord? defaultRecord(String? id) {
    final selected = records.where((r) => r.id == id);
    if (selected.isNotEmpty) return selected.first;
    final submitted = records.where((r) => r.isSubmitted);
    if (submitted.isNotEmpty) return submitted.first;
    return records.isEmpty ? null : records.first;
  }

  ZakatRecord? get draft => _draft;
  bool get loading => _loading;
  bool get recordsLoading => _recordsLoading;
  String? get error => _error;
  String? get recordsError => _recordsError;
  double get goldPricePerGram => _goldPricePerGram;
  double get nisabValue =>
      (_draft?.goldPricePerGram24k ?? _goldPricePerGram) * kNisabGrams;
  bool get pricesLoading => _pricesLoading;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void loadRecords(String uid) => _listenRecords(uid, retries: 1);

  Future<void> retryRecords(String uid) async {
    if (_disposed) return;
    final generation = ++_dataGeneration;
    _loadDeadline?.cancel();
    _sub?.cancel();
    _paymentSub?.cancel();
    if (_recordsUid != uid) {
      _records = [];
      _allPayments = [];
      if (_draft?.userId != uid) _draft = null;
    }
    _recordsUid = uid;
    _recordsLoading = true;
    paymentsLoading = true;
    _recordsError = null;
    paymentsError = null;
    _notify();
    try {
      await _fs.reconnectNetwork().timeout(const Duration(seconds: 6));
    } catch (_) {
      /* A fresh listener can still recover after a transport error. */
    }
    if (_disposed || generation != _dataGeneration) return;
    _listenRecords(uid, retries: 0);
  }

  void _finishInitialLoad() {
    if (!_recordsLoading && !paymentsLoading) {
      _loadDeadline?.cancel();
      _loadDeadline = null;
    }
  }

  void _listenRecords(String uid, {required int retries}) {
    if (_disposed) return;
    final generation = ++_dataGeneration;
    _loadDeadline?.cancel();
    _sub?.cancel();
    _paymentSub?.cancel();
    if (_recordsUid != uid) {
      _records = [];
      _allPayments = [];
      if (_draft?.userId != uid) _draft = null;
    }
    _recordsUid = uid;
    _recordsLoading = true;
    paymentsLoading = true;
    _recordsError = null;
    paymentsError = null;
    _loadDeadline = Timer(_initialLoadTimeout, () {
      if (_disposed || generation != _dataGeneration) return;
      if (!_recordsLoading && !paymentsLoading) return;
      if (retries > 0 && _recordsError == null && paymentsError == null) {
        unawaited(retryRecords(uid));
        return;
      }
      if (_recordsLoading) {
        _recordsLoading = false;
        _recordsError =
            'Your records are taking too long to load. Check your connection and retry.';
      }
      if (paymentsLoading) {
        paymentsLoading = false;
        paymentsError =
            'Payment totals are taking too long to load. Check your connection and retry.';
      }
      _notify();
    });
    _notify();
    _paymentSub = _fs.allPaymentsStream(uid).listen((payments) {
      if (_disposed || generation != _dataGeneration) return;
      _allPayments = payments;
      paymentsLoading = false;
      paymentsError = null;
      _finishInitialLoad();
      _notify();
    }, onError: (Object e) {
      if (_disposed || generation != _dataGeneration) return;
      paymentsLoading = false;
      paymentsError = 'Payment totals could not load. Please retry.';
      _finishInitialLoad();
      _notify();
    });
    _sub = _fs.recordsStream(uid).listen((list) {
      if (_disposed || generation != _dataGeneration) return;
      _records = list;
      _recordsError = null;
      _recordsLoading = false;
      _finishInitialLoad();
      _notify();
    }, onError: (Object e) {
      if (_disposed || generation != _dataGeneration) return;
      _recordsLoading = false;
      _recordsError =
          'Could not load records. Check your connection and retry.';
      _finishInitialLoad();
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

  void startNewRecord(String userId, String currency,
      {String language = 'en'}) {
    _priceRequest++;
    _goldPricePerGram = 0;
    _error = null;
    final now = DateTime.now();
    _draft = ZakatRecord(
        id: const Uuid().v4(),
        userId: userId,
        currency: currency,
        name: language == 'ar' ? 'زكاة ${now.year}' : 'Zakat ${now.year}',
        hawlStartDate: DateTime(now.year, now.month, now.day),
        foreignCash: [],
        goldEntries: [],
        createdAt: now);
    _notify();
  }

  void resumeRecord(ZakatRecord record) {
    if (record.isSubmitted || record.isDeleted) return;
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
    if (_draft != null) await _fs.recycleRecord(_draft!.userId, _draft!.id);
    _draft = null;
    _notify();
  }

  Future<bool> recycleRecord(ZakatRecord record) async {
    try {
      await _fs.recycleRecord(record.userId, record.id);
      if (_draft?.id == record.id) _draft = null;
      return true;
    } catch (_) {
      _error = 'Could not move the record to the recycle bin. Please retry.';
      _notify();
      return false;
    }
  }

  Future<bool> restoreRecord(ZakatRecord record) async {
    try {
      await _fs.restoreRecord(record.userId, record.id);
      return true;
    } catch (_) {
      _error =
          'Could not restore the record. Check your connection and the 60-day window.';
      _notify();
      return false;
    }
  }

  void clearError() {
    _error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _dataGeneration++;
    _loadDeadline?.cancel();
    _priceRequest++;
    _sub?.cancel();
    _paymentSub?.cancel();
    super.dispose();
  }
}
