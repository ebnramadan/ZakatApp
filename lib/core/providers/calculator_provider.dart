import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/zakat_record.dart';
import '../services/firestore_service.dart';
import '../services/price_service.dart';

class CalculatorProvider extends ChangeNotifier {
  final _fs = FirestoreService();
  final _prices = PriceService();
  final _uuid = const Uuid();

  List<ZakatRecord> _records = [];
  ZakatRecord? _draft;
  bool _loading = false;
  String? _error;

  // Live price state
  double _goldPricePerGram = 0;
  double _nisabValue = 0;
  bool _pricesLoading = false;

  List<ZakatRecord> get records => _records;
  ZakatRecord? get draft => _draft;
  bool get loading => _loading;
  String? get error => _error;
  double get goldPricePerGram => _goldPricePerGram;
  double get nisabValue => _nisabValue;
  bool get pricesLoading => _pricesLoading;

  void loadRecords(String uid) {
    _fs.recordsStream(uid).listen((list) {
      _records = list;
      notifyListeners();
    });
  }

  Future<void> fetchPrices(String currency) async {
    _pricesLoading = true;
    _error = null;
    notifyListeners();
    try {
      _goldPricePerGram = await _prices.goldPricePerGram(currency);
      _nisabValue = kNisabGrams * _goldPricePerGram;
    } catch (e) {
      _error = 'Could not fetch live prices. Please check your connection.';
    }
    _pricesLoading = false;
    notifyListeners();
  }

  Future<double> getExchangeRate(String foreign, String local) =>
      _prices.exchangeRate(foreign, local);

  void startNewRecord(String userId, String currency) {
    final now = DateTime.now();
    _draft = ZakatRecord(
      id: '',
      userId: userId,
      name: 'Zakat ${now.year}',
      hawlStartDate: now,
      isHijriCalendar: false,
      foreignCash: [],
      goldEntries: [],
      goldPricePerGram24k: _goldPricePerGram,
      createdAt: now,
    );
    notifyListeners();
  }

  void updateDraftName(String name) {
    _draft = ZakatRecord(
      id: _draft!.id,
      userId: _draft!.userId,
      name: name,
      hawlStartDate: _draft!.hawlStartDate,
      isHijriCalendar: _draft!.isHijriCalendar,
      cashLocal: _draft!.cashLocal,
      foreignCash: _draft!.foreignCash,
      goldEntries: _draft!.goldEntries,
      goldPricePerGram24k: _draft!.goldPricePerGram24k,
      createdAt: _draft!.createdAt,
    );
    notifyListeners();
  }

  void updateDraftHawl(DateTime date, bool isHijri) {
    _draft!.hawlStartDate = date;
    _draft!.isHijriCalendar = isHijri;
    notifyListeners();
  }

  void updateCashLocal(double amount) {
    _draft!.cashLocal = amount;
    notifyListeners();
  }

  void setForeignCash(List<ForeignCashEntry> entries) {
    _draft!.foreignCash = entries;
    notifyListeners();
  }

  void setGoldEntries(List<GoldEntry> entries) {
    _draft!.goldEntries = entries;
    notifyListeners();
  }

  void updateGoldPrice(double pricePerGram) {
    _draft!.goldPricePerGram24k = pricePerGram;
    notifyListeners();
  }

  /// Compute results and store in draft.
  void computeResults() {
    final d = _draft!;
    final foreignTotal = d.foreignCash.fold(0.0, (s, e) => s + e.localValue);
    final goldTotal = d.goldEntries.fold(0.0, (s, e) => s + e.localValue);
    final total = d.cashLocal + foreignTotal + goldTotal;
    final nisab = kNisabGrams * d.goldPricePerGram24k;
    d.totalWealth = total;
    d.nisabThreshold = nisab;
    d.nisabMet = total >= nisab;
    d.zakatDue = d.nisabMet ? total * kZakatRate : 0;
    notifyListeners();
  }

  Future<void> submitDraft(String userId) async {
    _loading = true;
    notifyListeners();
    try {
      computeResults();
      _draft!.isSubmitted = true;
      _draft!.submittedAt = DateTime.now();
      final id = await _fs.saveRecord(_draft!);
      // Reload records (stream will update automatically)
      _draft = null;
    } catch (e) {
      _error = 'Failed to save record. Please try again.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> deleteDraft() async {
    _draft = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
