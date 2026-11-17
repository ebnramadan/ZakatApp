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
            title: p.recipient.isEmpty ? p.name : p.recipient,
            detail: 'Zakat · ${current?.name ?? ''}',
            amount: p.amount,
            currency: current?.currency,
            date: p.date
          )),
      ...monthly.payments.where((p) => p.kind == 'sadaqah').map((p) => (
            title: p.recipient,
            detail: 'Sadaqah · Monthly giving',
            amount: p.amount,
            currency: p.currency,
            date: p.paidAt
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final loading = calc.recordsLoading || calc.paymentsLoading;
    final hasError = calc.recordsError != null || calc.paymentsError != null;
    return SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
      const PageIntro(
          eyebrow: 'Your giving',
          title: 'One intention. Clear progress.',
          description: 'Your default Zakat record and the next things to do.'),
      if (loading)
        const Center(child: CircularProgressIndicator())
      else if (hasError)
        ActionCard(
            icon: Icons.cloud_off_outlined,
            title: 'Your progress couldn’t load',
            subtitle: 'Tap to retry; saved payments are unchanged.',
            onTap: () => calc.loadRecords(auth.user!.uid))
      else if (current == null)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mosque_outlined,
                          size: 40, color: kPrimaryGreen),
                      const SizedBox(height: 16),
                      Text('Begin with your Zakat',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                          'A guided calculation helps you set up your first record. You can add monthly Sadaqah at any time.'),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add),
                          label: const Text('Calculate my Zakat')),
                    ])))
      else ...[
        Row(children: [
          const Expanded(
              child: Text('Default record',
                  style: TextStyle(color: Color(0xFF52655F)))),
          TextButton(
              onPressed: onRecords, child: const Text('View all records'))
        ]),
        Card(
            color: const Color(0xFF103F36),
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                          !current.isSubmitted
                              ? 'Draft · Ready to finish'
                              : current.hawlComplete
                                  ? 'Hawl complete'
                                  : 'Hawl ends ${DateFormat.yMMMd().format(current.hawlEndDate)}',
                          style: const TextStyle(color: Color(0xFFD6E9E1))),
                      const SizedBox(height: 24),
                      if (current.isSubmitted) ...[
                        Text(
                            current.hawlComplete
                                ? 'Remaining Zakat'
                                : 'Remaining estimate',
                            style: const TextStyle(color: Color(0xFFD6E9E1))),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(money(remaining, current.currency),
                                style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white))),
                        const SizedBox(height: 20),
                        Wrap(spacing: 32, runSpacing: 12, children: [
                          _Metric('Calculated Zakat',
                              money(target, current.currency)),
                          _Metric('Given', money(paid, current.currency))
                        ]),
                        const SizedBox(height: 20),
                        Semantics(
                            label:
                                '${target > 0 ? ((paid / target).clamp(0, 1) * 100).round() : 0}% of calculated Zakat recorded',
                            child: LinearProgressIndicator(
                                value: target > 0
                                    ? (paid / target).clamp(0, 1)
                                    : 0,
                                backgroundColor: const Color(0xFF52766A),
                                color: const Color(0xFFE9C77B),
                                minHeight: 8)),
                        const SizedBox(height: 12),
                        Text(
                            current.hawlComplete
                                ? 'Payments reduce this record’s remaining balance.'
                                : 'This is an estimate until your Hawl is complete.',
                            style: const TextStyle(
                                color: Color(0xFFD6E9E1), fontSize: 13)),
                      ] else
                        const Text(
                            'Your calculation is saved. Finish reviewing the amounts before submitting it.',
                            style: TextStyle(color: Color(0xFFD6E9E1))),
                      const SizedBox(height: 20),
                      if (current.isSubmitted &&
                          (!current.hawlComplete || remaining == 0))
                        FilledButton.tonalIcon(
                            onPressed: () => onRecord(current),
                            icon: Icon(current.isSubmitted
                                ? Icons.arrow_forward
                                : Icons.edit_outlined),
                            label: Text(current.isSubmitted
                                ? 'Open payment tracker'
                                : 'Finish this calculation')),
                    ]))),
      ],
      if (!loading && !hasError) ...[
        const SectionTitle('Your next steps'),
        if (current != null && !current.isSubmitted)
          ActionCard(
              icon: Icons.edit_note_outlined,
              title: 'Finalize ${current.name}',
              subtitle: 'Review your assets and submit the calculation.',
              onTap: () => onRecord(current)),
        if (current?.isSubmitted == true &&
            current!.hawlComplete &&
            remaining > 0 &&
            !due.any((p) => p.kind == 'zakat'))
          ActionCard(
              icon: Icons.volunteer_activism_outlined,
              title: 'Fulfil ${money(remaining, current.currency)} of Zakat',
              subtitle:
                  'Record a payment after you give. It will reduce this balance.',
              onTap: () => onRecord(current)),
        if (!monthly.loading && monthly.error == null)
          ...due.take(3).map((p) => ActionCard(
              icon: Icons.calendar_month_outlined,
              title: 'Give ${money(p.amount, p.currency)} to ${p.recipient}',
              subtitle:
                  '${p.kind == 'zakat' ? 'Zakat' : 'Sadaqah'} · Due ${DateFormat.MMMd().format(p.dueDate(key))}',
              onTap: () =>
                  onCommitment != null ? onCommitment!(p) : onMonthly())),
        if (current != null &&
            (current.isSubmitted &&
                (!current.hawlComplete || remaining == 0)) &&
            due.isEmpty &&
            !monthly.loading)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      'You’re up to date. New monthly commitments will appear here when they are due.'))),
        const SectionTitle('Recent giving'),
        if (events.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      'Your recent Zakat and Sadaqah payments will appear here after you record them.')))
        else
          Card(
              child: Column(
                  children: events
                      .take(5)
                      .map((e) => ListTile(
                          leading: const Icon(Icons.check_circle_outline,
                              color: kPrimaryGreen),
                          title: Text(e.title),
                          subtitle: Text(
                              '${e.detail}\n${DateFormat.yMMMd().format(e.date)}'),
                          isThreeLine: true,
                          trailing: Text(money(e.amount, e.currency),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600))))
                      .toList())),
        const SizedBox(height: 12),
        const Text(
            'Zakat progress belongs to the default record. Sadaqah is shown as giving history and never reduces Zakat.',
            style: TextStyle(fontSize: 13, color: Color(0xFF52655F))),
      ],
    ]));
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFFD6E9E1))),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white))
      ]);
}
