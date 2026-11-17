import '../shared/giving_celebration.dart';
import '../widgets/searchable_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/models/monthly_giving.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/monthly_provider.dart';

class MonthlyScreen extends StatefulWidget {
  final String? focusRecipient;
  const MonthlyScreen({super.key, this.focusRecipient});
  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _query = '';
  late final TextEditingController _search;
  bool _followingCurrent = true;
  bool _showPaused = false;
  @override
  void initState() {
    super.initState();
    _query = widget.focusRecipient ?? '';
    _search = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _shift(int by) => setState(() {
        _followingCurrent = false;
        _month = DateTime(_month.year, _month.month + by);
      });
  void _currentMonth() => setState(() {
        _followingCurrent = true;
        _month = DateTime(DateTime.now().year, DateTime.now().month);
      });
  Future<void> _edit({MonthlyPlan? plan}) async {
    await showDialog<void>(
        context: context, builder: (_) => MonthlyPlanDialog(existing: plan));
  }

  Future<void> _undo(MonthlyPayment payment) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Undo this payment?'),
                content: Text(
                    'This marks ${payment.recipient} as unpaid for ${DateFormat.yMMMM().format(monthFromKey(payment.month))}.${payment.kind == 'zakat' ? ' The matching Zakat tracker entry will also be removed.' : ''}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep payment')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Undo payment'))
                ]));
    if (!mounted || confirmed != true) return;
    final monthly = context.read<MonthlyProvider>();
    final ok = await monthly.undo(payment);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Payment undone.' : monthly.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthly = context.watch<MonthlyProvider>();
    final auth = context.watch<AuthProvider>();
    if (_followingCurrent) {
      _month = DateTime(DateTime.now().year, DateTime.now().month);
    }
    final key = monthKey(_month);
    final nowKey = monthKey(DateTime.now());
    final all = monthly.plans
        .where((p) =>
            ((p.active || _showPaused) && p.startMonth.compareTo(key) <= 0) ||
            monthly.paid(p.id, key) != null)
        .toList();
    final shown = all
        .where((p) => p.recipient.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final calc = context.watch<CalculatorProvider>();
    bool available(String kind, String id) =>
        kind != 'zakat' || calc.isRecordActive(id);
    final paid = monthly.forMonth(key);
    final currencies = {
      ...all.map((p) => p.currency),
      ...paid.map((p) => p.currency)
    }.toList()
      ..sort();
    return Scaffold(
      appBar: AppBar(
          title: Text(
              context.watch<AuthProvider>().profile?.monthlyGivingLabel ??
                  'Monthly Giving'),
          actions: [
            IconButton(
                tooltip: 'Monthly giving settings',
                onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const MonthlySettings()),
                icon: const Icon(Icons.tune))
          ]),
      body: monthly.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => monthly.load(auth.user!.uid, force: true),
              child: ListView(
                  key: const Key('monthly-list'),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  children: [
                    Text('A little, every month.',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'Keep your monthly commitments in one place. Mark a payment only after you have given the money.',
                        style: TextStyle(height: 1.6, color: Colors.black54)),
                    const SizedBox(height: 18),
                    Row(children: [
                      IconButton(
                          tooltip: 'Previous month',
                          onPressed: () => _shift(-1),
                          icon: const Icon(Icons.chevron_left)),
                      Expanded(
                          child: Text(DateFormat.yMMMM().format(_month),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          tooltip: 'Next month',
                          onPressed: () => _shift(1),
                          icon: const Icon(Icons.chevron_right))
                    ]),
                    if (key != nowKey)
                      Center(
                          child: TextButton(
                              onPressed: _currentMonth,
                              child: const Text('Back to this month'))),
                    if (key.compareTo(nowKey) > 0)
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                              'Planning ahead. Future months cannot be marked paid yet.')),
                    if (monthly.error != null)
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.error_outline),
                              title: Text(monthly.error!),
                              trailing: TextButton(
                                  onPressed: () =>
                                      monthly.load(auth.user!.uid, force: true),
                                  child: const Text('Retry')))),
                    ...currencies.map((currency) {
                      final paidTotal = paid
                          .where((p) => p.currency == currency)
                          .fold(0.0, (s, p) => s + p.amount);
                      final outstanding = all
                          .where((p) =>
                              p.currency == currency &&
                              available(p.kind, p.zakatRecordId) &&
                              monthly.paid(p.id, key) == null)
                          .fold(0.0, (s, p) => s + p.amount);
                      final fmt = NumberFormat.currency(
                          name: currency, symbol: '$currency ');
                      return Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child:
                                  Wrap(spacing: 28, runSpacing: 12, children: [
                                _MonthlyStat(
                                    'Given this month', fmt.format(paidTotal)),
                                _MonthlyStat(
                                    'Still to give', fmt.format(outstanding)),
                              ])));
                    }),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, children: [
                      FilterChip(
                          label: const Text('Include paused recipients'),
                          selected: _showPaused,
                          onSelected: (value) =>
                              setState(() => _showPaused = value)),
                    ]),
                    const SizedBox(height: 12),
                    if (_query.isNotEmpty)
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: InputChip(
                              label: Text('Showing: $_query'),
                              onDeleted: () {
                                _search.clear();
                                setState(() => _query = '');
                              })),
                    if (all.isNotEmpty)
                      TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                              labelText: 'Find a recipient',
                              prefixIcon: Icon(Icons.search)),
                          onChanged: (v) => setState(() => _query = v)),
                    const SizedBox(height: 12),
                    if (all.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Column(children: [
                            Icon(Icons.volunteer_activism_outlined,
                                size: 58,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 16),
                            Text('Start a monthly habit',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            const Text(
                                'Add a person and an amount. Choose صدقة or connect a Zakat record, then record each month when you pay.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    height: 1.6, color: Colors.black54)),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                                onPressed: () => _edit(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add your first recipient'))
                          ])),
                    if (all.isNotEmpty && shown.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No recipients match your search.')),
                    ...shown.map((plan) {
                      final receipt = monthly.paid(plan.id, key);
                      final isPaid = receipt != null;
                      final blocked = !available(receipt?.kind ?? plan.kind,
                          receipt?.zakatRecordId ?? plan.zakatRecordId);
                      final kind = receipt?.kind ?? plan.kind;
                      final amount = receipt?.amount ?? plan.amount;
                      final due = plan.dueDate(key);
                      final overdue = !isPaid && !due.isAfter(DateTime.now());
                      return Card(
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                              backgroundColor: isPaid
                                                  ? Colors.green.shade50
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                              child: Icon(
                                                  isPaid
                                                      ? Icons.check
                                                      : Icons.person_outline,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(
                                                    receipt?.recipient ??
                                                        plan.recipient,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                const SizedBox(height: 4),
                                                Text(
                                                    kind == 'zakat'
                                                        ? 'زكاة · Counts toward your selected Zakat record'
                                                        : 'صدقة · Separate from Zakat',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        height: 1.5))
                                              ])),
                                          PopupMenuButton<String>(
                                              tooltip: 'Manage recipient',
                                              onSelected: (v) async {
                                                if (v == 'edit') {
                                                  _edit(plan: plan);
                                                }
                                                if (v == 'pause') {
                                                  final pause = await showDialog<
                                                          bool>(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                              title: const Text(
                                                                  'Pause monthly giving?'),
                                                              content: Text(
                                                                  'Stop future commitments and reminders for ${plan.recipient}. Payments already recorded will remain in your history.'),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            false),
                                                                    child: const Text(
                                                                        'Cancel')),
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            true),
                                                                    child: const Text(
                                                                        'Pause recipient'))
                                                              ]));
                                                  if (pause == true) {
                                                    await monthly
                                                        .save(plan.archived());
                                                  }
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                    const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Text(
                                                            'Edit commitment')),
                                                    if (plan.active)
                                                      const PopupMenuItem(
                                                          value: 'pause',
                                                          child: Text(
                                                              'Pause recipient'))
                                                  ])
                                        ]),
                                    const SizedBox(height: 16),
                                    Text(
                                        NumberFormat.currency(
                                          name: receipt?.currency ??
                                              plan.currency,
                                          symbol:
                                              '${receipt?.currency ?? plan.currency} ',
                                        ).format(amount),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(
                                        isPaid
                                            ? 'Paid on ${DateFormat.yMMMd().format(receipt.paidAt)}'
                                            : '${overdue ? 'Ready to give' : 'Reminder'} · ${DateFormat.MMMd().format(due)}',
                                        style: TextStyle(
                                            color: isPaid
                                                ? Colors.green.shade800
                                                : overdue
                                                    ? Colors.deepOrange.shade800
                                                    : Colors.black54)),
                                    const SizedBox(height: 14),
                                    if (blocked)
                                      const Padding(
                                          padding: EdgeInsets.only(bottom: 12),
                                          child: Text(
                                              'Linked Zakat record is unavailable. Restore it from the recycle bin or edit this commitment to select another record.')),
                                    if (isPaid)
                                      TextButton.icon(
                                          onPressed: monthly.busy || blocked
                                              ? null
                                              : () => _undo(receipt),
                                          icon:
                                              const Icon(Icons.undo, size: 18),
                                          label: const Text('Undo payment'))
                                    else
                                      OutlinedButton.icon(
                                          onPressed: monthly.busy ||
                                                  blocked ||
                                                  key.compareTo(nowKey) > 0
                                              ? null
                                              : () async {
                                                  final confirmed = await showDialog<
                                                          bool>(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                              title: const Text(
                                                                  'Record this month’s payment?'),
                                                              content: Text(
                                                                  'Confirm that you gave ${plan.currency} ${plan.amount.toStringAsFixed(currencyDecimals(plan.currency))} to ${plan.recipient}.${plan.kind == 'zakat' ? ' This will reduce the remaining amount on your selected Zakat record.' : ' Your Zakat balance will not change.'}'),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            false),
                                                                    child: const Text(
                                                                        'Not yet')),
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            true),
                                                                    child: const Text(
                                                                        'Yes, I paid'))
                                                              ]));
                                                  if (confirmed != true ||
                                                      !context.mounted) return;
                                                  final ok = await monthly
                                                      .markPaid(plan, key);
                                                  if (ok && context.mounted) {
                                                    await showGivingCelebration(
                                                        context,
                                                        sadaqah: plan.kind ==
                                                            'sadaqah');
                                                  }
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(ok
                                                                ? 'Payment recorded for ${plan.recipient}.'
                                                                : monthly
                                                                    .error!)));
                                                  }
                                                },
                                          icon: const Icon(
                                              Icons.check_circle_outline),
                                          label: const Text('Mark as paid')),
                                  ])));
                    }),
                    if (monthly.plans.any((p) => !p.active))
                      ExpansionTile(
                          title: const Text('Paused recipients'),
                          subtitle: const Text(
                              'Resume from this month; previous payments stay saved'),
                          children: monthly.plans
                              .where((p) => !p.active)
                              .map((p) => ListTile(
                                  title: Text(p.recipient),
                                  trailing: TextButton(
                                      onPressed: monthly.busy
                                          ? null
                                          : () => _edit(plan: p),
                                      child: const Text('Edit & resume'))))
                              .toList()),
                    const SizedBox(height: 16),
                    const Text(
                        'Reminders are a prompt to give, not an automatic transfer. A commitment never reduces your Zakat until it is marked paid.',
                        style: TextStyle(
                            color: Colors.black54, fontSize: 12, height: 1.6)),
                  ])),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: 'monthly-add',
          onPressed: monthly.busy ? null : () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add recipient')),
    );
  }
}

