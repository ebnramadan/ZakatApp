import '../constants.dart';
import '../models/zakat_record.dart';

/// Gold-based Nisab, a lunar Hawl, and a 2.5% rate. No debt deductions.
class ZakatCalculator {
  static void calculate(ZakatRecord record, {DateTime? now}) {
    void valid(double value, String label, {bool positive = false}) {
      if (!value.isFinite ||
          value < 0 ||
          value >= 1e18 ||
          (positive && value == 0)) {
        throw FormatException(
            'Enter a valid ${positive ? 'positive ' : ''}$label.');
      }
    }

    if (record.name.trim().isEmpty || record.name.length > 200) {
      throw const FormatException('Enter a record name.');
    }
    if (!kCurrencies.containsKey(record.currency)) {
      throw const FormatException('Choose a base currency.');
    }
    final today = now ?? DateTime.now();
    if (record.hawlStartDate.year < 1938 || record.hawlStartDate.year > 2075) {
      throw const FormatException('Hawl date must be between 1938 and 2075.');
    }
    if (record.hawlStartDate.isAfter(today)) {
      throw const FormatException('Hawl cannot start in the future.');
    }
    if (record.foreignCash.length > 100 || record.goldEntries.length > 100) {
      throw const FormatException(
          'Use at most 100 entries per asset category.');
    }
    valid(record.cashLocal, 'cash amount');
    valid(record.goldPricePerGram24k, '24K gold price for Nisab',
        positive: true);
    for (final entry in record.foreignCash) {
      valid(entry.amount, 'foreign cash amount');
      if (!kCurrencies.containsKey(entry.currency)) {
        throw const FormatException('Unsupported currency.');
      }
      valid(entry.exchangeRate, 'exchange rate', positive: true);
    }
    for (final entry in record.goldEntries) {
      valid(entry.grams, 'gold weight');
      if (!kGoldPurity.containsKey(entry.carat)) {
        throw const FormatException('Unsupported gold purity.');
      }
      valid(entry.pricePerGram24k, 'gold price', positive: entry.grams > 0);
    }
    final total = record.cashLocal +
        record.foreignCash.fold(0.0, (sum, e) => sum + e.localValue) +
        record.goldEntries.fold(0.0, (sum, e) => sum + e.localValue);
    valid(total, 'total wealth');
    record.totalWealth = total;
    record.nisabThreshold = kNisabGrams * record.goldPricePerGram24k;
    valid(record.nisabThreshold, 'Nisab threshold', positive: true);
    record.nisabMet = total >= record.nisabThreshold;
    record.zakatDue = record.nisabMet && record.hawlCompleteAt(today)
        ? total * kZakatRate
        : 0;
  }
}
