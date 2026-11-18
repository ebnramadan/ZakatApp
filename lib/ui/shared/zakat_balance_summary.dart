import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants.dart';
import '../../core/localization/strings.dart';
import '../../core/models/zakat_record.dart';

/// The same plain-language calculation on Home and Tracker.
class ZakatBalanceSummary extends StatelessWidget {
  final ZakatRecord record;
  final double paid;
  const ZakatBalanceSummary(
      {super.key, required this.record, required this.paid});

  @override
  Widget build(BuildContext context) {
    final total = record.estimatedZakat;
    final remaining = (total - paid).clamp(0.0, double.infinity);
    final formatter = record.currency == null
        ? NumberFormat('#,##0.00')
        : NumberFormat.currency(
            name: record.currency,
            symbol: '${record.currency} ',
            decimalDigits: currencyDecimals(record.currency!));
    Widget row(String label, double amount, {bool prominent = false}) =>
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l(context, label),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.4)),
              const SizedBox(height: 3),
              Text(formatter.format(amount),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: prominent ? 28 : 20,
                      fontWeight: FontWeight.w700,
                      height: 1.3)),
            ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!record.hawlComplete && record.nisabMet)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                l(
                    context,
                    'Not due yet. This estimate is for {0}. Payments made now count as advance payments.',
                    [
                      DateFormat.yMMMd().format(record.hawlEndDate)
                    ]),
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.5))),
      if (!record.nisabMet)
        Text(l(context, 'Below Nisab: no Zakat is due on this calculation.'),
            style: const TextStyle(color: Colors.white, height: 1.5)),
      row(record.hawlComplete ? 'Total Zakat' : 'Estimated total Zakat', total),
      row('Already paid', paid),
      const Divider(color: Colors.white38, height: 12),
      row(record.hawlComplete ? 'Still to pay' : 'Still to cover (estimate)',
          remaining,
          prominent: true),
      Text(l(context, 'Total Zakat − Already paid = Still to pay'),
          style:
              const TextStyle(color: Colors.white, fontSize: 12, height: 1.5)),
    ]);
  }
}
