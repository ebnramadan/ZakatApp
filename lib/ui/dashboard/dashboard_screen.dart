import '../../core/models/giving_forecast.dart';
import 'giving_forecast_card.dart';
import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/monthly_giving.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/monthly_provider.dart';
import '../shared/app_components.dart';
import '../shared/zakat_balance_summary.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onRecords, onMonthly, onCreate;
  final ValueChanged<ZakatRecord> onRecord;
  final ValueChanged<MonthlyPlan>? onCommitment;
  const DashboardScreen(
      {super.key,
      required this.onRecords,
      required this.onMonthly,
      required this.onCreate,
      required this.onRecord,
      this.onCommitment});
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final auth = context.watch<AuthProvider>(),
        calc = context.watch<CalculatorProvider>(),
        monthly = context.watch<MonthlyProvider>();
    final current = calc.defaultRecord(auth.profile?.defaultRecordId),
        now = DateTime.now(),
        key = monthKey(DateTime.now());
    final payments = calc.allPayments
        .where((p) => p.zakatRecordId == current?.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final paid = payments.fold(0.0, (s, p) => s + p.amount),
        target = current?.estimatedZakat ?? 0;
    final remaining = (target - paid).clamp(0.0, double.infinity);
    final due = monthly.plans
        .where((p) =>
            p.active &&
            p.startMonth.compareTo(key) <= 0 &&
            (p.kind == 'sadaqah' || p.zakatRecordId == current?.id) &&
            !p.dueDate(key).isAfter(now) &&
            monthly.paid(p.id, key) == null)
        .toList()
      ..sort((a, b) => a.dueDate(key).compareTo(b.dueDate(key)));
    final events = <({
      String title,
      String detail,
      double amount,
      String? currency,
      DateTime date
    })>[
      ...payments.map((p) => (
            title: p.displayName,
            detail: l(context, 'Zakat · {0}', [current?.name ?? '']),
            amount: p.amount,
            currency: current?.currency,
            date: p.date
          )),
      ...monthly.payments.where((p) => p.kind == 'sadaqah').map((p) => (
            title: p.recipient,
            detail: l(context, 'Sadaqah · Monthly giving'),
            amount: p.amount,
            currency: p.currency,
            date: p.paidAt
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final loading = calc.recordsLoading || calc.paymentsLoading;
    final hasError = calc.recordsError != null || calc.paymentsError != null;
    final overview = <Widget>[
      if (hasError)
        ActionCard(
            icon: Icons.cloud_off_outlined,
            title: l(context, "Your progress couldn’t load"),
            subtitle: l(context, "Tap to retry; saved payments are unchanged."),
            onTap: () => calc.retryRecords(auth.user!.uid))
      else if (loading)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(l(context, 'Loading your saved records…'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                          l(context,
                              'If this takes too long, retry here. You do not need to close the app.'),
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                              onPressed: () =>
                                  calc.retryRecords(auth.user!.uid),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(l(context, 'Retry connection')))),
                    ])))
      else if (current == null)
        Card(
            child: Padding(
                padding: EdgeInsets.all(compact ? 20 : 28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mosque_outlined,
                          size: 40, color: kPrimaryGreen),
                      const SizedBox(height: 16),
                      Text(l(context, "Begin with your Zakat"),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(l(context,
                          "Add your cash and gold to calculate Zakat. You can add monthly Sadaqah at any time.")),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add),
                          label: Text(l(context, "Calculate my Zakat"))),
                    ])))
      else ...[
        Card(
            color: const Color(0xFF103F36),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              const Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: AlignmentDirectional.topStart,
                              end: AlignmentDirectional.bottomEnd,
                              colors: [
                    Color(0xFF174F41),
                    Color(0xFF092E28)
                  ])))),
              const PositionedDirectional(
                  end: -36,
                  top: -24,
                  child: Opacity(
                      opacity: .055,
                      child: Icon(Icons.mosque_outlined,
                          size: 320, color: Colors.white))),
              Padding(
                  padding: EdgeInsets.all(compact ? 20 : 28),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l(context, 'Default record'),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFD6E9E1))),
                        const SizedBox(height: 6),
                        Text(current.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                            !current.isSubmitted
                                ? l(context, "Draft · Ready to finish")
                                : current.hawlComplete
                                    ? l(
                                        context,
                                        current.nisabMet
                                            ? "Zakat is due"
                                            : "Below Nisab")
                                    : l(context, "Hawl ends {0}", [
                                        DateFormat.yMMMd()
                                            .format(current.hawlEndDate)
                                      ]),
                            style: const TextStyle(color: Color(0xFFD6E9E1))),
                        const SizedBox(height: 24),
                        if (current.isSubmitted) ...[
                          ZakatBalanceSummary(record: current, paid: paid),
                        ] else
                          Text(
                              l(context,
                                  "Your calculation is saved. Finish reviewing the amounts before submitting it."),
                              style: const TextStyle(color: Color(0xFFD6E9E1))),
                        const SizedBox(height: 20),
                        if (current.isSubmitted &&
                            target > 0 &&
                            remaining == 0 &&
                            !calc.paymentsLoading &&
                            calc.paymentsError == null) ...[
                          Text(
                              l(
                                  context,
                                  current.hawlComplete
                                      ? 'This Zakat amount is fully paid. May Allah accept your giving.'
                                      : 'This estimate is fully covered by advance payments. Your Hawl is still in progress.'),
                              style: const TextStyle(color: Color(0xFFD6E9E1))),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  side:
                                      const BorderSide(color: Colors.white54)),
                              onPressed: onCreate,
                              icon: const Icon(Icons.calculate_outlined),
                              label: Text(l(context, 'Calculate new Zakat'))),
                          const SizedBox(height: 8),
                        ],
                        if (current.isSubmitted)
                          FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  side:
                                      const BorderSide(color: Colors.white54)),
                              onPressed: () => onRecord(current),
                              icon: Icon(current.isSubmitted
                                  ? Icons.arrow_forward
                                  : Icons.edit_outlined),
                              label: Text(current.isSubmitted
                                  ? l(context, "Open payment tracker")
                                  : l(context, "Finish this calculation")))
                      ]))
            ])),
      ],
    ];
    final nextSteps = <Widget>[
      if (!loading && !hasError) ...[
        if (current != null || due.isNotEmpty)
          SectionTitle(l(context, "Your next steps")),
        if (current != null && !current.isSubmitted)
          ActionCard(
              icon: Icons.edit_note_outlined,
              title: l(context, "Finalize {0}", [current.name]),
              subtitle:
                  l(context, "Review your assets and submit the calculation."),
              onTap: () => onRecord(current)),
        if (current?.isSubmitted == true &&
            current!.hawlComplete &&
            remaining > 0 &&
            !due.any((p) => p.kind == 'zakat'))
          ActionCard(
              icon: Icons.volunteer_activism_outlined,
              title: l(context, "Fulfil {0} of Zakat",
                  [money(remaining, current.currency)]),
              subtitle: l(context,
                  "Record a payment after you give. It will reduce this balance."),
              onTap: () => onRecord(current)),
        if (!monthly.loading && monthly.error == null)
          ...due.take(3).map((p) => ActionCard(
              icon: Icons.calendar_month_outlined,
              title: l(context, "Give {0} to {1}",
                  [money(p.amount, p.currency), p.recipient]),
              subtitle: l(context, "{0} · Due {1}", [
                p.kind == 'zakat' ? l(context, "Zakat") : l(context, "Sadaqah"),
                DateFormat.MMMd().format(p.dueDate(key))
              ]),
              onTap: () =>
                  onCommitment != null ? onCommitment!(p) : onMonthly())),
        if (current != null &&
            (current.isSubmitted &&
                (!current.hawlComplete || remaining == 0)) &&
            due.isEmpty &&
            !monthly.loading)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(l(context,
                      "You’re up to date. New monthly commitments will appear here when they are due.")))),
      ]
    ];
    final recentGiving = <Widget>[
      if (!loading && !hasError) ...[
        SectionTitle(l(context, "Recent giving")),
        if (events.isEmpty)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(l(context,
                      "Your recent Zakat and Sadaqah payments will appear here after you record them."))))
        else
          Card(
              child: Column(
                  children: events
                      .take(5)
                      .map((e) => ListTile(
                          leading: const Icon(Icons.check_circle_outline,
                              color: kPrimaryGreen),
                          title: Text(l(context, e.title)),
                          subtitle: Text(
                              '${e.detail}\n${DateFormat.yMMMd().format(e.date)}'),
                          isThreeLine: true,
                          trailing: Text(
                              l(context, money(e.amount, e.currency)),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600))))
                      .toList())),
        const SizedBox(height: 12),
        Text(
            l(context,
                "Zakat progress belongs to the default record. Sadaqah is shown as giving history and never reduces Zakat."),
            style: const TextStyle(fontSize: 13, color: Color(0xFF52655F))),
      ]
    ];
    return SafeArea(
        child: ListView(padding: EdgeInsets.all(compact ? 20 : 28), children: [
      PageIntro(
          eyebrow: l(context, "Your giving"),
          title: l(context, "For Allah. One step at a time."),
          description: l(
              context, "Your default Zakat record and the next things to do.")),
      Row(children: [
        const Icon(Icons.folder_open_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(l(context, 'My Zakat records'),
                style: Theme.of(context).textTheme.titleMedium)),
        TextButton(
            onPressed: onRecords, child: Text(l(context, 'View all records'))),
      ]),
      LayoutBuilder(builder: (context, constraints) {
        final left = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: overview);
        final tasks = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: nextSteps);
        final history = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: recentGiving);
        if (constraints.maxWidth >= 1050) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: Column(children: [left, history])),
            const SizedBox(width: 32),
            Expanded(flex: 4, child: tasks)
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, tasks, history]);
      }),
      if (!loading && !hasError && !monthly.loading && monthly.error == null)
        GivingForecastCard(
            months: givingForecast(
                plans: monthly.plans,
                from: now,
                recordAvailable: (id, currency) => calc.records.any((r) =>
                    r.id == id && r.isSubmitted && r.currency == currency))),
    ]));
  }
}