class _MonthlyStat extends StatelessWidget {
  final String label;
  final String value;
  const _MonthlyStat(this.label, this.value);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label),
        const SizedBox(height: 6),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold))
      ]);
}

class MonthlyPlanDialog extends StatefulWidget {
  final MonthlyPlan? existing;
  const MonthlyPlanDialog({super.key, this.existing});
  @override
  State<MonthlyPlanDialog> createState() => _MonthlyPlanDialogState();
}

class _MonthlyPlanDialogState extends State<MonthlyPlanDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late String _currency;
  late String _kind;
  late String _record;
  late int _day;
  String? _error;
  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile!;
    final p = widget.existing;
    _name = TextEditingController(text: p?.recipient ?? '');
    _amount = TextEditingController(text: p?.amount.toString() ?? '');
    _currency = p?.currency ?? profile.currency;
    _kind = p?.kind ?? profile.monthlyDefaultKind;
    _record = p?.zakatRecordId ?? '';
    _day = p?.reminderDay ?? 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthly = context.watch<MonthlyProvider>();
    final records = context
        .watch<CalculatorProvider>()
        .records
        .where((r) => r.isSubmitted && r.currency == _currency)
        .toList();
    final selected = records.any((r) => r.id == _record) ? _record : null;
    return AlertDialog(
        title: Text(widget.existing == null
            ? 'Add monthly giving'
            : 'Edit monthly commitment'),
        content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.existing != null)
                            const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: Text(
                                    'Changes apply to unpaid and future months. Recorded payments keep their original amounts and classification.')),
                          TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                  labelText: 'Recipient name'),
                              validator: (v) => v == null ||
                                      v.trim().isEmpty ||
                                      v.length > 120
                                  ? 'Enter a name (up to 120 characters)'
                                  : null),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: _amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Amount per month'),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                return n == null ||
                                        !n.isFinite ||
                                        n <= 0 ||
                                        n >= 1e15
                                    ? 'Enter a positive amount'
                                    : null;
                              }),
                          const SizedBox(height: 14),
                          SearchablePicker<String>(
                              label: 'Currency',
                              value: _currency,
                              options: currencyOptions,
                              onChanged: monthly.busy
                                  ? null
                                  : (v) => setState(() {
                                        _currency = v;
                                        _record = '';
                                      })),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                              value: _kind,
                              decoration: const InputDecoration(
                                  labelText: 'Count this giving as'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'sadaqah',
                                    child: Text('صدقة · Sadaqah')),
                                DropdownMenuItem(
                                    value: 'zakat',
                                    child: Text('زكاة · Part of Zakat'))
                              ],
                              onChanged: monthly.busy
                                  ? null
                                  : (v) => setState(() => _kind = v!)),
                          if (_kind == 'zakat') ...[
                            const SizedBox(height: 14),
                            SearchablePicker<String>(
                                label: 'Zakat record to reduce',
                                value: selected,
                                options: records
                                    .map((r) => PickerOption(r.id, r.name))
                                    .toList(),
                                onChanged: monthly.busy
                                    ? null
                                    : (v) => setState(() => _record = v),
                                validator: (v) => _kind == 'zakat' && v == null
                                    ? 'Choose a submitted record in the same currency'
                                    : null),
                            if (records.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                      'Create and submit a Zakat calculation in this currency first. You can also choose Sadaqah for now.')),
                          ],
                          const SizedBox(height: 14),
                          SearchablePicker<int>(
                              label: 'Remind me each month on day',
                              value: _day,
                              options: List.generate(
                                  31, (i) => PickerOption(i + 1, '${i + 1}')),
                              onChanged: monthly.busy
                                  ? null
                                  : (v) => setState(() => _day = v)),
                          const SizedBox(height: 8),
                          const Text(
                              'If a month is shorter, the reminder falls on its last day.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  height: 1.5)),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                        ])))),
        actions: [
          TextButton(
              onPressed: monthly.busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: monthly.busy
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      final p = widget.existing;
                      final plan = MonthlyPlan(
                          id: p?.id ?? const Uuid().v4(),
                          userId: context.read<AuthProvider>().user!.uid,
                          recipient: _name.text.trim(),
                          amount: double.parse(_amount.text),
                          currency: _currency,
                          kind: _kind,
                          zakatRecordId: _kind == 'zakat' ? _record : '',
                          reminderDay: _day,
                          startMonth: p != null && p.active
                              ? p.startMonth
                              : monthKey(DateTime.now()),
                          active: true,
                          createdAt: p?.createdAt ?? DateTime.now());
                      final ok = await monthly.save(plan);
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _error = monthly.error);
                      }
                    },
              child: Text(monthly.busy ? 'Saving…' : 'Save recipient')),
        ]);
  }
}

