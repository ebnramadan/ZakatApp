import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../shared/app_components.dart';
import '../../core/localization/strings.dart';
import '../../core/models/giving_forecast.dart';

class GivingForecastCard extends StatefulWidget {
  final List<GivingForecastMonth> months;
  const GivingForecastCard({super.key, required this.months});
  @override
  State<GivingForecastCard> createState() => _GivingForecastCardState();
}

class _GivingForecastCardState extends State<GivingForecastCard> {
  String? _selected;
  @override
  Widget build(BuildContext context) {
    final currencies = widget.months
        .expand((m) => {...m.sadaqah.keys, ...m.zakat.keys})
        .toSet()
        .toList()
      ..sort();
    if (currencies.isEmpty) return const SizedBox.shrink();
    final currency =
        currencies.contains(_selected) ? _selected! : currencies.first;
    final first = widget.months.first.total(currency);
    final annual = widget.months.fold(0.0, (sum, m) => sum + m.total(currency));
    final maximum = widget.months
        .fold(0.0, (value, m) => math.max(value, m.total(currency)));
    return Card(
        child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      leading: const Icon(Icons.insights_outlined),
      title: Text(l(context, '12-month giving forecast'),
          style: Theme.of(context).textTheme.titleMedium),
      subtitle:
          Text('${l(context, 'Monthly plan')}: ${money(first, currency)}'),
      children: [
        Text(
            l(context,
                'Planned giving, not payments. Based on your active commitments; amounts may change.'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (currencies.length > 1)
          Wrap(
              spacing: 8,
              children: currencies
                  .map((c) => ChoiceChip(
                      label: Text(c),
                      selected: c == currency,
                      onSelected: (_) => setState(() => _selected = c)))
                  .toList()),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l(context, 'Next 12 months')),
            trailing: Text(money(annual, currency),
                style: const TextStyle(fontWeight: FontWeight.w700))),
        ...widget.months.map((month) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            l(context, DateFormat.yMMM().format(month.month)),
                            style: Theme.of(context).textTheme.bodySmall)),
                    Text(money(month.total(currency), currency),
                        style: const TextStyle(fontWeight: FontWeight.w600))
                  ]),
                  const SizedBox(height: 6),
                  Semantics(
                      label:
                          '${l(context, DateFormat.yMMMM().format(month.month))}: ${money(month.total(currency), currency)}',
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: maximum == 0
                                  ? 0
                                  : month.total(currency) / maximum,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFF1E3D1),
                              color: const Color(0xFF875C43)))),
                  const SizedBox(height: 4),
                  Text(
                      '${l(context, 'Sadaqah')}: ${money(month.sadaqah[currency] ?? 0, currency)} · ${l(context, 'Zakat')}: ${money(month.zakat[currency] ?? 0, currency)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ]))),
      ],
    ));
  }
}
