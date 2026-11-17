import 'monthly_giving.dart';

/// Planned commitments only; receipts remain the source of actual giving.
class GivingForecastMonth {
  final DateTime month;
  final Map<String, double> sadaqah, zakat;
  GivingForecastMonth(this.month, this.sadaqah, this.zakat);
  double total(String currency) =>
      (sadaqah[currency] ?? 0) + (zakat[currency] ?? 0);
}

List<GivingForecastMonth> givingForecast(
    {required Iterable<MonthlyPlan> plans,
    required DateTime from,
    required bool Function(String id, String currency) recordAvailable}) {
  final eligible = plans
      .where((p) =>
          p.active &&
          (p.kind == 'sadaqah' || recordAvailable(p.zakatRecordId, p.currency)))
      .toList();
  return List.generate(12, (i) {
    final date = DateTime(from.year, from.month + i);
    final key = monthKey(date);
    final sadaqah = <String, double>{}, zakat = <String, double>{};
    for (final plan
        in eligible.where((p) => p.startMonth.compareTo(key) <= 0)) {
      final totals = plan.kind == 'zakat' ? zakat : sadaqah;
      totals.update(plan.currency, (v) => v + plan.amount,
          ifAbsent: () => plan.amount);
    }
    return GivingForecastMonth(date, sadaqah, zakat);
  });
}
