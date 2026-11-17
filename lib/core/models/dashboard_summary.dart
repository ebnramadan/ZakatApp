import 'payment.dart';
import 'zakat_record.dart';

class DashboardSummary {
  final String? currency;
  double due = 0;
  double remaining = 0;
  double given = 0;
  double upcomingEstimate = 0;
  int records = 0;
  DashboardSummary(this.currency);

  static List<DashboardSummary> build(
      List<ZakatRecord> records, List<Payment> payments, DateTime now) {
    final totals = <String?, DashboardSummary>{};
    final paid = <String, double>{};
    for (final payment in payments) {
      paid.update(payment.zakatRecordId, (v) => v + payment.amount,
          ifAbsent: () => payment.amount);
    }
    for (final record in records.where((r) => r.isSubmitted && !r.isDeleted)) {
      final total = totals.putIfAbsent(
          record.currency, () => DashboardSummary(record.currency));
      final amount = paid[record.id] ?? 0;
      total.records++;
      total.given += amount;
      if (record.hawlCompleteAt(now)) {
        total.due += record.estimatedZakat;
        total.remaining +=
            (record.estimatedZakat - amount).clamp(0, double.infinity);
      } else {
        total.upcomingEstimate += record.estimatedZakat;
      }
    }
    return totals.values.toList()
      ..sort((a, b) => (a.currency ?? '').compareTo(b.currency ?? ''));
  }
}