class MonthlySettings extends StatelessWidget {
  const MonthlySettings({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final monthly = context.watch<MonthlyProvider>();
    final profile = auth.profile!;
    return SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Monthly giving settings',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                      value: profile.monthlyDefaultKind,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Default for new recipients'),
                      items: const [
                        DropdownMenuItem(
                            value: 'sadaqah', child: Text('صدقة · Sadaqah')),
                        DropdownMenuItem(
                            value: 'zakat', child: Text('زكاة · Part of Zakat'))
                      ],
                      onChanged: (v) async {
                        final ok = await auth.updateProfileFields(
                            monthlyDefaultKind: v);
                        if (!context.mounted || ok) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(auth.error!)));
                      }),
                  const SizedBox(height: 10),
                  const Text(
                      'Each recipient can override this. Changing the default never reclassifies existing payments.',
                      style: TextStyle(height: 1.5, color: Colors.black54)),
                  const SizedBox(height: 18),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Email me monthly reminders'),
                      subtitle: Text(
                          'Sent to ${auth.user?.email ?? profile.email}. In-app reminders are always available.'),
                      value: profile.monthlyEmailReminders,
                      onChanged: (v) async {
                        final ok = await auth.updateProfileFields(
                            monthlyEmailReminders: v);
                        if (!context.mounted || ok) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(auth.error!)));
                      }),
                  if (!monthly.emailReady)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Text(
                                'Email delivery has not been confirmed yet. Your preference is saved; in-app due reminders are available now.'))),
                  const Text(
                      'Email reminders are checked daily around 08:00 UTC. One reminder per unpaid recipient per month; completed payments are skipped. Email includes the recipient and amount. You can turn it off at any time.',
                      style: TextStyle(
                          fontSize: 12, height: 1.6, color: Colors.black54)),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done')),
                ])));
  }
}
