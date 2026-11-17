import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/dashboard_summary.dart';
import '../../core/models/zakat_record.dart';
import '../../core/models/monthly_giving.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/monthly_provider.dart';
import '../shared/app_components.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onRecords, onMonthly, onCreate;
  final ValueChanged<ZakatRecord> onRecord;
  const DashboardScreen(
      {super.key,
      required this.onRecords,
      required this.onMonthly,
      required this.onCreate,
      required this.onRecord});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final calc = context.watch<CalculatorProvider>();
    final monthly = context.watch<MonthlyProvider>();
    final now = DateTime.now();
    final submitted = calc.records.where((r) => r.isSubmitted).toList();
    final summaries =
        DashboardSummary.build(calc.records, calc.allPayments, now);
    final due = monthly.plans
        .where((p) =>
            p.active &&
            p.startMonth.compareTo(monthKey(now)) <= 0 &&
            (p.kind != 'zakat' || calc.isRecordActive(p.zakatRecordId)) &&
            !p.dueDate(monthKey(now)).isAfter(now) &&
            monthly.paid(p.id, monthKey(now)) == null)
        .length;
    final activeIds = submitted.map((r) => r.id).toSet();
    final recent = calc.allPayments
        .where((p) => activeIds.contains(p.zakatRecordId))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final name = auth.profile?.displayName.trim().split(' ').first ?? '';
    final overview = <Widget>[
      if (calc.recordsLoading || calc.paymentsLoading)
        const Card(
            child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator())))
      else if (calc.error != null || calc.paymentsError != null)
        ActionCard(
            icon: Icons.cloud_off_outlined,
            title: 'Your overview couldn’t load',
            subtitle: 'Tap to retry. Your saved data is unchanged.',
            onTap: () => calc.loadRecords(auth.user!.uid))
      else if (summaries.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: kPrimaryGreen, size: 36),
                      const SizedBox(height: 16),
                      Text('Start with a clear picture',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                          'Create your first calculation or continue a draft. Your balances will appear here once a record is submitted.'),
                      const SizedBox(height: 16),
                      TextButton.icon(
                          onPressed: onRecords,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Open your records')),
                    ])))
      else ...[
        const SectionTitle('Your Zakat overview'),
        const Text(
            'Each currency is shown separately. Payments apply only to their linked record.',
            style: TextStyle(fontSize: 13, color: Color(0xFF52655F))),
        const SizedBox(height: 12),
        ...summaries.map((s) => Card(
            color: const Color(0xFF103F36),
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.currency ?? 'Currency not recorded',
                          style: const TextStyle(
                              color: Color(0xFFD6E9E1),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      const Text('Remaining Zakat due',
                          style: TextStyle(color: Color(0xFFD6E9E1))),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(money(s.remaining, s.currency),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1))),
                      const SizedBox(height: 24),
                      Wrap(spacing: 36, runSpacing: 16, children: [
                        _Metric('Due after completed Hawl',
                            money(s.due, s.currency)),
                        _Metric(
                            'Given toward Zakat', money(s.given, s.currency)),
                      ]),
                      if (s.upcomingEstimate > 0) ...[
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Color(0xFF60887B))),
                        Text(
                            'Upcoming estimate: ${money(s.upcomingEstimate, s.currency)}',
                            style: const TextStyle(color: Color(0xFFD6E9E1))),
                        const Text(
                            'Hawl not complete. This is separate from the amount due.',
                            style: TextStyle(
                                color: Color(0xFFD6E9E1), fontSize: 12))
                      ],
                    ])))),
      ],
    ];
    final nextSteps = <Widget>[
      const SectionTitle('Your next steps'),
      if (!monthly.loading && due > 0)
        ActionCard(
            icon: Icons.notifications_active_outlined,
            title:
                '$due monthly ${due == 1 ? 'commitment' : 'commitments'} ready to give',
            subtitle: 'Review recipients and mark payments after giving.',
            onTap: onMonthly),
      if (calc.records.any((r) => !r.isSubmitted))
        ActionCard(
            icon: Icons.edit_note_outlined,
            title: 'Continue your draft',
            subtitle: 'Pick up where you left off in Records.',
            onTap: onRecords),
      ActionCard(
          icon: Icons.calendar_month_outlined,
          title: auth.profile?.monthlyGivingLabel ?? 'Monthly Giving',
          subtitle: 'Build a regular habit of Sadaqah or Zakat.',
          onTap: onMonthly),
    ];
    return SafeArea(
        child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
          PageIntro(
              eyebrow: DateFormat('EEEE, d MMMM').format(now),
              title: name.isEmpty
                  ? 'Your giving, at a glance.'
                  : 'Assalamu alaikum, $name.',
              description:
                  'A clear view of your Zakat, your progress, and what comes next.',
              action: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('New Calculation')))),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 960) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...overview, ...nextSteps]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  flex: 3,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: overview)),
              const SizedBox(width: 28),
              Expanded(
                  flex: 2,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: nextSteps)),
            ]);
          }),
          if (submitted.isNotEmpty) ...[
            SectionTitle('Your records',
                trailing: TextButton(
                    onPressed: onRecords, child: const Text('View all'))),
            ...submitted.take(3).map((r) => ActionCard(
                icon: Icons.description_outlined,
                title: r.name,
                subtitle: r.hawlComplete
                    ? 'Hawl complete · Open payment tracker'
                    : 'Hawl ends ${DateFormat.yMMMd().format(r.hawlEndDate)}',
                onTap: () => onRecord(r))),
          ],
          if (!calc.paymentsLoading &&
              calc.paymentsError == null &&
              recent.isNotEmpty) ...[
            const SectionTitle('Recent Zakat payments'),
            Card(
                child: Column(
                    children: recent.take(4).map((p) {
              final record =
                  submitted.firstWhere((r) => r.id == p.zakatRecordId);
              return ListTile(
                  onTap: () => onRecord(record),
                  leading: const Icon(Icons.check_circle_outline,
                      color: kPrimaryGreen),
                  title: Text(p.recipient.isNotEmpty ? p.recipient : p.name),
                  subtitle: Text(
                      '${record.name} · ${DateFormat.MMMd().format(p.date)}'),
                  trailing: Text(money(p.amount, record.currency),
                      style: const TextStyle(fontWeight: FontWeight.w600)));
            }).toList())),
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
            style: const TextStyle(fontSize: 12, color: Color(0xFFD6E9E1))),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ]);
}
