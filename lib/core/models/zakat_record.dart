import '../constants.dart';
import 'package:hijri/hijri_calendar.dart';

class ForeignCashEntry {
  String currency;
  double amount;
  double exchangeRate;
  bool isManualRate;

  ForeignCashEntry({
    required this.currency,
    required this.amount,
    required this.exchangeRate,
    this.isManualRate = false,
  });

  double get localValue => amount * exchangeRate;

  factory ForeignCashEntry.fromMap(Map<String, dynamic> m) => ForeignCashEntry(
        currency: m['currency'] as String,
        amount: (m['amount'] as num).toDouble(),
        exchangeRate: (m['exchangeRate'] as num).toDouble(),
        isManualRate: m['isManualRate'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'currency': currency,
        'amount': amount,
        'exchangeRate': exchangeRate,
        'isManualRate': isManualRate,
      };

  ForeignCashEntry copyWith({
    String? currency,
    double? amount,
    double? exchangeRate,
    bool? isManualRate,
  }) =>
      ForeignCashEntry(
        currency: currency ?? this.currency,
        amount: amount ?? this.amount,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        isManualRate: isManualRate ?? this.isManualRate,
      );
}

class GoldEntry {
  int carat;
  double grams;
  double pricePerGram24k;
  bool isManualPrice;

  GoldEntry({
    this.carat = 24,
    required this.grams,
    required this.pricePerGram24k,
    this.isManualPrice = false,
  });

  double get purity => kGoldPurity[carat] ?? 1.0;
  double get localValue => grams * pricePerGram24k * purity;

  factory GoldEntry.fromMap(Map<String, dynamic> m) => GoldEntry(
        carat: m['carat'] as int? ?? 24,
        grams: (m['grams'] as num).toDouble(),
        pricePerGram24k: (m['pricePerGram24k'] as num).toDouble(),
        isManualPrice: m['isManualPrice'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'carat': carat,
        'grams': grams,
        'pricePerGram24k': pricePerGram24k,
        'isManualPrice': isManualPrice,
      };

  GoldEntry copyWith({
    int? carat,
    double? grams,
    double? pricePerGram24k,
    bool? isManualPrice,
  }) =>
      GoldEntry(
        carat: carat ?? this.carat,
        grams: grams ?? this.grams,
        pricePerGram24k: pricePerGram24k ?? this.pricePerGram24k,
        isManualPrice: isManualPrice ?? this.isManualPrice,
      );
}

class ZakatRecord {
  final String id;
  final String userId;
  String name;
  String? currency; // null means an older record whose currency is unknown.
  DateTime? pricedAt;
  bool manualNisabPrice;
  DateTime hawlStartDate;
  bool isHijriCalendar;

  double cashLocal;
  List<ForeignCashEntry> foreignCash;
  List<GoldEntry> goldEntries;

  double goldPricePerGram24k;

  double totalWealth;
  double nisabThreshold;
  double zakatDue;
  bool nisabMet;

  bool isSubmitted;
  DateTime? submittedAt;
  DateTime createdAt;
  DateTime? deletedAt;
  DateTime? purgeAt;
  bool get isDeleted => deletedAt != null;
  bool canRestoreAt(DateTime now) =>
      isDeleted && purgeAt != null && now.isBefore(purgeAt!);

  ZakatRecord({
    required this.id,
    required this.userId,
    required this.name,
    this.currency,
    this.pricedAt,
    this.manualNisabPrice = false,
    required this.hawlStartDate,
    this.isHijriCalendar = false,
    this.cashLocal = 0,
    this.foreignCash = const [],
    this.goldEntries = const [],
    this.goldPricePerGram24k = 0,
    this.totalWealth = 0,
    this.nisabThreshold = 0,
    this.zakatDue = 0,
    this.nisabMet = false,
    this.isSubmitted = false,
    this.submittedAt,
    required this.createdAt,
    this.deletedAt,
    this.purgeAt,
  });

  factory ZakatRecord.fromMap(String id, Map<String, dynamic> m) {
    return ZakatRecord(
      id: id,
      userId: m['userId'] as String,
      name: m['name'] as String,
      currency: m['currency'] as String?,
      deletedAt: m['deletedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['deletedAt'] as int),
      purgeAt: m['purgeAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['purgeAt'] as int),
      pricedAt: m['pricedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['pricedAt'] as int),
      manualNisabPrice: m['manualNisabPrice'] as bool? ?? false,
      hawlStartDate:
          DateTime.fromMillisecondsSinceEpoch(m['hawlStartDate'] as int),
      isHijriCalendar: m['isHijriCalendar'] as bool? ?? false,
      cashLocal: (m['cashLocal'] as num?)?.toDouble() ?? 0,
      foreignCash: (m['foreignCash'] as List? ?? [])
          .map((e) =>
              ForeignCashEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      goldEntries: (m['goldEntries'] as List? ?? [])
          .map((e) => GoldEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      goldPricePerGram24k: (m['goldPricePerGram24k'] as num?)?.toDouble() ?? 0,
      totalWealth: (m['totalWealth'] as num?)?.toDouble() ?? 0,
      nisabThreshold: (m['nisabThreshold'] as num?)?.toDouble() ?? 0,
      zakatDue: (m['zakatDue'] as num?)?.toDouble() ?? 0,
      nisabMet: m['nisabMet'] as bool? ?? false,
      isSubmitted: m['isSubmitted'] as bool? ?? false,
      submittedAt: m['submittedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['submittedAt'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'currency': currency,
        'pricedAt': pricedAt?.millisecondsSinceEpoch,
        'manualNisabPrice': manualNisabPrice,
        'hawlStartDate': hawlStartDate.millisecondsSinceEpoch,
        'isHijriCalendar': isHijriCalendar,
        'cashLocal': cashLocal,
        'foreignCash': foreignCash.map((e) => e.toMap()).toList(),
        'goldEntries': goldEntries.map((e) => e.toMap()).toList(),
        'goldPricePerGram24k': goldPricePerGram24k,
        'totalWealth': totalWealth,
        'nisabThreshold': nisabThreshold,
        'zakatDue': zakatDue,
        'nisabMet': nisabMet,
        'isSubmitted': isSubmitted,
        'submittedAt': submittedAt?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (deletedAt != null) 'deletedAt': deletedAt!.millisecondsSinceEpoch,
        if (purgeAt != null) 'purgeAt': purgeAt!.millisecondsSinceEpoch,
      };

  // The calendar switch controls date presentation only. Hawl is a lunar year.
  DateTime get hawlEndDate {
    final start = HijriCalendar.fromDate(hawlStartDate);
    final calendar = HijriCalendar();
    final lastDay = calendar.getDaysInMonth(start.hYear + 1, start.hMonth);
    return calendar.hijriToGregorian(start.hYear + 1, start.hMonth,
        start.hDay > lastDay ? lastDay : start.hDay);
  }

  bool hawlCompleteAt(DateTime now) =>
      !DateTime(now.year, now.month, now.day).isBefore(hawlEndDate);
  bool get hawlComplete => hawlCompleteAt(DateTime.now());
  double get estimatedZakat => nisabMet ? totalWealth * kZakatRate : 0;

  int get daysLeftInHawl {
    final now = DateTime.now();
    final end = hawlEndDate;
    final diff = DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    return diff < 0 ? 0 : diff;
  }
}
