import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:zakat_app/core/calculation/zakat_calculator.dart';
import 'package:zakat_app/core/models/zakat_record.dart';

ZakatRecord record({double cash = 8500}) => ZakatRecord(
    id: 'r',
    userId: 'u',
    currency: 'USD',
    name: 'Test',
    hawlStartDate: DateTime(2023, 1, 1),
    cashLocal: cash,
    goldPricePerGram24k: 100,
    createdAt: DateTime(2023));

void main() {
  final now = DateTime(2026, 11, 16);
  test('below, at, and above 85g gold Nisab', () {
    for (final cash in [8499.99, 8500.0, 10000.0]) {
      final d = record(cash: cash);
      ZakatCalculator.calculate(d, now: now);
      expect(d.nisabThreshold, 8500);
      expect(d.nisabMet, cash >= 8500);
      expect(d.zakatDue, cash >= 8500 ? cash * .025 : 0);
    }
  });
  test('cash, FX and purity-adjusted gold are combined', () {
    final d = record(cash: 1000)
      ..foreignCash = [
        ForeignCashEntry(currency: 'EUR', amount: 1000, exchangeRate: 2)
      ]
      ..goldEntries = [GoldEntry(carat: 18, grams: 100, pricePerGram24k: 100)];
    ZakatCalculator.calculate(d, now: now);
    expect(d.totalWealth, 10500);
    expect(d.zakatDue, 262.5);
  });
  test('uncompleted Hawl is an estimate, not an amount currently due', () {
    final d = record()..hawlStartDate = now;
    ZakatCalculator.calculate(d, now: now);
    expect(d.nisabMet, isTrue);
    expect(d.zakatDue, 0);
    expect(d.estimatedZakat, 212.5);
  });
  test('lunar anniversary uses the calendar and starts being due on that day',
      () {
    final calendar = HijriCalendar();
    final d = record()..hawlStartDate = calendar.hijriToGregorian(1445, 9, 1);
    expect(d.hawlEndDate, calendar.hijriToGregorian(1446, 9, 1));
    ZakatCalculator.calculate(d,
        now: d.hawlEndDate.subtract(const Duration(days: 1)));
    expect(d.zakatDue, 0);
    ZakatCalculator.calculate(d, now: d.hawlEndDate);
    expect(d.zakatDue, 212.5);
  });
  test('Hijri switch changes presentation, not the Hawl duration', () {
    final d = record();
    final end = d.hawlEndDate;
    d.isHijriCalendar = true;
    expect(d.hawlEndDate, end);
  });
  test('zero, negative and nonfinite prices cannot produce a result', () {
    for (final price in [0.0, -1.0, double.nan, double.infinity]) {
      final d = record()..goldPricePerGram24k = price;
      expect(
          () => ZakatCalculator.calculate(d, now: now), throwsFormatException);
    }
  });
  test('missing FX is rejected rather than silently ignoring foreign cash', () {
    final d = record()
      ..foreignCash = [
        ForeignCashEntry(currency: 'EUR', amount: 1000, exchangeRate: 0)
      ];
    expect(() => ZakatCalculator.calculate(d, now: now), throwsFormatException);
  });
  test('invalid gold, cash and future dates are rejected', () {
    expect(() => ZakatCalculator.calculate(record(cash: -1), now: now),
        throwsFormatException);
    expect(
        () => ZakatCalculator.calculate(
            record()..hawlStartDate = now.add(const Duration(days: 1)),
            now: now),
        throwsFormatException);
    expect(
        () => ZakatCalculator.calculate(
            record()
              ..goldEntries = [
                GoldEntry(carat: 10, grams: 10, pricePerGram24k: 100)
              ],
            now: now),
        throwsFormatException);
  });
  test('record currency and pricing provenance survive persistence', () {
    final d = record()
      ..pricedAt = now
      ..manualNisabPrice = true;
    final saved = ZakatRecord.fromMap(d.id, d.toMap());
    expect(saved.currency, 'USD');
    expect(saved.pricedAt, now);
    expect(saved.manualNisabPrice, isTrue);
    final legacy = d.toMap()..remove('currency');
    expect(ZakatRecord.fromMap(d.id, legacy).currency, isNull);
  });
}
